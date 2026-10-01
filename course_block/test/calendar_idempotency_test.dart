import 'dart:async';
import 'dart:collection';

import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/services/calendar_event_mapping_store.dart';
import 'package:course_block/core/services/calendar_service.dart';
import 'package:course_block/core/services/course_transfer_manager.dart';
import 'package:device_calendar/device_calendar.dart' as calendar;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _termStart = DateTime(2026, 3, 2);

Course _course({
  int? id = 10,
  String room = 'A101',
  String? weekCode,
  int node = 1,
  bool virtual = false,
}) => Course(
  id: id,
  scheduleId: 7,
  courseId: 'same-upstream-id',
  courseName: 'Math',
  teacher: 'Tutor',
  classRoom: room,
  startWeek: 1,
  endWeek: 8,
  dayOfWeek: 3,
  startNode: node,
  step: 2,
  weekCode: weekCode,
  isVirtual: virtual,
);

class _MemoryMappings implements CalendarEventMappingStore {
  final data = <int, Map<String, CalendarEventMapping>>{};

  @override
  Future<Map<String, CalendarEventMapping>> load(int scheduleId) async => {
    ...?data[scheduleId],
  };

  @override
  Future<void> save(
    int scheduleId,
    Map<String, CalendarEventMapping> mappings,
  ) async {
    data[scheduleId] = {...mappings};
  }
}

class _Calendar extends calendar.DeviceCalendarPlugin {
  _Calendar() : super.private();

  final events = <String, calendar.Event>{};
  var writes = 0;
  var deletions = 0;
  var nextId = 0;
  int? failWriteAt;
  bool failDeleteOnce = false;
  bool permission = true;
  bool permissionError = false;
  List<String> calendars = ['test'];
  Completer<void>? writeEntered;
  Completer<void>? resumeWrite;

  void addUnrelated() {
    events['personal'] = calendar.Event(
      'test',
      eventId: 'personal',
      title: 'Math',
      description: 'My private appointment',
      location: 'A101',
    );
  }

  @override
  Future<calendar.Result<bool>> hasPermissions() async =>
      calendar.Result<bool>()
        ..data = permission
        ..errors = [
          if (permissionError)
            const calendar.ResultError(1, 'permission error'),
        ];

  @override
  Future<calendar.Result<bool>> requestPermissions() async =>
      calendar.Result<bool>()
        ..data = permission
        ..errors = [
          if (permissionError)
            const calendar.ResultError(1, 'permission error'),
        ];

  @override
  Future<calendar.Result<UnmodifiableListView<calendar.Calendar>>>
  retrieveCalendars() async =>
      calendar.Result<UnmodifiableListView<calendar.Calendar>>()
        ..data = UnmodifiableListView([
          for (final id in calendars)
            calendar.Calendar(id: id, isReadOnly: false),
        ]);

  @override
  Future<calendar.Result<UnmodifiableListView<calendar.Event>>> retrieveEvents(
    String? calendarId,
    calendar.RetrieveEventsParams? params,
  ) async =>
      calendar.Result<UnmodifiableListView<calendar.Event>>()
        ..data = UnmodifiableListView([
          for (final id in params!.eventIds!)
            if (events.containsKey(id) && events[id]!.calendarId == calendarId)
              events[id]!,
        ]);

  @override
  Future<calendar.Result<String>?> createOrUpdateEvent(
    calendar.Event? event,
  ) async {
    writes++;
    if (writes == 1 && resumeWrite != null) {
      writeEntered!.complete();
      await resumeWrite!.future;
    }
    if (failWriteAt == writes) return calendar.Result<String>();
    final id = event!.eventId ?? '${++nextId}';
    event.eventId = id;
    events[id] = event;
    return calendar.Result<String>()..data = id;
  }

