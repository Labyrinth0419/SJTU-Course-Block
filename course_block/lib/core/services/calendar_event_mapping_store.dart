import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One app-owned calendar event for a persisted course occurrence.
class CalendarEventMapping {
  const CalendarEventMapping({
    required this.calendarId,
    required this.eventId,
    required this.courseId,
    required this.occurrence,
    required this.signature,
  });

  final String calendarId;
  final String eventId;
  final int courseId;
  final String occurrence;
  final String signature;

  String get key => jsonEncode([calendarId, courseId, occurrence]);

  String ownerMarker(int scheduleId) =>
      '[CourseBlock:calendar:v1:s$scheduleId:c$courseId:o$occurrence]';

  Map<String, Object> toJson() => {
    'calendarId': calendarId,
    'eventId': eventId,
    'courseId': courseId,
    'occurrence': occurrence,
    'signature': signature,
  };

  factory CalendarEventMapping.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw.length != 5 ||
        raw['calendarId'] is! String ||
        (raw['calendarId'] as String).isEmpty ||
        raw['eventId'] is! String ||
        (raw['eventId'] as String).isEmpty ||
        raw['courseId'] is! int ||
        (raw['courseId'] as int) <= 0 ||
        raw['occurrence'] is! String ||
        !RegExp(r'^(r|w[1-9][0-9]*)$').hasMatch(raw['occurrence'] as String) ||
        raw['signature'] is! String ||
        (raw['signature'] as String).isEmpty) {
      throw const FormatException('Invalid owned calendar event mapping');
    }
    return CalendarEventMapping(
      calendarId: raw['calendarId'] as String,
      eventId: raw['eventId'] as String,
      courseId: raw['courseId'] as int,
      occurrence: raw['occurrence'] as String,
      signature: raw['signature'] as String,
    );
  }
}

/// Loads and atomically replaces the owned-event mapping for one schedule.
abstract class CalendarEventMappingStore {
  Future<Map<String, CalendarEventMapping>> load(int scheduleId);
  Future<void> save(int scheduleId, Map<String, CalendarEventMapping> mappings);
}

class SharedPreferencesCalendarEventMappingStore
    implements CalendarEventMappingStore {
  static const keyPrefix = 'course_block.calendar_events.v1.schedule.';

  @override
  Future<Map<String, CalendarEventMapping>> load(int scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('$keyPrefix$scheduleId');
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 3 ||
          decoded['version'] != 1 ||
          decoded['scheduleId'] != scheduleId ||
          decoded['events'] is! List) {
        throw const FormatException('Invalid owned calendar mapping version');
      }
      final result = <String, CalendarEventMapping>{};
      final eventIds = <String>{};
      for (final item in decoded['events'] as List) {
        final mapping = CalendarEventMapping.fromJson(item);
        if (result.containsKey(mapping.key) ||
            !eventIds.add(jsonEncode([mapping.calendarId, mapping.eventId]))) {
          throw const FormatException('Duplicate owned calendar event mapping');
        }
        result[mapping.key] = mapping;
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid owned calendar event mapping');
    }
  }

  @override
  Future<void> save(
    int scheduleId,
    Map<String, CalendarEventMapping> mappings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final events = mappings.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final saved = await prefs.setString(
      '$keyPrefix$scheduleId',
      jsonEncode({
        'version': 1,
        'scheduleId': scheduleId,
        'events': [for (final event in events) event.toJson()],
      }),
    );
    if (!saved) throw StateError('Could not persist owned calendar events');
  }
}
