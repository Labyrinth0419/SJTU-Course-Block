import 'dart:async';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/services/course_service.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/services/login_session.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/ui/course/add_course_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course _course({String teacher = 'Original', String color = '#FF5722'}) =>
    Course(
      courseId: 'R',
      courseName: 'Algebra',
      teacher: teacher,
      classRoom: 'A101',
      startWeek: 1,
      endWeek: 16,
      dayOfWeek: 1,
      startNode: 1,
      step: 2,
      weekCode: '1111',
      color: color,
    );

final _schedule = Schedule(
  id: 1,
  name: '2025-1 学期',
  year: '2025',
  term: '1',
  startDate: DateTime(2025, 9, 1),
  isCurrent: true,
);

// Round-trip each row through the same map representation as the real helper.
class _Rows extends DatabaseHelper {
  _Rows() : super.forTesting();

  final rows = <int, Map<String, dynamic>>{};
  int nextId = 1;
  int nextScheduleId = 1;
  Schedule? currentSchedule;
  Completer<void>? firstReadStarted;
  Completer<void>? releaseFirstRead;
  Completer<void>? secondReadStarted;
  int reads = 0;

  @override
  Future<Schedule?> getCurrentSchedule() async => currentSchedule;

  @override
  Future<int> insertSchedule(Schedule schedule) =>
      withCourseWriteLock(() async {
        final id = nextScheduleId++;
        currentSchedule = schedule.copyWith(id: id);
        return id;
      });

  @override
  Future<List<Course>> getCoursesBySchedule(int scheduleId) async {
    final snapshot = rows.values
        .where((row) => row['scheduleId'] == scheduleId)
        .map(Course.fromMap)
        .toList();
    reads++;
    if (reads == 1 && releaseFirstRead != null) {
      firstReadStarted!.complete();
      await releaseFirstRead!.future;
    } else if (reads == 2 && secondReadStarted != null) {
      secondReadStarted!.complete();
    }
    return snapshot;
  }

  @override
  Future<int> insertCourse(Course course) => withCourseWriteLock(() async {
    final id = course.id ?? nextId++;
    rows[id] = {...course.toMap(), 'id': id};
    return id;
  });

  @override
  Future<int> updateCourse(Course course) => withCourseWriteLock(() async {
    if (!rows.containsKey(course.id)) return 0;
    rows[course.id!] = course.toMap();
    return 1;
  });

  @override
  Future<int> deleteCourse(int id) =>
      withCourseWriteLock(() async => rows.remove(id) == null ? 0 : 1);

  @override
  Future<int> deleteSchedule(int id) => withCourseWriteLock(() async {
    rows.removeWhere((_, row) => row['scheduleId'] == id);
    if (currentSchedule?.id == id) currentSchedule = null;
    return 1;
  });

  @override
  Future<Course?> getCourseById(int id) async =>
      rows[id] == null ? null : Course.fromMap(rows[id]!);

  @override
  Future<int> updateCourseColor(int id, String color) =>
      withCourseWriteLock(() async {
        final row = rows[id];
        if (row == null) return 0;
        rows[id] = {...row, 'color': color};
        return 1;
      });

  List<Course> get persisted => rows.values.map(Course.fromMap).toList();
}

class _EditorProvider extends CourseProvider {
  _EditorProvider(this.active, this.visible);
  final Schedule active;
  final List<Course> visible;
  @override
  Schedule? get currentSchedule => active;
  @override
  List<Course> get courses => visible;
}

class _Fetch extends CourseService {
  _Fetch([this.onFetch]);
  final Future<CourseFetchResult> Function()? onFetch;
  List<Course> incoming = [_course()];

  CourseFetchResult result([List<Course>? courses]) => CourseFetchResult(
    sourceSystem: AcademicLoginSystem.undergraduate,
    courses: courses ?? incoming,
  );

  @override
  Future<CourseFetchResult> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async => onFetch == null ? result() : onFetch!();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Rows db;
  late _Fetch service;

