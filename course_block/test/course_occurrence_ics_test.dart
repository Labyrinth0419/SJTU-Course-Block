import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/services/calendar_service.dart';
import 'package:course_block/core/services/course_transfer_manager.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/core/utils/course_occurrences.dart';
import 'package:device_calendar/device_calendar.dart' as calendar;
import 'package:flutter_test/flutter_test.dart';

final _semesterStart = DateTime(2026, 3, 2); // Monday

Course _course({
  int startWeek = 1,
  int endWeek = 8,
  String? weekCode,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  bool isVirtual = false,
}) => Course(
  courseId: 'C1',
  courseName: 'Math',
  teacher: 'Tutor',
  classRoom: 'A101',
  startWeek: startWeek,
  endWeek: endWeek,
  dayOfWeek: 3,
  startNode: 1,
  step: 2,
  isOddWeek: isOddWeek,
  isEvenWeek: isEvenWeek,
  weekCode: weekCode,
  isVirtual: isVirtual,
);

class _RecordingDatabase implements DatabaseHelper {
  final courses = <Course>[];

  @override
  Future<int> insertCourse(Course course) async {
    courses.add(course);
    return courses.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingCalendar extends calendar.DeviceCalendarPlugin {
  _RecordingCalendar() : super.private();

  final events = <calendar.Event>[];

  @override
  Future<calendar.Result<bool>> hasPermissions() async =>
      calendar.Result<bool>()..data = true;

  @override
  Future<calendar.Result<UnmodifiableListView<calendar.Calendar>>>
  retrieveCalendars() async =>
      calendar.Result<UnmodifiableListView<calendar.Calendar>>()
        ..data = UnmodifiableListView([
          calendar.Calendar(id: 'test', isReadOnly: false),
        ]);

  @override
  Future<calendar.Result<String>?> createOrUpdateEvent(
    calendar.Event? event,
  ) async {
    events.add(event!);
    return calendar.Result<String>()..data = '${events.length}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('course-ics-'),
  );
  tearDown(() async => temp.delete(recursive: true));

  Future<List<Course>> importedCourses(String ics, DateTime startDate) async {
    final db = _RecordingDatabase();
    final file = File('${temp.path}/import.ics');
    await file.writeAsString(ics);
    final result = await CourseTransferManager(databaseHelper: db)
        .importCoursesIcs(
          path: file.path,
          scheduleId: 1,
          startDate: startDate,
          courseColorPalette: AppCourseColorPalette.candyBox,
        );
    expect(
      result.failed,
      0,
      reason: result.failures.map((f) => f.reason).join(', '),
    );
    expect(result.added, 1);
    return db.courses;
  }

  Future<String> export(Course course, DateTime startDate) async => utf8.decode(
    await CourseTransferManager().exportCoursesIcsBytes([course], startDate),
  );

  test('sparse weekCode exports and imports only weeks 1, 3 and 8', () async {
    final course = _course(
      startWeek: 2,
      endWeek: 5,
      weekCode: '10100001',
      isEvenWeek: true,
    );
    final ics = await export(course, _semesterStart);
    expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260304T080000'));
    expect(ics, contains('RDATE'));
    final imported = (await importedCourses(ics, _semesterStart)).single;
    expect(
      [for (var w = 1; w <= 8; w++) imported.weekCode?[w - 1]],
      ['1', '0', '1', '0', '0', '0', '0', '1'],
    );
  });

  test(
    'odd parity starts at week 3 when bounds start at even week 2',
    () async {
      final course = _course(startWeek: 2, endWeek: 8, isOddWeek: true);
      final ics = await export(course, _semesterStart);
      expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260318T080000'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=3'));
      final imported = (await importedCourses(ics, _semesterStart)).single;
      expect(imported.startWeek, 3);
      expect(imported.endWeek, 7);
      expect(imported.isOddWeek || imported.weekCode != null, isTrue);
    },
  );

  test('external weekly INTERVAL=2 COUNT=3 imports weeks 2, 4, 6', () async {
    final imported = (await importedCourses('''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Math
DTSTART;TZID=Asia/Shanghai:20260311T080000
DTEND;TZID=Asia/Shanghai:20260311T094000
RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=3
END:VEVENT
END:VCALENDAR''', _semesterStart)).single;
    expect(courseOccurrenceWeeks(imported), [2, 4, 6]);
    expect(imported.isEvenWeek, isTrue);
  });

