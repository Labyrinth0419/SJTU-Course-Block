import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/schedule.dart';

/// Service responsible for preparing data that will be consumed by the
/// Android home screen widget. Currently the only supported action is to
/// gather today\'s courses, serialize them and push them into the
/// shared preferences namespace used by the `home_widget` plugin.
class WidgetService {
  /// Queries the database for the courses that are scheduled for the
  /// current date and writes a small JSON blob to the widget preferences.
  ///
  /// After saving the data this method also triggers an explicit widget
  /// update so the native side can refresh immediately.
  static Future<void> syncTodayCourses() async {
    debugPrint('WidgetService.syncTodayCourses called');
    try {
      final now = DateTime.now();
      final dayOfWeek = now.weekday; // 1 = Monday

      final Schedule? schedule = await DatabaseHelper.instance
          .getCurrentSchedule();
      if (schedule == null || schedule.id == null) {
        debugPrint('WidgetService: no current schedule, writing empty payload');
        final jsonString = jsonEncode({'type': 'none'});
        debugPrint('WidgetService: saving json=$jsonString');
        await HomeWidget.saveWidgetData('today_courses', jsonString);
        await HomeWidget.updateWidget(name: 'CourseWidgetProvider');
        return;
      }

      // calculate current week number relative to schedule start date
      final diff = now.difference(schedule.startDate).inDays;
      int currentWeek = (diff / 7).floor() + 1;
      if (currentWeek < 1) currentWeek = 1;

      final courses = await DatabaseHelper.instance.getCoursesBySchedule(
        schedule.id!,
      );

      // filter out by day/week and exclude virtual courses
      final todays = courses.where((c) {
        if (c.isVirtual) return false;
        if (c.dayOfWeek != dayOfWeek) return false;
        if (currentWeek < c.startWeek || currentWeek > c.endWeek) return false;
        if (c.isOddWeek && currentWeek % 2 == 0) return false;
        if (c.isEvenWeek && currentWeek % 2 == 1) return false;
        return true;
      }).toList();

      // sort by start node to help choose current/next
      todays.sort((a, b) => a.startNode.compareTo(b.startNode));

      // approximate current node by time (start at 8:00, 30min per half-node)
      int currentNode = 1;
      if (now.hour >= 8) {
        currentNode = ((now.hour - 8) * 2) + (now.minute >= 30 ? 1 : 0) + 1;
        if (currentNode < 1) currentNode = 1;
        if (currentNode > 14) currentNode = 14;
      }

      Course? currentCourse;
      Course? next;
      for (var c in todays) {
        if (currentCourse == null) {
          // check if now falls inside this course
          if (currentNode >= c.startNode &&
              currentNode < c.startNode + c.step) {
            currentCourse = c;
            continue;
          }
          // if no current yet and this course is in the future
          if (currentNode < c.startNode) {
            next = c;
            break;
          }
        } else {
          // we already have current, so first later entry is next
          next = c;
          break;
        }
      }

      Map<String, dynamic> payload = {'type': 'none'};
      if (currentCourse != null) {
        payload = {
          'type': 'course',
          'courseName': currentCourse.courseName,
          'classRoom': currentCourse.classRoom,
        };
      } else if (next != null) {
        payload = {
          'type': 'course',
          'courseName': next.courseName,
          'classRoom': next.classRoom,
        };
      } else {
        // look for tomorrow's first course
        int tomorrowDay = dayOfWeek == 7 ? 1 : dayOfWeek + 1;
        final tom = courses.where((c) {
          if (c.isVirtual) return false;
          if (c.dayOfWeek != tomorrowDay) return false;
          if (currentWeek < c.startWeek || currentWeek > c.endWeek)
            return false;
          if (c.isOddWeek && currentWeek % 2 == 0) return false;
          if (c.isEvenWeek && currentWeek % 2 == 1) return false;
          return true;
        }).toList()..sort((a, b) => a.startNode.compareTo(b.startNode));
        if (tom.isNotEmpty) {
          final first = tom.first;
          payload = {
            'type': 'tomorrow',
            'courseName': first.courseName,
            'classRoom': first.classRoom,
          };
        }
      }

      final jsonString = jsonEncode(payload);
      debugPrint('WidgetService: saving json=$jsonString');
      // write via home_widget and also to default SharedPreferences for native access
      await HomeWidget.saveWidgetData('today_courses', jsonString);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('today_courses', jsonString);
        debugPrint('WidgetService: also wrote SharedPreferences');
      } catch (e) {
        debugPrint('WidgetService: write to SharedPreferences failed: $e');
      }

      // additionally write to an app-private file so native side can read reliably
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/today_courses.json');
        await file.writeAsString(jsonString);
        debugPrint('WidgetService: also wrote file=${file.path}');
      } catch (e) {
        debugPrint('WidgetService: write to file failed: $e');
      }

      await HomeWidget.updateWidget(name: 'CourseWidgetProvider');
    } catch (e) {
      debugPrint('WidgetService.syncTodayCourses error: $e');
    }
  }
}