  Future<CourseSyncExecutionResult> runSync([
    CourseSyncManager? manager,
    bool noSchedule = false,
  ]) =>
      (manager ?? CourseSyncManager(databaseHelper: db, courseService: service))
          .syncCourses(
            year: '2025',
            term: '1',
            currentSchedule: noSchedule ? null : _schedule,
            schedules: noSchedule ? [] : [_schedule],
            courses: [],
            courseColorPalette: AppCourseColorPalette.candyBox,
            defaultScheduleName: '默认课表',
          );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ug_cookies': 'test-session',
      'active_login_system': 'ug',
    });
    db = _Rows();
    service = _Fetch();
  });

  test('independent sync managers read fresh rows and add only once', () async {
    db.firstReadStarted = Completer<void>();
    db.releaseFirstRead = Completer<void>();
    db.secondReadStarted = Completer<void>();
    final first = runSync();
    await db.firstReadStarted!.future;
    final second = runSync();
    // With the buggy concurrent reads this completes as soon as both have
    // captured the same empty snapshot. With serialization the second waits.
    await Future.any([
      db.secondReadStarted!.future,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
    db.releaseFirstRead!.complete();
    final results = await Future.wait([first, second]);
    expect(results.map((r) => r.report.added).toList(), [1, 0]);
    expect(db.persisted.map((row) => Course.fromMap(row.toMap()).courseId), [
      'R',
    ]);
  });

  test('two first syncs create one schedule and one course', () async {
    final first = runSync(null, true);
    final second = runSync(null, true);
    final reports = await Future.wait([first, second]);
    expect(reports.map((result) => result.report.added), [1, 0]);
    expect(db.nextScheduleId, 2);
    expect(db.persisted.single.scheduleId, 1);
    expect(reports.last.currentSchedule?.id, 1);
    expect(reports.last.schedules.single.id, 1);
  });

  test('editor delta uses fresh persisted baseline', () async {
    await db.insertCourse(_course().copyWith(scheduleId: 1).bindRemote('ug'));
    final opened = db.persisted.single;
    await db.updateCourse(
      opened.mergeRemote(
        _course(
          teacher: 'Updated',
          color: '#ABCDEF',
        ).copyWith(startNode: 5, weekCode: '0101', isOddWeek: true),
      ),
    );
    final count = await db.updateCourseFromEditor(
      original: opened,
      submitted: opened.copyWith(classRoom: 'My room'),
    );
    expect(count, 1);
    final saved = Course.fromMap(db.persisted.single.toMap());
    expect(saved.teacher, 'Updated');
    expect(saved.classRoom, 'My room');
    expect(saved.startNode, 5);
    expect(saved.weekCode, '0101');
    expect(saved.isOddWeek, true);
    expect(saved.color, '#ABCDEF');
    expect(saved.remoteBaseline, contains('Updated'));
    expect(saved.editedFields, {'classRoom'});
  });

  test('intentional week change clears only the current week code', () async {
    await db.insertCourse(_course().copyWith(scheduleId: 1).bindRemote('ug'));
    final opened = db.persisted.single;
    await db.updateCourse(
      opened.mergeRemote(
        _course(teacher: 'Updated').copyWith(weekCode: '0101'),
      ),
    );
    expect(
      await db.updateCourseFromEditor(
        original: opened,
        submitted: opened.copyWith(startWeek: 2),
      ),
      1,
    );
    final saved = Course.fromMap(db.persisted.single.toMap());
    expect(saved.startWeek, 2);
    expect(saved.weekCode, isNull);
    expect(saved.teacher, 'Updated');
    expect(saved.remoteBaseline, contains('0101'));
  });

  test(
    'direct import and schedule deletion queue behind a pending sync',
    () async {
      final started = Completer<void>();
      final release = Completer<CourseFetchResult>();
      late _Fetch controlled;
      controlled = _Fetch(() {
        started.complete();
        return release.future;
      });
      service = controlled;
      final syncing = runSync();
      await started.future;
      final imported = db.insertCourse(
        _course().copyWith(scheduleId: 1, courseId: 'imported'),
      );
      expect(db.persisted, isEmpty);
      release.complete(controlled.result());
      await syncing;
      await imported;
      expect(db.persisted.map((row) => row.sourceSystem).toSet(), {
        'ug',
        'local',
      });
      final secondStarted = Completer<void>();
      final secondRelease = Completer<CourseFetchResult>();
      service = _Fetch(() {
        secondStarted.complete();
        return secondRelease.future;
      });
      final nextSync = runSync();
      await secondStarted.future;
      final deletion = db.deleteSchedule(1);
      expect(db.persisted.length, 2);
      secondRelease.complete(service.result());
      await nextSync;
      await deletion;
      expect(db.persisted, isEmpty);
    },
  );

  test(
    'queued failure reaches caller without poisoning the next write',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final failing = db.withCourseWriteLock(() async {
        started.complete();
        await release.future;
        throw StateError('write failed');
      });
      await started.future;
      final next = db.insertCourse(_course().copyWith(scheduleId: 1));
      release.complete();
      await expectLater(failing, throwsA(isA<StateError>()));
      expect(await next, 1);
      expect(db.persisted.single.courseName, 'Algebra');
    },
  );

  test(
    'stale color normalization preserves editor edits and sync baseline',
    () async {
      final autoColor = AppCourseColorPalette.candyBox.autoColorToken(
        buildCourseColorSeed('Algebra', 'Original'),
      );
      service.incoming = [_course(color: autoColor)];
      await runSync();
      final stale = db.persisted.single;
      await db.updateCourseFromEditor(
        original: stale,
        submitted: stale.copyWith(classRoom: 'Mine'),
      );
      service.incoming = [_course(teacher: 'Remote', color: autoColor)];
      await runSync();
      final normalizer = CourseScheduleManager(databaseHelper: db);
      final normalized = await normalizer.normalizeCourseColors(
        courses: [stale],
        courseColorPalette: AppCourseColorPalette.candyBox,
      );
      expect(normalized.single.teacher, 'Remote');
      expect(normalized.single.classRoom, 'Mine');
      expect(normalized.single.color, isNot(autoColor));
      service.incoming = [_course(teacher: 'Remote', color: '#123456')];
      await runSync();
      final after = await normalizer.normalizeCourseColors(
        courses: [stale],
        courseColorPalette: AppCourseColorPalette.candyBox,
      );
      final persisted = Course.fromMap(db.persisted.single.toMap());
      expect(after.single.toMap(), persisted.toMap());
      expect(persisted.teacher, 'Remote');
      expect(persisted.classRoom, 'Mine');
      expect(persisted.remoteBaseline, contains('Remote'));
      expect(persisted.editedFields, {'classRoom'});
      expect(persisted.color, '#123456');
    },
  );

  test(
    'delete queued before stale editor save wins without deadlock',
    () async {
      await runSync();
      final opened = db.persisted.single;
      final started = Completer<void>();
      final release = Completer<void>();
      final held = db.withCourseWriteLock(() async {
        started.complete();
        await release.future;
      });
      await started.future;
      final deleting = db.deleteCourse(opened.id!);
      final editing = db.updateCourseFromEditor(
        original: opened,
        submitted: opened.copyWith(teacher: 'Mine'),
      );
      release.complete();
      await held;
      expect(await deleting, 1);
      expect(await editing, 0);
      expect(db.persisted, isEmpty);
    },
  );

  testWidgets('editor opened before sync writes only intentional form deltas', (
    tester,
  ) async {
    await runSync();
    final opened = db.persisted.single;
    final provider = _EditorProvider(_schedule, [opened]);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: AddCourseScreen(course: opened, databaseHelper: db),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '可不填').last,
      'My room',
    );
    final started = Completer<void>();
    final release = Completer<CourseFetchResult>();
    late _Fetch controlled;
    controlled = _Fetch(() {
      started.complete();
      return release.future;
    });
    service = controlled;
    final syncing = runSync();
    await started.future;
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    release.complete(controlled.result([_course(teacher: 'Remote')]));
    await syncing;
    await tester.pumpAndSettle();
    final saved = Course.fromMap(db.persisted.single.toMap());
    expect(saved.teacher, 'Remote');
    expect(saved.classRoom, 'My room');
    expect(saved.weekCode, '1111');
    expect(saved.remoteBaseline, contains('Remote'));
    expect(saved.editedFields, {'classRoom'});
  });

  test('older delayed fetch cannot overwrite a newer request', () async {
    await db.insertCourse(_course().copyWith(scheduleId: 1).bindRemote('ug'));
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final releaseFirst = Completer<CourseFetchResult>();
    var fetches = 0;
    late _Fetch controlled;
    controlled = _Fetch(() {
      fetches++;
      if (fetches == 1) {
        firstStarted.complete();
        return releaseFirst.future;
      }
      secondStarted.complete();
      return Future.value(controlled.result([_course(teacher: 'Newer')]));
    });
    service = controlled;
    final first = runSync();
    await firstStarted.future;
    final second = runSync();
    await Future.any([
      secondStarted.future,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
    releaseFirst.complete(service.result([_course(teacher: 'Older')]));
    await Future.wait([first, second]);
    expect(fetches, 2);
    expect(db.persisted.single.teacher, 'Newer');
    expect(
      Course.fromMap(db.persisted.single.toMap()).remoteBaseline,
      contains('Newer'),
    );
  });
}