  test(
    'continuous weeks use a COUNT-limited weekly rule and round-trip',
    () async {
      final original = _course(startWeek: 2, endWeek: 5);
      final ics = await export(original, _semesterStart);
      expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260311T080000'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=4'));
      final imported = (await importedCourses(ics, _semesterStart)).single;
      expect(courseOccurrenceWeeks(imported), courseOccurrenceWeeks(original));
      expect(imported.startNode, original.startNode);
      expect(imported.step, original.step);
    },
  );

  test(
    'RDATE and third-week intervals keep exact dates on round-trip',
    () async {
      for (final code in ['00101001', '1001001']) {
        final original = _course(weekCode: code);
        final ics = await export(original, _semesterStart);
        final imported = (await importedCourses(ics, _semesterStart)).single;
        expect(
          courseOccurrenceWeeks(imported),
          courseOccurrenceWeeks(original),
        );
        if (code == '1001001') {
          expect(ics, contains('RRULE:FREQ=WEEKLY;INTERVAL=3;COUNT=3'));
        } else {
          expect(ics, contains('RDATE;TZID=Asia/Shanghai:'));
        }
      }
    },
  );

  test('week one begins on Monday when semester start is midweek', () async {
    final startDate = DateTime(2026, 3, 4, 17);
    final original = _course(startWeek: 1, endWeek: 1);
    final mondayCourse = Course.fromMap({...original.toMap(), 'dayOfWeek': 1});
    final ics = await export(mondayCourse, startDate);
    expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260302T080000'));
    final imported = (await importedCourses(ics, startDate)).single;
    expect(imported.dayOfWeek, 1);
    expect(courseOccurrenceWeeks(imported), [1]);
  });

  test('weekly COUNT without INTERVAL defaults to every week', () async {
    final imported = (await importedCourses('''BEGIN:VEVENT
SUMMARY:Math
DTSTART:20260304T080000
DTEND:20260304T094000
RRULE:FREQ=WEEKLY;COUNT=3
END:VEVENT''', _semesterStart)).single;
    expect(courseOccurrenceWeeks(imported), [1, 2, 3]);
  });

  test(
    'unsupported external recurrence is reported, not made weekly',
    () async {
      for (final extra in [
        'RRULE:FREQ=DAILY;COUNT=3',
        'RRULE:FREQ=WEEKLY;UNTIL=20260331T080000',
        'RRULE:FREQ=WEEKLY;COUNT=3;BYDAY=MO,WE',
        'RRULE:FREQ=WEEKLY',
        'RRULE:FREQ=WEEKLY;COUNT=3\nEXDATE:20260311T080000',
      ]) {
        final db = _RecordingDatabase();
        final file = File('${temp.path}/unsupported.ics');
        await file.writeAsString('''BEGIN:VEVENT
SUMMARY:Math
DTSTART:20260304T080000
DTEND:20260304T094000
$extra
END:VEVENT''');
        final report = await CourseTransferManager(databaseHelper: db)
            .importCoursesIcs(
              path: file.path,
              scheduleId: 1,
              startDate: _semesterStart,
              courseColorPalette: AppCourseColorPalette.candyBox,
            );
        expect(report.added, 0, reason: extra);
        expect(report.failed, 1, reason: extra);
        expect(db.courses, isEmpty, reason: extra);
      }
    },
  );

  test(
    'date-only recurring events are rejected rather than made into classes',
    () async {
      final db = _RecordingDatabase();
      final file = File('${temp.path}/all-day.ics');
      await file.writeAsString('''BEGIN:VEVENT
SUMMARY:All day
DTSTART;VALUE=DATE:20260304
DTEND;VALUE=DATE:20260305
RRULE:FREQ=WEEKLY;COUNT=3
END:VEVENT''');
      final report = await CourseTransferManager(databaseHelper: db)
          .importCoursesIcs(
            path: file.path,
            scheduleId: 1,
            startDate: _semesterStart,
            courseColorPalette: AppCourseColorPalette.candyBox,
          );
      expect(report.failed, 1);
      expect(db.courses, isEmpty);
    },
  );

  test(
    'system calendar schedules sparse dates individually, without gaps',
    () async {
      final plugin = _RecordingCalendar();
      final service = CalendarService(deviceCalendarPlugin: plugin);
      final created = await service.importCourses([
        _course(
          startWeek: 2,
          endWeek: 5,
          weekCode: '10100001',
          isEvenWeek: true,
        ),
        _course(startWeek: 2, endWeek: 8, isOddWeek: true),
        _course(startWeek: 2, endWeek: 5),
        _course(startWeek: 1, endWeek: 8, isVirtual: true),
      ], _semesterStart);
      expect(created, 3); // Course count, not number of generated events.
      expect(plugin.events, hasLength(5));
      expect(
        plugin.events
            .take(3)
            .map(
              (event) => DateTime(
                event.start!.year,
                event.start!.month,
                event.start!.day,
              ),
            ),
        [DateTime(2026, 3, 4), DateTime(2026, 3, 18), DateTime(2026, 4, 22)],
      );
      for (final event in plugin.events.take(3)) {
        expect(event.recurrenceRule, isNull);
      }
      expect(plugin.events[3].start!.day, 18);
      expect(plugin.events[3].recurrenceRule!.interval, 2);
      expect(plugin.events[3].recurrenceRule!.totalOccurrences, 3);
      expect(plugin.events.last.start!.day, 11);
      expect(plugin.events.last.recurrenceRule!.interval, 1);
      expect(plugin.events.last.recurrenceRule!.totalOccurrences, 4);
    },
  );
}
