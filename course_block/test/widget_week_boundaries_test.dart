import 'dart:convert';

import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/services/widget_sync_service.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course(String name, int weekday, int firstWeek, int lastWeek) => Course(
  courseId: name,
  courseName: name,
  teacher: '',
  classRoom: '',
  startWeek: firstWeek,
  endWeek: lastWeek,
  dayOfWeek: weekday,
  startNode: 1,
  step: 2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> saved;

  setUp(() {
    saved = {};
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveWidgetData') {
        final args = call.arguments as Map;
        saved[args['id'] as String] = args['data'].toString();
      }
      return true;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final schedule = Schedule(
    name: 'Term',
    year: '2026',
    term: '1',
    startDate: DateTime(2026, 3, 4, 17), // Wednesday; week one starts Monday.
  );
  final courses = [
    _course('Monday week one', 1, 1, 1),
    _course('Tuesday week one', 2, 1, 1),
    _course('Sunday week one', 7, 1, 1),
    _course('Monday week two', 1, 2, 2),
    _course('Sunday week two', 7, 2, 2),
    _course('Monday all weeks', 1, 1, 20),
    _course('Monday week three', 1, 3, 3),
  ];

  Future<void> refresh(DateTime now, {Schedule? term}) =>
      WidgetSyncService.instance.updateTodayWidget(
        courses,
        term ?? schedule,
        totalWeeks: 2,
        themeScheme: AppThemeScheme.morningMist,
        themeMode: ThemeMode.system,
        courseColorPalette: AppCourseColorPalette.candyBox,
        now: now,
      );

  List<String> names(String key) => [
    for (final item in jsonDecode(saved[key]!) as List)
      if (item['name'] != null) item['name'] as String,
  ];

  test(
    'before first Monday: only future academic dates appear in upcoming',
    () async {
      await refresh(DateTime(2026, 3, 1, 7));
      expect(names('today_list'), isEmpty);
      expect(names('day_list'), isEmpty);
      expect(names('week_list'), isEmpty);
      expect(names('upcoming_list'), [
        'Monday week one',
        'Monday all weeks',
        'Tuesday week one',
      ]);
      expect(saved['today_header'], 'Term');
      final snapshot = jsonDecode(saved['widget_schedule_snapshot']!) as Map;
      expect(
        snapshot['schedule']['startEpochDay'],
        DateTime.utc(2026, 3, 4).difference(DateTime.utc(1970)).inDays,
      );
      expect(snapshot['schedule']['totalWeeks'], 2);
    },
  );

  test('Monday before configured Wednesday is academic week one', () async {
    await refresh(DateTime(2026, 3, 2, 7));
    expect(names('today_list'), ['Monday week one', 'Monday all weeks']);
    expect(names('day_list'), ['Monday week one', 'Monday all weeks']);
    expect(names('week_list'), [
      'Monday week one',
      'Monday all weeks',
      'Tuesday week one',
      'Sunday week one',
    ]);
  });

  test('next Monday is week two; upcoming crosses the last Sunday', () async {
    await refresh(DateTime(2026, 3, 9, 7));
    expect(names('today_list'), ['Monday week two', 'Monday all weeks']);
    await refresh(DateTime(2026, 3, 15, 7));
    expect(names('today_list'), ['Sunday week two']);
    expect(names('upcoming_list'), ['Sunday week two']);
    expect(names('week_list'), [
      'Monday week two',
      'Monday all weeks',
      'Sunday week two',
    ]);
  });

  test(
    'after total weeks: no payload includes even an open-ended course',
    () async {
      await refresh(DateTime(2026, 3, 16, 7));
      for (final key in [
        'today_list',
        'day_list',
        'upcoming_list',
        'week_list',
      ]) {
        expect(names(key), isEmpty, reason: key);
      }
      expect(saved['today_header'], 'Term');
    },
  );

  test(
    'snapshot serializes pre-epoch civil days as negative epoch days',
    () async {
      await refresh(
        DateTime(1969, 12, 29, 7),
        term: Schedule(
          name: 'Old',
          year: '1969',
          term: '1',
          startDate: DateTime(1969, 12, 31),
        ),
      );
      final snapshot = jsonDecode(saved['widget_schedule_snapshot']!) as Map;
      expect(snapshot['schedule']['startEpochDay'], -1);
    },
  );
}