  @override
  Future<calendar.Result<bool>> deleteEvent(
    String? calendarId,
    String? eventId,
  ) async {
    deletions++;
    if (failDeleteOnce) {
      failDeleteOnce = false;
      return calendar.Result<bool>()..data = false;
    }
    if (events[eventId]?.calendarId != calendarId) {
      return calendar.Result<bool>()..data = false;
    }
    return calendar.Result<bool>()..data = (events.remove(eventId) != null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('duplicate import survives service and preferences reload', () async {
    final plugin = _Calendar()..addUnrelated();
    expect(
      await CalendarService(
        deviceCalendarPlugin: plugin,
      ).importCourses([_course()], _termStart, scheduleId: 7),
      1,
    );
    expect(
      await CalendarService(
        deviceCalendarPlugin: plugin,
      ).importCourses([_course()], _termStart, scheduleId: 7),
      1,
    );
    expect(plugin.events, hasLength(2));
    expect(plugin.writes, 1);
    final persisted = await SharedPreferencesCalendarEventMappingStore().load(
      7,
    );
    expect(persisted.values.single.calendarId, 'test');
    expect(persisted.values.single.eventId, '1');
    expect(persisted.values.single.courseId, 10);
    expect(persisted.values.single.occurrence, 'r');
    expect(persisted.values.single.signature, isNotEmpty);
    expect(plugin.deletions, 0);
    expect(plugin.events['personal']!.description, 'My private appointment');
  });

  test(
    'edited time and room update only the course row, not a sibling',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses(
          [_course(), _course(id: 11)],
          _termStart,
          scheduleId: 7,
        ),
        2,
      );
      final originalId = store.data[7]!.values
          .singleWhere((m) => m.courseId == 10)
          .eventId;
      final siblingId = store.data[7]!.values
          .singleWhere((m) => m.courseId == 11)
          .eventId;
      final previousStart = plugin.events[originalId]!.start!;
      expect(
        await service.importCourses(
          [_course(room: 'B202', node: 3), _course(id: 11)],
          _termStart,
          scheduleId: 7,
        ),
        2,
      );
      expect(plugin.events, hasLength(3));
      expect(plugin.writes, 3);
      expect(plugin.events[originalId]!.location, 'B202');
      expect(
        plugin.events[originalId]!.start!.difference(previousStart),
        const Duration(hours: 2),
      );
      expect(plugin.events[siblingId]!.location, 'A101');
      expect(plugin.events['personal']!.description, 'My private appointment');
    },
  );

  test('manager forwards schedule identity to the calendar import', () async {
    final plugin = _Calendar();
    final manager = CourseTransferManager(
      calendarService: CalendarService(deviceCalendarPlugin: plugin),
    );
    expect(
      await manager.importToSystemCalendar(
        [_course()],
        _termStart,
        scheduleId: 7,
      ),
      1,
    );
    expect(
      await manager.importToSystemCalendar(
        [_course()],
        _termStart,
        scheduleId: 7,
      ),
      1,
    );
    expect(plugin.events, hasLength(1));
  });

