import 'dart:async';
import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../utils/course_occurrences.dart';
import '../utils/time_slots.dart';
import 'calendar_event_mapping_store.dart';

class CalendarService {
  CalendarService({
    DeviceCalendarPlugin? deviceCalendarPlugin,
    CalendarEventMappingStore? mappingStore,
  }) : _deviceCalendarPlugin = deviceCalendarPlugin ?? DeviceCalendarPlugin(),
       _mappingStore =
           mappingStore ?? SharedPreferencesCalendarEventMappingStore() {
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  static bool _tzInitialized = false;
  static final Map<int, Future<void>> _scheduleTails = {};

  final DeviceCalendarPlugin _deviceCalendarPlugin;
  final CalendarEventMappingStore _mappingStore;

  Future<bool> _ensurePermission() async {
    final hasPermissionResult = await _deviceCalendarPlugin.hasPermissions();
    if (hasPermissionResult.isSuccess && hasPermissionResult.data == true) {
      return true;
    }

    final requestResult = await _deviceCalendarPlugin.requestPermissions();
    return requestResult.isSuccess && requestResult.data == true;
  }

  Future<List<Calendar>> _writableCalendars() async {
    final result = await _deviceCalendarPlugin.retrieveCalendars();
    if (!result.isSuccess) return [];
    return (result.data ?? <Calendar>[])
        .where(
          (c) => (c.isReadOnly ?? false) == false && c.id?.isNotEmpty == true,
        )
        .toList();
  }

  /// With a schedule ID and persisted course IDs, imports are reconciled across runs.
  /// Null-ID courses (or calls without a schedule ID) are create-only: they have
  /// no durable identity from which to establish ownership or safely clean up.
  Future<int> importCourses(
    List<Course> courses,
    DateTime startDate, {
    int? scheduleId,
  }) {
    if (scheduleId == null) {
      return _import(courses, startDate, null);
    }
    return _serialForSchedule(
      scheduleId,
      () => _import(courses, startDate, scheduleId),
    );
  }

  // A shared queue prevents two service instances from reading the same old
  // snapshot and both creating an event before either mapping is saved.
  Future<T> _serialForSchedule<T>(
    int scheduleId,
    Future<T> Function() work,
  ) async {
    final previous = _scheduleTails[scheduleId] ?? Future<void>.value();
    final done = Completer<void>();
    _scheduleTails[scheduleId] = done.future;
    try {
      await previous;
      return await work();
    } finally {
      if (identical(_scheduleTails[scheduleId], done.future)) {
        _scheduleTails.remove(scheduleId);
      }
      done.complete();
    }
  }

  Future<int> _import(
    List<Course> courses,
    DateTime startDate,
    int? scheduleId,
  ) async {
    if (!await _ensurePermission()) return 0;
    final writable = await _writableCalendars();
    if (writable.isEmpty) return 0;
    final calendarId = writable.first.id!;
    final writableIds = {for (final calendar in writable) calendar.id!};
    final mappings = scheduleId == null
        ? <String, CalendarEventMapping>{}
        : await _mappingStore.load(scheduleId);
    if (mappings.entries.any((entry) => entry.key != entry.value.key)) {
      throw const FormatException('Invalid owned calendar event mapping');
    }
    final desiredKeys = <String>{};
    final succeeded = <int, bool>{};
    var statelessCount = 0;

    for (final course in courses) {
      if (course.isVirtual) continue;
      final weeks = courseOccurrenceWeeks(course);
      if (weeks.isEmpty) continue;
      if (scheduleId != null &&
          course.scheduleId != null &&
          course.scheduleId != scheduleId) {
        throw ArgumentError('Course belongs to a different schedule');
      }

      final interval = courseWeekInterval(weeks);
      // The plugin supports regular recurrence rules, but not RDATE gaps.
      final eventWeeks = interval == null ? weeks : [weeks.first];
      final persisted =
          scheduleId != null && course.id != null && course.id! > 0;
      var allSucceeded = true;
      for (final week in eventWeeks) {
        final occurrence = interval == null ? 'w$week' : 'r';
        final mapping = persisted
            ? CalendarEventMapping(
                calendarId: calendarId,
                eventId: '',
                courseId: course.id!,
                occurrence: occurrence,
                signature: '',
              )
            : null;
        final key = mapping?.key;
        if (key != null) desiredKeys.add(key);
        var previous = key == null ? null : mappings[key];
        if (previous != null &&
            await _ownedEvent(previous, scheduleId!) == null) {
          // The ID may have been recycled or the user changed the event. In
          // either case, never overwrite or delete an event without our marker.
          mappings.remove(key);
          await _mappingStore.save(scheduleId, mappings);
          previous = null;
        }

        final baseDate = courseDateForWeek(startDate, week, course.dayOfWeek);
        final start = _toTz(classStartDateTime(baseDate, course.startNode));
        final end = _toTz(
          classEndDateTime(baseDate, course.startNode, course.step),
        );
        final signature = jsonEncode([
          course.courseName,
          course.teacher,
          course.classRoom,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          interval,
          interval == null ? null : weeks.length,
        ]);
        if (previous?.signature == signature) continue;
        final marker = mapping?.ownerMarker(scheduleId!);
        final event = Event(
          calendarId,
          eventId: previous?.eventId,
          title: course.courseName,
          description: marker == null
              ? course.teacher
              : '${course.teacher}\n$marker',
          location: course.classRoom,
          start: start,
          end: end,
          recurrenceRule: interval == null
              ? null
              : RecurrenceRule(
                  RecurrenceFrequency.Weekly,
                  interval: interval,
                  totalOccurrences: weeks.length,
                ),
        );
        final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
        if (result?.isSuccess != true) {
          allSucceeded = false;
          continue;
        }
        if (mapping != null) {
          mappings[key!] = CalendarEventMapping(
            calendarId: calendarId,
            eventId: result!.data!,
            courseId: mapping.courseId,
            occurrence: occurrence,
            signature: signature,
          );
          // A later failure must not recreate an event already written.
          await _mappingStore.save(scheduleId!, mappings);
        }
      }
      if (persisted) {
        succeeded[course.id!] = allSucceeded;
      } else if (allSucceeded) {
        statelessCount++;
      }
    }

    if (scheduleId != null) {
      for (final entry in mappings.entries.toList()) {
        if (desiredKeys.contains(entry.key) ||
            succeeded[entry.value.courseId] == false) {
          continue;
        }
        final old = entry.value;
        if (!writableIds.contains(old.calendarId)) {
          // The old calendar is unavailable or read-only; retain ownership
          // until it becomes writable again, rather than guessing an ID.
          continue;
        }
        final owned = await _ownedEvent(old, scheduleId);
        if (owned != null) {
          final deleted = await _deviceCalendarPlugin.deleteEvent(
            old.calendarId,
            old.eventId,
          );
          if (deleted.isSuccess != true || deleted.data != true) {
            if (succeeded.containsKey(old.courseId)) {
              succeeded[old.courseId] = false;
            }
            continue;
          }
        }
        mappings.remove(entry.key);
        await _mappingStore.save(scheduleId, mappings);
      }
    }
    return statelessCount + succeeded.values.where((success) => success).length;
  }

  Future<Event?> _ownedEvent(
    CalendarEventMapping mapping,
    int scheduleId,
  ) async {
    final result = await _deviceCalendarPlugin.retrieveEvents(
      mapping.calendarId,
      RetrieveEventsParams(eventIds: [mapping.eventId]),
    );
    if (!result.isSuccess) {
      throw StateError('Could not verify owned calendar event');
    }
    final marker = mapping.ownerMarker(scheduleId);
    for (final event in result.data!) {
      if (event.eventId == mapping.eventId &&
          event.calendarId == mapping.calendarId &&
          (event.description == marker ||
              event.description?.endsWith('\n$marker') == true)) {
        return event;
      }
    }
    return null;
  }

  tz.TZDateTime _toTz(DateTime value) => tz.TZDateTime.from(value, tz.local);
}
