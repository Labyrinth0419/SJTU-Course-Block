import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/schedule.dart';
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
  }) async {
    if (schedule == null) return;

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
          (c) => {
            'name': c.courseName,
            'room': c.classRoom,
            'timeRange': _formatTimeRange(c.startNode, c.step),
          },
        )
        .toList();

    final subtitle = '${today.month}.${today.day}  $weekdayShort';

    await HomeWidget.saveWidgetData('today_header', schedule.name);
    await HomeWidget.saveWidgetData('today_subtitle', subtitle);
    await HomeWidget.saveWidgetData('today_list', jsonEncode(payload));

    await HomeWidget.updateWidget(androidName: 'widget.TodayWidgetProvider');
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
