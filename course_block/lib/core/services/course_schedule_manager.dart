import 'package:flutter/material.dart' show Brightness;

import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/schedule.dart';
import '../theme/app_theme.dart';
import '../utils/time_slots.dart';

class CourseScheduleState {
  const CourseScheduleState({
    required this.schedules,
    required this.currentSchedule,
    required this.courses,
  });

  final List<Schedule> schedules;
  final Schedule? currentSchedule;
  final List<Course> courses;
}

class CourseScheduleManager {
  CourseScheduleManager({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<CourseScheduleState> loadScheduleState({
    required String defaultScheduleName,
  }) async {
    var schedules = await _databaseHelper.getAllSchedules();
    var currentSchedule = await _databaseHelper.getCurrentSchedule();

    if (currentSchedule == null) {
      if (schedules.isNotEmpty) {
        final fallbackSchedule = schedules.first.copyWith(isCurrent: true);
        if (fallbackSchedule.id != null) {
          await _databaseHelper.setCurrentSchedule(fallbackSchedule.id!);
        }
        currentSchedule = fallbackSchedule;
        schedules = [
          for (final schedule in schedules)
            schedule.id == fallbackSchedule.id
                ? fallbackSchedule
                : schedule.copyWith(isCurrent: false),
        ];
      } else {
        final now = DateTime.now();
        final today = normalizeDate(now);
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

        final defaultSchedule = Schedule(
          name: defaultScheduleName,
          year: now.year.toString(),
          term: '1',
          startDate: startOfWeek,
          isCurrent: true,
        );
        final id = await _databaseHelper.insertSchedule(defaultSchedule);
        currentSchedule = defaultSchedule.copyWith(id: id);
        schedules = [currentSchedule];
      }
    }

    final courses = currentSchedule.id == null
        ? <Course>[]
        : await _databaseHelper.getCoursesBySchedule(currentSchedule.id!);

    return CourseScheduleState(
      schedules: schedules,
      currentSchedule: currentSchedule,
      courses: courses,
    );
  }

  Future<void> switchSchedule(int scheduleId) async {
    await _databaseHelper.setCurrentSchedule(scheduleId);
  }

  Future<int> addSchedule(
    String name,
    String year,
    String term, {
    DateTime? startDate,
  }) async {
    final today = normalizeDate(DateTime.now());
    final startOfWeek = startDate != null
        ? normalizeDate(startDate)
        : today.subtract(Duration(days: today.weekday - 1));
    final schedule = Schedule(
      name: name,
      year: year,
      term: term,
      startDate: startOfWeek,
      isCurrent: true,
    );
    return _databaseHelper.insertSchedule(schedule);
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _databaseHelper.deleteSchedule(scheduleId);
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await _databaseHelper.updateSchedule(schedule);
  }

  Future<List<Course>> normalizeCourseColors({
    required List<Course> courses,
    required AppCourseColorPalette courseColorPalette,
  }) async {
    if (courses.isEmpty) {
      return courses;
    }

    final assignments = assignScheduledCourseColorTokens(
      courses.map(
        (course) => CourseColorIdentityEntry(
          identity: buildCourseColorSeed(course.courseName, course.teacher),
          colorValue: course.color,
        ),
      ),
      swatches: courseColorPalette.colors(Brightness.light),
    );

    if (assignments.isEmpty) {
      return courses;
    }

    final updatedCourses = <Course>[];
    var hasChanges = false;

    for (final course in courses) {
      final identity = buildCourseColorSeed(course.courseName, course.teacher);
      final assignedColor = assignments[identity] ?? course.color;
      final updatedCourse = assignedColor == course.color
          ? course
          : course.copyWith(color: assignedColor);

      if (updatedCourse.color != course.color) {
        hasChanges = true;
        if (updatedCourse.id != null) {
          await _databaseHelper.updateCourse(updatedCourse);
        }
      }

      updatedCourses.add(updatedCourse);
    }

    return hasChanges ? updatedCourses : courses;
  }
}
