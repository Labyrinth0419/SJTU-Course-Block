import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../utils/time_slots.dart';

class CalendarService {
  CalendarService() {
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  static bool _tzInitialized = false;

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<bool> _ensurePermission() async {
    final hasPermissionResult = await _deviceCalendarPlugin.hasPermissions();
    if (hasPermissionResult.data == true) return true;

    final requestResult = await _deviceCalendarPlugin.requestPermissions();
    return requestResult.data == true;
  }

  Future<Calendar?> _pickWritableCalendar() async {
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    final calendars = (calendarsResult.data ?? <Calendar>[]).cast<Calendar>();
    if (calendars.isEmpty) return null;

    // prefer default or primary calendars that are writable
    final writable = calendars
        .where((c) => (c.isReadOnly ?? false) == false)
        .toList();
    if (writable.isEmpty) return null;

    // device_calendar Calendar模型仅提供 isReadOnly 等字段，这里直接返回首个可写日历
    return writable.first;
  }

  Future<int> importCourses(List<Course> courses, DateTime startDate) async {
    final granted = await _ensurePermission();
    if (!granted) return 0;

    final calendar = await _pickWritableCalendar();
    if (calendar == null) return 0;

    // Align startDate to the Monday of its week, so that dayOfWeek offsets
    // are always calculated from a Monday baseline.
    final normalized = normalizeDate(startDate);
    final normalizedStart = normalized.subtract(
      Duration(days: normalized.weekday - 1),
    );

    int created = 0;
    for (final course in courses) {
      if (course.isVirtual) continue;
      final baseDate = normalizedStart.add(
        Duration(days: (course.startWeek - 1) * 7 + (course.dayOfWeek - 1)),
      );
      final start = classStartDateTime(baseDate, course.startNode);
      final end = classEndDateTime(baseDate, course.startNode, course.step);

      int interval = 1;
      int count = course.endWeek - course.startWeek + 1;
      if (course.isOddWeek ^ course.isEvenWeek) {
        interval = 2;
        count = ((course.endWeek - course.startWeek) / 2).floor() + 1;
      }

      // Build the recurrence rule only when there are multiple occurrences.
      RecurrenceRule? recurrenceRule;
      if (count > 1) {
        recurrenceRule = RecurrenceRule(
          RecurrenceFrequency.Weekly,
          interval: interval,
          totalOccurrences: count,
        );
      }

      final event = Event(
        calendar.id,
        title: course.courseName,
        description: course.teacher,
        location: course.classRoom,
        start: _toTz(start),
        end: _toTz(end),
        recurrenceRule: recurrenceRule,
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true) {
        created++;
      }
    }

    return created;
  }

  tz.TZDateTime _toTz(DateTime value) => tz.TZDateTime.from(value, tz.local);
}
