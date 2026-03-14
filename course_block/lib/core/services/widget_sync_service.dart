import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/schedule.dart';
import '../theme/app_theme.dart';
import '../utils/time_slots.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._();

  static const List<String> _weekdaysShort = [
    '', // index 0 unused
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Push today's courses to the Android home widget.
  Future<void> updateTodayWidget(
    List<Course> courses,
    Schedule? schedule, {
    required int totalWeeks,
    required AppThemeScheme themeScheme,
    required ThemeMode themeMode,
    required AppCourseColorPalette courseColorPalette,
  }) async {
    await HomeWidget.saveWidgetData('theme_scheme', themeScheme.storageKey);
    await HomeWidget.saveWidgetData(
      'theme_mode',
      _themeModeToStorage(themeMode),
    );
    await HomeWidget.saveWidgetData(
      'course_palette',
      courseColorPalette.storageKey,
    );

    if (schedule == null) {
      await HomeWidget.saveWidgetData('today_header', '课程表');
      await HomeWidget.saveWidgetData('today_subtitle', '');
      await HomeWidget.saveWidgetData('today_list', '[]');
      await HomeWidget.saveWidgetData('day_list', '[]');
      await HomeWidget.saveWidgetData('upcoming_list', '[]');
      await HomeWidget.saveWidgetData('week_list', '[]');
      await _updateAllWidgets();
      return;
    }

    final today = normalizeDate(DateTime.now());
    final start = normalizeDate(schedule.startDate);
    final diffDays = today.difference(start).inDays;
    var currentWeek = (diffDays / 7).floor() + 1;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > totalWeeks) currentWeek = totalWeeks;

    final weekdayShort = _weekdaysShort[today.weekday]; // weekday is 1–7

    final now = DateTime.now();
    final todayCourses =
        courses
            .where((c) => _isCourseInWeek(c, currentWeek))
            .where((c) => c.dayOfWeek == today.weekday)
            .where((c) => _courseEndTime(today, c).isAfter(now))
            .toList()
          ..sort((a, b) => a.startNode.compareTo(b.startNode));

    final payload = todayCourses
        .map(
          (c) => _coursePayload(
            c,
            timeRange: _formatTimeRange(c.startNode, c.step),
          ),
        )
        .toList();

    final subtitle = '${today.month}.${today.day}  $weekdayShort';

    await HomeWidget.saveWidgetData('today_header', schedule.name);
    await HomeWidget.saveWidgetData('today_subtitle', subtitle);
    await HomeWidget.saveWidgetData('today_list', jsonEncode(payload));
    await HomeWidget.updateWidget(androidName: 'widget.TodayWidgetProvider');

    // ── day_list：今天全部课程（含已结束），携带 status 字段 ──────────────────
    final allTodayCourses =
        courses
            .where((c) => _isCourseInWeek(c, currentWeek))
            .where((c) => c.dayOfWeek == today.weekday)
            .toList()
          ..sort((a, b) => a.startNode.compareTo(b.startNode));

    final dayPayload = allTodayCourses.map((c) {
      final end = _courseEndTime(today, c);
      final start2 = _courseStartDateTime(today, c);
      final String status;
      if (end.isBefore(now)) {
        status = 'done';
      } else if (start2.isBefore(now)) {
        status = 'current';
      } else {
        status = 'upcoming';
      }
      return {
        ..._coursePayload(c, timeRange: _formatTimeRange(c.startNode, c.step)),
        'status': status,
      };
    }).toList();

    await HomeWidget.saveWidgetData('day_list', jsonEncode(dayPayload));
    await HomeWidget.updateWidget(androidName: 'widget.DayWidgetProvider');

    // ── upcoming_list：近 3 天课程（含今日剩余），带日期标题 ──────────────────
    final upcomingItems = <Map<String, String>>[];
    for (int offset = 0; offset < 3; offset++) {
      final date = today.add(Duration(days: offset));
      final diffOff = date.difference(start).inDays;
      final weekOff = ((diffOff / 7).floor() + 1).clamp(1, totalWeeks);

      final dayCourses =
          courses
              .where((c) => _isCourseInWeek(c, weekOff))
              .where((c) => c.dayOfWeek == date.weekday)
              .where(
                (c) =>
                    offset == 0 ? _courseEndTime(date, c).isAfter(now) : true,
              )
              .toList()
            ..sort((a, b) => a.startNode.compareTo(b.startNode));

      if (dayCourses.isEmpty) continue;

      final dayLabel = offset == 0
          ? 'Today ${date.month}.${date.day}'
          : offset == 1
          ? 'Tmr ${date.month}.${date.day}'
          : '${_weekdaysShort[date.weekday]} ${date.month}.${date.day}';
      upcomingItems.add({'t': 'header', 'label': dayLabel});
      for (final c in dayCourses) {
        upcomingItems.add({
          't': 'course',
          ..._coursePayload(
            c,
            timeRange: _formatTimeRange(c.startNode, c.step),
          ),
        });
      }
    }

    await HomeWidget.saveWidgetData('upcoming_list', jsonEncode(upcomingItems));
    await HomeWidget.updateWidget(androidName: 'widget.UpcomingWidgetProvider');

    // ── week_list：本周（周一到周日）课程，带日期标题 ─────────────────────────
    final weekItems = <Map<String, String>>[];
    final mondayOffset = -(today.weekday - 1);
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: mondayOffset + i));
      final diffW = date.difference(start).inDays;
      final weekW = ((diffW / 7).floor() + 1).clamp(1, totalWeeks);
      final wd = i + 1; // 1=Mon … 7=Sun

      final dayCourses =
          courses
              .where((c) => _isCourseInWeek(c, weekW))
              .where((c) => c.dayOfWeek == wd)
              .toList()
            ..sort((a, b) => a.startNode.compareTo(b.startNode));

      if (dayCourses.isEmpty) continue;

      final isToday = wd == today.weekday;
      final label =
          '${_weekdaysShort[wd]}${isToday ? ' ●' : ''} ${date.month}.${date.day}';
      weekItems.add({'t': 'header', 'label': label});
      for (final c in dayCourses) {
        weekItems.add({
          't': 'course',
          ..._coursePayload(
            c,
            timeRange: _formatTimeRange(c.startNode, c.step),
          ),
        });
      }
    }

    await HomeWidget.saveWidgetData('week_list', jsonEncode(weekItems));
    await HomeWidget.updateWidget(androidName: 'widget.WeekWidgetProvider');
  }

  Map<String, String> _coursePayload(
    Course course, {
    required String timeRange,
  }) {
    return {
      'name': course.courseName,
      'room': course.classRoom,
      'timeRange': timeRange,
      'color': course.color,
    };
  }

  String _themeModeToStorage(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  Future<void> _updateAllWidgets() async {
    await HomeWidget.updateWidget(androidName: 'widget.TodayWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'widget.DayWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'widget.UpcomingWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'widget.WeekWidgetProvider');
  }

  /// 返回某门课的开始时刻（DateTime）。
  DateTime _courseStartDateTime(DateTime baseDate, Course course) {
    final startIdx = (course.startNode - 1).clamp(
      0,
      kClassStartTimes.length - 1,
    );
    final parts = kClassStartTimes[startIdx].split(':');
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 返回某门课的结束时刻（DateTime）。
  DateTime _courseEndTime(DateTime baseDate, Course course) {
    final endIdx = (course.startNode + course.step - 2).clamp(
      0,
      kClassEndTimes.length - 1,
    );
    final parts = kClassEndTimes[endIdx].split(':');
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 将节次号和步长转换为 "HH:mm-HH:mm" 格式字符串，例如 "08:00-09:40"。
  String _formatTimeRange(int startNode, int step) {
    if (startNode < 1) return '';
    final startIdx = (startNode - 1).clamp(0, kClassStartTimes.length - 1);
    final endIdx = (startNode + step - 2).clamp(0, kClassEndTimes.length - 1);
    final startTime = _pad(kClassStartTimes[startIdx]);
    final endTime = _pad(kClassEndTimes[endIdx]);
    return '$startTime-$endTime';
  }

  /// 补零，将 "8:00" → "08:00"。
  String _pad(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    return '$h:$m';
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
