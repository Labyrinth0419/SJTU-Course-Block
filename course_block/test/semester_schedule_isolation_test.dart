import 'dart:async';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/services/course_service.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/services/course_transfer_manager.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/services/login_session.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/settings/more_functions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Schedule _schedule(
  int id,
  String term,
  DateTime date, {
  bool current = false,
}) => Schedule(
  id: id,
  name: 'Term $term ($id)',
  year: '2025',
  term: term,
  startDate: date,
  isCurrent: current,
);

Course _course(String name, {String courseId = 'R'}) => Course(
  courseId: courseId,
  courseName: name,
  teacher: 'Teacher',
  classRoom: 'A101',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startNode: 1,
  step: 2,
  color: '#123456',
);

// Round-trip all fake rows through the same persisted representation as SQLite.
class _Rows extends DatabaseHelper {
  _Rows() : super.forTesting();

  final Map<int, Map<String, dynamic>> schedules = {};
  final Map<int, Map<String, dynamic>> courses = {};
  int nextScheduleId = 1;
  int nextCourseId = 1;

  Future<void> seedSchedule(Schedule schedule) async {
    schedules[schedule.id!] = schedule.toMap();
    if (schedule.id! >= nextScheduleId) nextScheduleId = schedule.id! + 1;
  }

  @override
  Future<List<Schedule>> getAllSchedules() async =>
      schedules.values.map(Schedule.fromMap).toList();

  @override
  Future<Schedule?> getCurrentSchedule() async {
    final current = schedules.values.where((row) => row['isCurrent'] == 1);
    return current.isEmpty ? null : Schedule.fromMap(current.single);
  }

  @override
  Future<int> insertSchedule(Schedule schedule) =>
      withCourseWriteLock(() async {
        if (schedule.isCurrent) {
          for (final row in schedules.values) {
            row['isCurrent'] = 0;
          }
        }
        final id = nextScheduleId++;
        schedules[id] = {...schedule.toMap(), 'id': id};
        return id;
      });

  @override
  Future<int> updateSchedule(Schedule schedule) =>
      withCourseWriteLock(() async {
        if (!schedules.containsKey(schedule.id)) return 0;
        if (schedule.isCurrent) {
          for (final row in schedules.values) {
            row['isCurrent'] = 0;
          }
        }
        schedules[schedule.id!] = schedule.toMap();
        return 1;
      });

  @override
  Future<void> setCurrentSchedule(int id) => withCourseWriteLock(() async {
    for (final row in schedules.values) {
      row['isCurrent'] = row['id'] == id ? 1 : 0;
    }
  });

  @override
  Future<List<Course>> getCoursesBySchedule(int scheduleId) async => courses
      .values
      .where((row) => row['scheduleId'] == scheduleId)
      .map(Course.fromMap)
      .toList();

  @override
  Future<int> insertCourse(Course course) => withCourseWriteLock(() async {
    final id = course.id ?? nextCourseId++;
    courses[id] = {...course.toMap(), 'id': id};
    return id;
  });

  @override
  Future<int> updateCourse(Course course) => withCourseWriteLock(() async {
    if (!courses.containsKey(course.id)) return 0;
    courses[course.id!] = course.toMap();
    return 1;
  });

  @override
  Future<int> deleteCourse(int id) =>
      withCourseWriteLock(() async => courses.remove(id) == null ? 0 : 1);

  @override
  Future<int> updateCourseColor(int id, String color) =>
      withCourseWriteLock(() async {
        if (!courses.containsKey(id)) return 0;
        courses[id]!['color'] = color;
        return 1;
      });
}

class _Fetch extends CourseService {
  final Map<String, List<Course>> incoming = {};
  Completer<void>? started;
  Completer<void>? release;

  Future<CourseFetchResult> _fetch(
    String year,
    String term,
    AcademicLoginSystem system,
  ) async {
    if (started != null && !started!.isCompleted) started!.complete();
    if (release != null) await release!.future;
    return CourseFetchResult(
      sourceSystem: system,
      courses: incoming['$year-$term-${system.storageKey}'] ?? [],
    );
  }

  @override
  Future<CourseFetchResult> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) => _fetch(year, term, AcademicLoginSystem.undergraduate);

  @override
  Future<CourseFetchResult> fetchGraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) => _fetch(year, term, AcademicLoginSystem.graduate);
}

class _CalendarCapture extends CourseTransferManager {
  int? selectedId;
  DateTime? selectedDate;
  List<Course> imported = [];

