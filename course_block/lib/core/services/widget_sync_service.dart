import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/schedule.dart';
import '../utils/time_slots.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._();

  /// Push today’s courses to the Android home widget.
  Future<void> updateTodayWidget(
    List<Course> courses,
    Schedule? schedule, {
    required int totalWeeks,
  }) async {
    if (schedule == null) return;

    final today = normalizeDate(DateTime.now());
    final start = normalizeDate(schedule.startDate);
    final diffDays = today.difference(start).inDays;
    var currentWeek = (diffDays / 7).floor() + 1;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > totalWeeks) currentWeek = totalWeeks;

    final todayCourses =
        courses
            .where((c) => _isCourseInWeek(c, currentWeek))
            .where((c) => c.dayOfWeek == today.weekday)
            .toList()
          ..sort((a, b) => a.startNode.compareTo(b.startNode));

    final payload = todayCourses
        .take(5)
        .map(
          (c) => {
            'name': c.courseName,
            'room': c.classRoom,
            'startNode': c.startNode,
            'step': c.step,
          },
        )
        .toList();

    final subtitle = '第$currentWeek周 ${today.month}/${today.day}';

    await HomeWidget.saveWidgetData('today_header', schedule.name);
    await HomeWidget.saveWidgetData('today_subtitle', subtitle);
    await HomeWidget.saveWidgetData('today_list', jsonEncode(payload));

    // Trigger only the today widget for now; more can be added later.
    // Pass class path without leading dot; plugin prefixes package automatically.
    await HomeWidget.updateWidget(androidName: 'widget.TodayWidgetProvider');
  }

  bool _isCourseInWeek(Course course, int currentWeek) {
    if (course.weekCode != null && course.weekCode!.isNotEmpty) {
      if (currentWeek > 0 && currentWeek <= course.weekCode!.length) {
        return course.weekCode![currentWeek - 1] == '1';
      }
      return false;
    }
    if (currentWeek < course.startWeek || currentWeek > course.endWeek) {
      return false;
    }
    if (course.isOddWeek && currentWeek % 2 == 0) return false;
    if (course.isEvenWeek && currentWeek % 2 != 0) return false;
    return true;
  }
}