  test(
    'sparse edits, sparse-to-regular, and removal clean only owned dates',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses(
          [_course(weekCode: '10100001')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(store.data[7]!.values.map((m) => m.occurrence).toSet(), {
        'w1',
        'w3',
        'w8',
      });
      expect(plugin.events, hasLength(4));

      expect(
        await service.importCourses(
          [_course(weekCode: '10100100')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(store.data[7]!.values.map((m) => m.occurrence).toSet(), {
        'w1',
        'w3',
        'w6',
      });
      expect(plugin.events, hasLength(4));

      expect(
        await service.importCourses(
          [_course(weekCode: '11111111')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(store.data[7]!.values.single.occurrence, 'r');
      expect(plugin.events, hasLength(2));
      expect(
        plugin.events.values
            .singleWhere((e) => e.eventId != 'personal')
            .recurrenceRule!
            .totalOccurrences,
        8,
      );

      expect(
        await service.importCourses(
          [_course(weekCode: '10100001')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(store.data[7]!.values.map((m) => m.occurrence).toSet(), {
        'w1',
        'w3',
        'w8',
      });
      expect(plugin.events, hasLength(4));

      expect(await service.importCourses([], _termStart, scheduleId: 7), 0);
      expect(plugin.events.keys, {'personal'});
      expect(store.data[7], isEmpty);
    },
  );

  test(
    'partial write failure persists each success and retry fills only missing week',
    () async {
      final plugin = _Calendar()..failWriteAt = 2;
      final store = _MemoryMappings();
      expect(
        await CalendarService(
          deviceCalendarPlugin: plugin,
          mappingStore: store,
        ).importCourses(
          [_course(weekCode: '10100001')],
          _termStart,
          scheduleId: 7,
        ),
        0,
      );
      expect(store.data[7], hasLength(2));
      expect(plugin.events, hasLength(2));
      expect(
        await CalendarService(
          deviceCalendarPlugin: plugin,
          mappingStore: store,
        ).importCourses(
          [_course(weekCode: '10100001')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(store.data[7], hasLength(3));
      expect(plugin.events, hasLength(3));
      expect(plugin.writes, 4);
    },
  );

  test('failed update keeps event ID and retries in place', () async {
    final plugin = _Calendar();
    final store = _MemoryMappings();
    final service = CalendarService(
      deviceCalendarPlugin: plugin,
      mappingStore: store,
    );
    expect(
      await service.importCourses([_course()], _termStart, scheduleId: 7),
      1,
    );
    final id = store.data[7]!.values.single.eventId;
    plugin.failWriteAt = 2;
    expect(
      await service.importCourses(
        [_course(room: 'B202')],
        _termStart,
        scheduleId: 7,
      ),
      0,
    );
    expect(store.data[7]!.values.single.eventId, id);
    expect(plugin.events[id]!.location, 'A101');
    expect(
      await CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      ).importCourses([_course(room: 'B202')], _termStart, scheduleId: 7),
      1,
    );
    expect(plugin.events.keys, {id});
    expect(plugin.events[id]!.location, 'B202');
  });

  test(
    'failed cleanup retains mapping for retry without recreating regular event',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses(
          [_course(weekCode: '10100001')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      plugin.failDeleteOnce = true;
      expect(
        await service.importCourses(
          [_course(weekCode: '11111111')],
          _termStart,
          scheduleId: 7,
        ),
        0,
      );
      expect(store.data[7], hasLength(4));
      final writes = plugin.writes;
      expect(
        await CalendarService(
          deviceCalendarPlugin: plugin,
          mappingStore: store,
        ).importCourses(
          [_course(weekCode: '11111111')],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(plugin.writes, writes);
      expect(store.data[7], hasLength(1));
      expect(plugin.events, hasLength(2));
      expect(plugin.events['personal']!.description, 'My private appointment');
    },
  );

  test(
    'manually deleted event is replaced, recycled ID without marker is not edited',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      final oldId = store.data[7]!.values.single.eventId;
      plugin.events.remove(oldId);
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      final newId = store.data[7]!.values.single.eventId;
      expect(newId, isNot(oldId));

      plugin.events[newId] = calendar.Event(
        'test',
        eventId: newId,
        title: 'User appointment',
        description: 'Not owned',
      );
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      expect(plugin.events[newId]!.title, 'User appointment');
      expect(plugin.events['personal']!.description, 'My private appointment');
      expect(plugin.deletions, 0);
      expect(store.data[7]!.values.single.eventId, isNot(newId));
    },
  );

  test(
    'calendar change defers old cleanup when unavailable, then verifies ownership',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      final oldId = store.data[7]!.values.single.eventId;
      plugin.calendars = ['new'];
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      expect(store.data[7], hasLength(2));
      expect(plugin.events[oldId]!.calendarId, 'test');
      plugin.events[oldId]!.description = 'User edited away the marker';
      plugin.calendars = ['new', 'test'];
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      expect(store.data[7], hasLength(1));
      expect(plugin.events[oldId]!.description, 'User edited away the marker');
      expect(plugin.deletions, 0);
    },
  );

  test(
    'corrupt mapping fails closed; permission denial does not claim success',
    () async {
      final plugin = _Calendar()..addUnrelated();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${SharedPreferencesCalendarEventMappingStore.keyPrefix}7',
        '{not json',
      );
      final service = CalendarService(deviceCalendarPlugin: plugin);
      await expectLater(
        service.importCourses([_course()], _termStart, scheduleId: 7),
        throwsFormatException,
      );
      expect(plugin.events.keys, {'personal'});
      expect(plugin.deletions, 0);
      plugin.permission = false;
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        0,
      );
      plugin.permission = true;
      plugin.permissionError = true;
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        0,
      );
    },
  );

  test(
    'simultaneous imports across instances serialize around shared scope',
    () async {
      final plugin = _Calendar()
        ..writeEntered = Completer<void>()
        ..resumeWrite = Completer<void>();
      final store = _MemoryMappings();
      final first = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      ).importCourses([_course()], _termStart, scheduleId: 7);
      await plugin.writeEntered!.future;
      final second = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      ).importCourses([_course()], _termStart, scheduleId: 7);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(plugin.writes, 1);
      plugin.resumeWrite!.complete();
      expect(await Future.wait([first, second]), [1, 1]);
      expect(plugin.writes, 1);
      expect(plugin.events, hasLength(1));
    },
  );

  test(
    'null database ID uses safe create-only fallback even with schedule ID',
    () async {
      final plugin = _Calendar();
      final store = _MemoryMappings();
      final service = CalendarService(
        deviceCalendarPlugin: plugin,
        mappingStore: store,
      );
      expect(
        await service.importCourses(
          [_course(id: null)],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(
        await service.importCourses(
          [_course(id: null)],
          _termStart,
          scheduleId: 7,
        ),
        1,
      );
      expect(await service.importCourses([], _termStart, scheduleId: 7), 0);
      expect(plugin.events, hasLength(2));
      expect(plugin.deletions, 0);
      expect(store.data[7], isNull);
    },
  );

  test(
    'virtual course clears earlier owned events without counting as import',
    () async {
      final plugin = _Calendar();
      final service = CalendarService(deviceCalendarPlugin: plugin);
      expect(
        await service.importCourses([_course()], _termStart, scheduleId: 7),
        1,
      );
      expect(
        await service.importCourses(
          [_course(virtual: true)],
          _termStart,
          scheduleId: 7,
        ),
        0,
      );
      expect(plugin.events, isEmpty);
    },
  );
}
