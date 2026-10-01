import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../utils/course_occurrences.dart';
import '../utils/time_slots.dart';

class CalendarService {
  CalendarService({DeviceCalendarPlugin? deviceCalendarPlugin})
    : _deviceCalendarPlugin = deviceCalendarPlugin ?? DeviceCalendarPlugin() {
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  static bool _tzInitialized = false;

  final DeviceCalendarPlugin _deviceCalendarPlugin;

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

    int created = 0;
    for (final course in courses) {
      if (course.isVirtual) continue;
      final weeks = courseOccurrenceWeeks(course);
      if (weeks.isEmpty) continue;

      final interval = courseWeekInterval(weeks);
      // The plugin supports regular recurrence rules, but not RDATE gaps.
      final eventWeeks = interval == null ? weeks : [weeks.first];
      var allSucceeded = true;
      for (final week in eventWeeks) {
        final baseDate = courseDateForWeek(startDate, week, course.dayOfWeek);
        final event = Event(
          calendar.id,
          title: course.courseName,
          description: course.teacher,
          location: course.classRoom,
          start: _toTz(classStartDateTime(baseDate, course.startNode)),
          end: _toTz(classEndDateTime(baseDate, course.startNode, course.step)),
          recurrenceRule: interval == null
              ? null
              : RecurrenceRule(
                  RecurrenceFrequency.Weekly,
                  interval: interval,
                  totalOccurrences: weeks.length,
                ),
        );
        final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
        if (result?.isSuccess != true) allSucceeded = false;
      }
      if (allSucceeded) created++;
    }

    return created;
  }

  tz.TZDateTime _toTz(DateTime value) => tz.TZDateTime.from(value, tz.local);
}