  @override
  Future<int> importToSystemCalendar(
    List<Course> courses,
    DateTime? startDate, {
    int? scheduleId,
  }) async {
    selectedId = scheduleId;
    selectedDate = startDate;
    imported = courses;
    return courses.length;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Rows db;
  late _Fetch fetch;
  late CourseSyncManager manager;
  final fall = DateTime(2025, 9, 1);
  final spring = DateTime(2026, 2, 23);

  Future<CourseSyncExecutionResult> sync(
    String term, {
    Schedule? selected,
    CourseSyncManager? using,
    DateTime? startDate,
  }) async => (using ?? manager).syncCourses(
    year: '2025',
    term: term,
    currentSchedule: selected ?? await db.getCurrentSchedule(),
    schedules: await db.getAllSchedules(),
    courses: selected?.id == null
        ? []
        : await db.getCoursesBySchedule(selected!.id!),
    courseColorPalette: AppCourseColorPalette.candyBox,
    defaultScheduleName: CourseProvider.defaultScheduleName,
    startDate: startDate,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ug_cookies': 'session',
      'active_login_system': 'ug',
    });
    db = _Rows();
    fetch = _Fetch();
    manager = CourseSyncManager(databaseHelper: db, courseService: fetch);
  });

  test(
    'other semester isolates source rows, manual rows, ids and dates',
    () async {
      final old = _schedule(1, '1', fall, current: true);
      await db.seedSchedule(old);
      fetch.incoming['2025-1-ug'] = [_course('Fall')];
      final first = await sync('1');
      final remote = first.courses.single;
      await db.updateCourse(
        remote.withUserEdits(remote.copyWith(courseName: 'Mine')),
      );
      final manualId = await db.insertCourse(
        _course('Manual').copyWith(scheduleId: 1),
      );
      fetch.incoming['2025-2-ug'] = [_course('Spring')];
      final result = await sync('2', startDate: spring);
      expect(result.currentSchedule!.id, isNot(1));
      expect(result.currentSchedule!.startDate, spring);
      expect(
        Schedule.fromMap(db.schedules[1]!).toMap(),
        old.copyWith(isCurrent: false).toMap(),
      );
      final oldCourses = await db.getCoursesBySchedule(1);
      expect(
        oldCourses.map((course) => course.id),
        containsAll([remote.id, manualId]),
      );
      expect(
        oldCourses.firstWhere((course) => course.id == remote.id).editedFields,
        contains('courseName'),
      );
      final springCourse = result.courses.single;
      expect(springCourse.courseName, 'Spring');
      expect(springCourse.editedFields, isEmpty);
      expect(springCourse.id, isNot(remote.id));
      expect(springCourse.scheduleId, result.currentSchedule!.id);
    },
  );

  test(
    'existing target reuses persisted id/date and ignores stale caller caches',
    () async {
      final fallSchedule = _schedule(1, '1', fall, current: true);
      final springSchedule = _schedule(2, '2', spring);
      await db.seedSchedule(fallSchedule);
      await db.seedSchedule(springSchedule);
      final old = await db.insertCourse(
        _course('Old').bindRemote('ug').copyWith(scheduleId: 1),
      );
      fetch.incoming['2025-2-ug'] = [_course('New')];
      final first = await sync('2', selected: fallSchedule, startDate: fall);
      expect(first.currentSchedule!.id, 2);
      expect(first.currentSchedule!.isCurrent, true);
      expect(first.schedules.singleWhere((s) => s.id == 2).isCurrent, true);
      expect(first.currentSchedule!.startDate, spring);
      expect(first.courses.single.courseName, 'New');
      final newId = first.courses.single.id;
      final second = await sync('2', selected: fallSchedule);
      expect((second.report.added, second.report.updated), (0, 0));
      expect(second.courses.single.id, newId);
      expect((await db.getCoursesBySchedule(1)).single.id, old);
      expect(
        (await db.getAllSchedules()).singleWhere((s) => s.id == 2).startDate,
        spring,
      );
    },
  );

  test(
    'graduate source in another term cannot claim undergraduate rows',
    () async {
      await db.seedSchedule(_schedule(1, '1', fall, current: true));
      fetch.incoming['2025-1-ug'] = [_course('UG')];
      final ug = (await sync('1')).courses.single;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('grad_cookies', 'session');
      await prefs.setString('active_login_system', 'grad');
      fetch.incoming['2025-2-grad'] = [_course('Graduate')];
      final graduate = await sync('2', startDate: spring);
      expect(graduate.courses.single.sourceSystem, 'grad');
      expect(graduate.courses.single.remoteCourseKey, ug.remoteCourseKey);
      expect(graduate.courses.single.id, isNot(ug.id));
      expect((await db.getCoursesBySchedule(1)).single.sourceSystem, 'ug');
    },
  );

  test('first creation rejects missing date and uses explicit date', () async {
    fetch.incoming['2025-2-ug'] = [_course('New')];
    await expectLater(
      sync('2'),
      throwsA(isA<SemesterStartDateRequiredException>()),
    );
    expect(db.schedules, isEmpty);
    final result = await sync('2', startDate: spring);
    expect(result.createdSchedule, true);
    expect(result.currentSchedule!.startDate, spring);
    expect(result.courses.single.scheduleId, result.currentSchedule!.id);
  });

  test(
    'empty default placeholder needs explicit date; nonempty is never relabeled',
    () async {
      final placeholder = Schedule(
        id: 1,
        name: CourseProvider.defaultScheduleName,
        year: '2026',
        term: '1',
        startDate: DateTime(2026, 3, 9),
        isCurrent: true,
      );
      await db.seedSchedule(placeholder);
      fetch.incoming['2025-2-ug'] = [_course('New')];
      await expectLater(
        sync('2'),
        throwsA(isA<SemesterStartDateRequiredException>()),
      );
      expect(db.schedules[1], placeholder.toMap());
      final bound = await sync('2', startDate: spring);
      expect(bound.currentSchedule!.id, 1);
      expect(bound.currentSchedule!.startDate, spring);
      expect(bound.currentSchedule!.name, '2025-2 学期');

      db = _Rows();
      manager = CourseSyncManager(databaseHelper: db, courseService: fetch);
      await db.seedSchedule(placeholder);
      final manualId = await db.insertCourse(
        _course('Manual').copyWith(scheduleId: 1),
      );
      final separate = await sync('2', startDate: spring);
      expect(separate.currentSchedule!.id, isNot(1));
      expect(db.schedules[1], placeholder.copyWith(isCurrent: false).toMap());
      expect((await db.getCoursesBySchedule(1)).single.id, manualId);
    },
  );

  test(
    'matching empty placeholder requires date, not its generated date',
    () async {
      final placeholder = Schedule(
        id: 1,
        name: CourseProvider.defaultScheduleName,
        year: '2025',
        term: '1',
        startDate: DateTime(2026, 3, 9),
        isCurrent: true,
      );
      await db.seedSchedule(placeholder);
      fetch.incoming['2025-1-ug'] = [_course('New')];
      await expectLater(
        sync('1'),
        throwsA(isA<SemesterStartDateRequiredException>()),
      );
      expect(db.schedules[1], placeholder.toMap());
      final result = await sync('1', startDate: fall);
      expect(result.currentSchedule!.id, 1);
      expect(result.currentSchedule!.startDate, fall);
    },
  );

  test(
    'ambiguous target refuses arbitrary pick unless selected/current matches',
    () async {
      final old = _schedule(1, '1', fall, current: true);
      final first = _schedule(2, '2', spring);
      final second = _schedule(3, '2', DateTime(2026, 3, 2));
      for (final schedule in [old, first, second]) {
        await db.seedSchedule(schedule);
      }
      fetch.incoming['2025-2-ug'] = [_course('New')];
      await expectLater(
        sync('2', selected: old),
        throwsA(isA<AmbiguousSemesterSyncException>()),
      );
      expect(await db.getCurrentSchedule(), isNotNull);
      expect((await db.getCurrentSchedule())!.id, 1);
      expect(db.courses, isEmpty);
      final chosen = await sync('2', selected: second);
      expect(chosen.currentSchedule!.id, 3);
      expect(chosen.currentSchedule!.startDate, second.startDate);
      expect((await db.getCoursesBySchedule(2)), isEmpty);
      final reused = await sync('2', selected: first);
      expect(reused.currentSchedule!.id, 3);
      expect(reused.report.added, 0);
    },
  );

  test(
    'two independent managers create only one target behind a pending fetch',
    () async {
      await db.seedSchedule(_schedule(1, '1', fall, current: true));
      fetch.incoming['2025-2-ug'] = [_course('New')];
      fetch.started = Completer<void>();
      fetch.release = Completer<void>();
      final first = sync('2', startDate: spring);
      await fetch.started!.future;
      final second = sync(
        '2',
        startDate: spring,
        using: CourseSyncManager(databaseHelper: db, courseService: fetch),
      );
      fetch.release!.complete();
      final results = await Future.wait([first, second]);
      expect(results.map((r) => r.report.added), [1, 0]);
      expect(db.schedules.length, 2);
      expect(
        results.last.currentSchedule!.id,
        results.first.currentSchedule!.id,
      );
      expect(db.courses.length, 1);
    },
  );

  test(
    'provider applies target settings, week and calendar scope together',
    () async {
      await db.seedSchedule(_schedule(1, '1', fall, current: true));
      fetch.incoming['2025-2-ug'] = [_course('New')];
      final calendar = _CalendarCapture();
      final provider = CourseProvider(
        courseScheduleManager: CourseScheduleManager(databaseHelper: db),
        courseSyncManager: manager,
        courseTransferManager: calendar,
        now: () => DateTime(2026, 3, 9),
      );
      addTearDown(provider.dispose);
      await provider.loadCourses();
      await provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showGridLinesKey,
        false,
      );
      final report = await provider.syncCourses('2025', '2', startDate: spring);
      expect(report.added, 1);
      final newId = provider.currentSchedule!.id!;
      expect(newId, isNot(1));
      expect(
        provider.showGridLines,
        false,
      ); // New schedule inherits source settings.
      expect(provider.currentWeek, 3);
      expect(provider.courses.single.scheduleId, newId);
      expect(await provider.importToSystemCalendar(), 1);
      expect(calendar.selectedId, newId);
      expect(calendar.selectedDate, spring);
      expect(calendar.imported.single.id, provider.courses.single.id);
      await provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showGridLinesKey,
        true,
      );
      await provider.switchSchedule(1);
      expect(provider.showGridLines, false);
      await provider.switchSchedule(newId);
      expect(provider.showGridLines, true);
      expect(
        (await db.getAllSchedules()).singleWhere((s) => s.id == 1).startDate,
        fall,
      );
    },
  );

  test(
    'provider reuses target-specific settings without copying old settings',
    () async {
      await db.seedSchedule(_schedule(1, '1', fall, current: true));
      await db.seedSchedule(_schedule(2, '2', spring));
      final prefs = await SharedPreferences.getInstance();
      const setting = CourseSettingsStore.showSundayKey;
      final settings = CourseSettingsStore();
      await prefs.setBool(settings.schedulePrefKey(1, setting), false);
      await prefs.setBool(settings.schedulePrefKey(2, setting), true);
      fetch.incoming['2025-2-ug'] = [_course('New')];
      final provider = CourseProvider(
        courseScheduleManager: CourseScheduleManager(databaseHelper: db),
        courseSyncManager: manager,
      );
      addTearDown(provider.dispose);
      await provider.loadCourses();
      expect(provider.showSunday, false);
      await provider.syncCourses('2025', '2', startDate: fall);
      expect(provider.currentSchedule!.id, 2);
      expect(provider.currentSchedule!.startDate, spring);
      expect(provider.currentSchedule!.isCurrent, true);
      expect(provider.showSunday, true);
      expect(prefs.getBool(settings.schedulePrefKey(1, setting)), false);
      expect(prefs.getBool(settings.schedulePrefKey(2, setting)), true);
    },
  );

  test(
    'provider recalculates week when a placeholder binds at the same id',
    () async {
      await db.seedSchedule(
        Schedule(
          id: 1,
          name: CourseProvider.defaultScheduleName,
          year: '2025',
          term: '1',
          startDate: DateTime(2026, 3, 9),
          isCurrent: true,
        ),
      );
      fetch.incoming['2025-2-ug'] = [_course('New')];
      final provider = CourseProvider(
        courseScheduleManager: CourseScheduleManager(databaseHelper: db),
        courseSyncManager: manager,
        now: () => DateTime(2026, 3, 16),
      );
      addTearDown(provider.dispose);
      await provider.loadCourses();
      expect(provider.currentWeek, 2);
      await provider.syncCourses('2025', '2', startDate: spring);
      expect(provider.currentSchedule!.id, 1);
      expect(provider.currentWeek, 4);
    },
  );

  testWidgets('semester dialog requires a picked first-week date before sync', (
    tester,
  ) async {
    await db.seedSchedule(
      Schedule(
        id: 1,
        name: CourseProvider.defaultScheduleName,
        year: '2025',
        term: '1',
        startDate: DateTime(2026, 3, 9),
        isCurrent: true,
      ),
    );
    fetch.incoming['2025-1-ug'] = [_course('New')];
    final provider = CourseProvider(
      courseScheduleManager: CourseScheduleManager(databaseHelper: db),
      courseSyncManager: manager,
    );
    addTearDown(provider.dispose);
    await provider.loadCourses();
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => handleImportMenuAction(
                  context,
                  ImportMenuAction.syncOtherTerm,
                ),
                child: const Text('打开同步'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开同步'));
    await tester.pumpAndSettle();
    final syncButton = find.widgetWithText(FilledButton, '同步');
    expect(find.text('开学第一周日期（必选）'), findsOneWidget);
    expect(tester.widget<FilledButton>(syncButton).onPressed, isNull);
    await tester.tap(find.text('开学第一周日期（必选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(syncButton).onPressed, isNotNull);
    await tester.tap(syncButton);
    await tester.pumpAndSettle();
    expect(provider.currentSchedule!.name, '2025-1 学期');
    expect(provider.courses.single.courseName, 'New');
  });
}
