import 'dart:io';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/course_operation_report.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/services/course_service.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/services/login_session.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/course/add_course_screen.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course _course(
  String id, {
  int day = 1,
  int node = 1,
  String name = 'Algebra',
}) => Course(
  courseId: id,
  courseName: name,
  teacher: 'Professor',
  classRoom: 'A101',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: day,
  startNode: node,
  step: 2,
  weekCode: '1111',
  color: '#FF5722',
);

final _schedule = Schedule(
  id: 1,
  name: '2025-1 学期',
  year: '2025',
  term: '1',
  startDate: DateTime(2025, 9, 1),
  isCurrent: true,
);

// The same serialized representation that DatabaseHelper writes is read back on
// every query, rather than retaining Course object references in this fake.
class _Rows extends DatabaseHelper {
  _Rows() : super.forTesting();

  final Map<int, Map<String, dynamic>> rows = {};
  int nextId = 1;

  @override
  Future<int> insertCourse(Course course) async {
    final id = course.id ?? nextId++;
    rows[id] = {...course.toMap(), 'id': id};
    return id;
  }

  @override
  Future<int> updateCourse(Course course) async {
    if (!rows.containsKey(course.id)) throw StateError('Missing course id');
    rows[course.id!] = course.toMap();
    return 1;
  }

  @override
  Future<int> deleteCourse(int id) async => rows.remove(id) == null ? 0 : 1;

  @override
  Future<List<Course>> getCoursesBySchedule(int scheduleId) async => rows.values
      .where((row) => row['scheduleId'] == scheduleId)
      .map(Course.fromMap)
      .toList();
}

class _Fetch extends CourseService {
  AcademicLoginSystem system = AcademicLoginSystem.undergraduate;
  List<Course> incoming = [];
  List<CourseOperationFailure> failures = [];
  @override
  Future<CourseFetchResult> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async => CourseFetchResult(
    sourceSystem: system,
    courses: incoming,
    failures: failures,
  );

  @override
  Future<CourseFetchResult> fetchGraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async => CourseFetchResult(
    sourceSystem: system,
    courses: incoming,
    failures: failures,
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Rows db;
  late _Fetch service;
  late CourseSyncManager sync;

  Future<dynamic> runSync() => sync.syncCourses(
    year: '2025',
    term: '1',
    currentSchedule: _schedule,
    schedules: [_schedule],
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
    sync = CourseSyncManager(databaseHelper: db, courseService: service);
  });

  test(
    'manual and file-import rows survive refresh and remote removal',
    () async {
      final manualId = await db.insertCourse(
        _course('remote-id').copyWith(scheduleId: 1),
      );
      final fileId = await db.insertCourse(
        _course('').copyWith(scheduleId: 1, courseName: 'Imported'),
      );
      service.incoming = [_course('remote-id')];
      final first = await runSync();
      expect(first.report.added, 1);
      expect((await db.getCoursesBySchedule(1)).length, 3);
      service.incoming = [_course('new-id')];
      await runSync();
      final after = await db.getCoursesBySchedule(1);
      expect(after.map((course) => course.id), containsAll([manualId, fileId]));
      expect(
        after
            .where((course) => course.sourceSystem == 'ug')
            .map((course) => course.courseId),
        ['new-id'],
      );
    },
  );

  test(
    'untouched fields refresh, explicit overrides survive, ids stay stable',
    () async {
      service.incoming = [_course('R')];
      await runSync();
      final original = (await db.getCoursesBySchedule(1)).single;
      final edited = original.withUserEdits(
        original.copyWith(
          courseName: 'My name',
          teacher: 'My teacher',
          classRoom: 'My room',
          dayOfWeek: 4,
          startNode: 5,
          step: 3,
          startWeek: 2,
          endWeek: 12,
          weekCode: '1010',
          isOddWeek: true,
          isEvenWeek: true,
          color: '#ABCDEF',
          isVirtual: true,
        ),
      );
      await db.updateCourse(edited);
      service.incoming = [
        _course('R').copyWith(
          courseName: 'Remote name',
          teacher: 'Remote teacher',
          classRoom: 'Remote room',
          dayOfWeek: 6,
          startNode: 8,
          step: 4,
          startWeek: 3,
          endWeek: 14,
          weekCode: '0101',
          isOddWeek: true,
          color: '#000000',
          isVirtual: false,
        ),
      ];
      await runSync();
      final first = (await db.getCoursesBySchedule(1)).single;
      expect(first.id, original.id);
      expect(first.courseName, 'My name');
      expect(first.teacher, 'My teacher');
      expect(first.classRoom, 'My room');
      expect((first.dayOfWeek, first.startNode, first.step), (4, 5, 3));
      expect((first.startWeek, first.endWeek, first.weekCode), (2, 12, '1010'));
      expect(
        (first.isOddWeek, first.isEvenWeek, first.color, first.isVirtual),
        (true, true, '#ABCDEF', true),
      );
      expect(first.remoteBaseline, isNot(original.remoteBaseline));
      final second = await runSync();
      expect(second.report.added, 0);
      expect((await db.getCoursesBySchedule(1)).single.id, original.id);
      // A changed value restored to the current baseline relinquishes its override.
      final reverted = first.withUserEdits(
        first.copyWith(courseName: 'Remote name'),
      );
      expect(reverted.editedFields, isNot(contains('courseName')));
      await db.updateCourse(reverted);
      service.incoming = [_course('R').copyWith(courseName: 'New remote name')];
      await runSync();
      expect(
        (await db.getCoursesBySchedule(1)).single.courseName,
        'New remote name',
      );
    },
  );

  test(
    'one untouched remote field follows subsequent remote updates',
    () async {
      service.incoming = [_course('R')];
      await runSync();
      final remote = (await db.getCoursesBySchedule(1)).single;
      await db.updateCourse(
        remote.withUserEdits(remote.copyWith(classRoom: 'Mine')),
      );
      service.incoming = [
        _course('R').copyWith(teacher: 'New teacher', classRoom: 'New room'),
      ];
      await runSync();
      expect((await db.getCoursesBySchedule(1)).single.teacher, 'New teacher');
      expect((await db.getCoursesBySchedule(1)).single.classRoom, 'Mine');
    },
  );

  test(
    'legacy matching keeps original values and unmatched stays local',
    () async {
      // SQLite v1->v2 migration explicitly labels preexisting rows legacy.
      final legacy = {
        ..._course('R').copyWith(scheduleId: 1).toMap(),
        'id': 40,
        'sourceSystem': 'legacy',
      };
      final unmatched = {
        ..._course('old').copyWith(scheduleId: 1).toMap(),
        'id': 41,
        'sourceSystem': 'legacy',
      };
      db.rows[40] = legacy;
      db.rows[41] = unmatched;
      service.incoming = [
        _course('R').copyWith(
          classRoom: 'New room',
          startWeek: 3,
          endWeek: 12,
          color: '#000000',
          isVirtual: true,
        ),
      ];
      await runSync();
      final saved = await db.getCoursesBySchedule(1);
      final bound = saved.firstWhere((c) => c.id == 40);
      expect(bound.classRoom, 'A101');
      expect(
        (bound.startWeek, bound.endWeek, bound.color, bound.isVirtual),
        (1, 16, '#FF5722', false),
      );
      expect(bound.editedFields, Course.syncFieldNames);
      expect(saved.firstWhere((c) => c.id == 40).sourceSystem, 'ug');
      expect(saved.firstWhere((c) => c.id == 41).sourceSystem, 'local');
      await runSync();
      expect((await db.getCoursesBySchedule(1)).length, 2);
    },
  );

  test(
    'ambiguous legacy meeting group retains rows and reports conflict',
    () async {
      for (var id = 50; id <= 51; id++) {
        db.rows[id] = {
          ..._course('R').copyWith(scheduleId: 1).toMap(),
          'id': id,
          'sourceSystem': 'legacy',
        };
      }
      service.incoming = [_course('R')];
      final result = await runSync();
      expect(result.report.notes.join(' '), contains('R'));
      final after = await db.getCoursesBySchedule(1);
      expect(after.map((c) => c.id), containsAll([50, 51]));
      expect(after.every((c) => c.sourceSystem == 'legacy'), true);
      expect((await runSync()).report.added, 0);
    },
  );

  test('fromMap distinguishes portable imports from id-bearing v1 rows', () {
    final portable = {..._course('R').toMap()}
      ..remove('id')
      ..remove('scheduleId')
      ..remove('sourceSystem')
      ..remove('remoteCourseKey')
      ..remove('remoteBaseline')
      ..remove('editedFields');
    expect(Course.fromMap(portable).sourceSystem, 'local');
    expect(Course.fromMap({...portable, 'id': null}).sourceSystem, 'local');
    expect(Course.fromMap({...portable, 'id': 42}).sourceSystem, 'legacy');
    expect(
      Course.fromMap({
        ...portable,
        'id': 42,
        'sourceSystem': 'ug',
      }).sourceSystem,
      'ug',
    );
  });

  test('fetched row with an id cannot replace an existing local row', () async {
    final localId = await db.insertCourse(
      _course('manual').copyWith(scheduleId: 1),
    );
    service.incoming = [_course('remote').copyWith(id: localId)];
    await runSync();
    final saved = await db.getCoursesBySchedule(1);
    expect(saved.length, 2);
    expect(saved.firstWhere((c) => c.id == localId).courseId, 'manual');
    expect(saved.firstWhere((c) => c.courseId == 'remote').sourceSystem, 'ug');
  });

  test(
    'metadata-free portable JSON is local, even if its id resembles remote',
    () async {
      final portable = {..._course('R').toMap()}
        ..remove('id')
        ..remove('scheduleId')
        ..remove('sourceSystem')
        ..remove('remoteCourseKey')
        ..remove('remoteBaseline')
        ..remove('editedFields');
      final imported = Course.fromMap(portable).copyWith(scheduleId: 1);
      expect(imported.sourceSystem, 'local');
      final id = await db.insertCourse(imported);
      service.incoming = [_course('R')];
      await runSync();
      expect(
        (await db.getCoursesBySchedule(
          1,
        )).where((c) => c.id == id).single.sourceSystem,
        'local',
      );
      expect((await db.getCoursesBySchedule(1)).length, 2);
    },
  );

  test('ambiguous multi-meeting group is skipped, others still sync', () async {
    service.incoming = [
      _course('R', node: 1),
      _course('R', node: 5),
      _course('S'),
    ];
    await runSync();
    final original = await db.getCoursesBySchedule(1);
    service.incoming = [
      _course('R', day: 2, node: 3),
      _course('R', day: 3, node: 7),
      _course('S').copyWith(teacher: 'Updated'),
    ];
    final report = (await runSync()).report;
    final after = await db.getCoursesBySchedule(1);
    expect(
      after
          .where((c) => c.courseId == 'R')
          .map((c) => (c.id, c.dayOfWeek, c.startNode)),
      original
          .where((c) => c.courseId == 'R')
          .map((c) => (c.id, c.dayOfWeek, c.startNode)),
    );
    expect(after.singleWhere((c) => c.courseId == 'S').teacher, 'Updated');
    expect(report.notes.join(' '), contains('R'));
    await runSync();
    expect((await db.getCoursesBySchedule(1)).length, 3);
  });

  test(
    'partial identity does not apply any change in ambiguous meeting group',
    () async {
      service.incoming = [
        _course('R', node: 1),
        _course('R', node: 5),
        _course('R', node: 9),
      ];
      await runSync();
      final before = await db.getCoursesBySchedule(1);
      service.incoming = [
        _course('R', node: 1).copyWith(teacher: 'Should not update'),
        _course('R', day: 2, node: 3),
        _course('R', day: 3, node: 7),
      ];
      final report = (await runSync()).report;
      expect(report.notes.join(' '), contains('R'));
      expect(report.updated, 0);
      expect(report.added, 0);
      final after = await db.getCoursesBySchedule(1);
      expect(after.map((c) => c.id), before.map((c) => c.id));
      expect(after.every((c) => c.teacher == 'Professor'), true);
    },
  );

  test('multi-meeting matching uses baseline, not user-edited time', () async {
    service.incoming = [_course('R', node: 1), _course('R', node: 5)];
    await runSync();
    final rows = await db.getCoursesBySchedule(1);
    await db.updateCourse(
      rows.first.withUserEdits(rows.first.copyWith(startNode: 8)),
    );
    service.incoming = [
      _course('R', node: 1).copyWith(teacher: 'Changed'),
      _course('R', node: 5),
    ];
    await runSync();
    final after = await db.getCoursesBySchedule(1);
    expect(after.firstWhere((c) => c.id == rows.first.id).startNode, 8);
    expect(after.firstWhere((c) => c.id == rows.first.id).teacher, 'Changed');
  });

  test(
    'schedule auto-color normalization does not make each sync a new update',
    () async {
      final autoColor = AppCourseColorPalette.candyBox.autoColorToken(
        buildCourseColorSeed('Algebra', 'Professor'),
      );
      service.incoming = [_course('R').copyWith(color: autoColor)];
      final first = await runSync();
      final id = first.courses.single.id;
      await CourseScheduleManager(databaseHelper: db).normalizeCourseColors(
        courses: first.courses,
        courseColorPalette: AppCourseColorPalette.candyBox,
      );
      final normalized = (await db.getCoursesBySchedule(1)).single;
      expect(normalized.color, isNot(autoColor));
      final second = await runSync();
      expect(second.report.added, 0);
      expect(second.report.updated, 0);
      expect(second.courses.single.id, id);
      expect(second.courses.single.color, normalized.color);
      service.incoming = [_course('R').copyWith(color: '#123456')];
      final third = await runSync();
      expect(third.courses.single.color, '#123456');
      expect(third.courses.single.id, id);
    },
  );

  test('same-time meetings use distinct baseline week fingerprints', () async {
    service.incoming = [
      _course('R').copyWith(weekCode: '1010', startWeek: 1, endWeek: 4),
      _course('R').copyWith(weekCode: '0101', startWeek: 2, endWeek: 4),
    ];
    await runSync();
    final before = await db.getCoursesBySchedule(1);
    final one = before.firstWhere((c) => c.weekCode == '1010');
    service.incoming = [
      _course('R').copyWith(
        weekCode: '1010',
        startWeek: 1,
        endWeek: 4,
        teacher: 'Updated',
      ),
      _course('R').copyWith(weekCode: '0101', startWeek: 2, endWeek: 4),
    ];
    final report = (await runSync()).report;
    final after = await db.getCoursesBySchedule(1);
    expect(report.notes.join(' '), isNot(contains('无法唯一')));
    expect(after.firstWhere((c) => c.id == one.id).teacher, 'Updated');
    expect(after.map((c) => c.id), containsAll(before.map((c) => c.id)));
    expect((await runSync()).report.added, 0);
  });

  test('remote login systems isolate matching and removals', () async {
    SharedPreferences.setMockInitialValues({
      'ug_cookies': 'test-session',
      'grad_cookies': 'test-session',
      'active_login_system': 'ug',
    });
    service.incoming = [_course('R')];
    await runSync();
    final ug = (await db.getCoursesBySchedule(1)).single;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_login_system', 'grad');
    service.system = AcademicLoginSystem.graduate;
    service.incoming = [_course('R').copyWith(teacher: 'Graduate')];
    await runSync();
    final afterGrad = await db.getCoursesBySchedule(1);
    expect(afterGrad.length, 2);
    expect(afterGrad.firstWhere((c) => c.id == ug.id).teacher, 'Professor');
    expect(
      afterGrad.singleWhere((c) => c.sourceSystem == 'grad').remoteCourseKey,
      'R',
    );
    service.incoming = [_course('new').copyWith(teacher: 'Graduate')];
    await runSync();
    expect(
      (await db.getCoursesBySchedule(1)).map((c) => c.id),
      contains(ug.id),
    );
  });

  test('missing remote course ID cannot remove tracked courses', () async {
    service.incoming = [_course('R')];
    await runSync();
    final id = (await db.getCoursesBySchedule(1)).single.id;
    service.incoming = [_course(''), _course('S')];
    final report = (await runSync()).report;
    expect(report.notes.join(' '), contains('缺少'));
    expect((await db.getCoursesBySchedule(1)).map((c) => c.id), contains(id));
    expect((await runSync()).report.added, 0);
  });

  test('partial parse failure does not remove absent remote rows', () async {
    service.incoming = [_course('R'), _course('S')];
    await runSync();
    final rows = await db.getCoursesBySchedule(1);
    service.incoming = [_course('R').copyWith(teacher: 'New')];
    service.failures = [
      const CourseOperationFailure(label: 'S', reason: 'parse failure'),
    ];
    final result = await runSync();
    expect(result.report.failed, 1);
    expect(result.report.notes.join(' '), contains('未删除'));
    expect(
      (await db.getCoursesBySchedule(1)).map((c) => c.id),
      containsAll(rows.map((c) => c.id)),
    );
    expect(
      (await db.getCoursesBySchedule(
        1,
      )).firstWhere((c) => c.courseId == 'R').teacher,
      'New',
    );
  });

  test(
    'same-value edits follow remote; unchanged overrides survive baseline catch-up',
    () async {
      service.incoming = [_course('R')];
      await runSync();
      final initial = (await db.getCoursesBySchedule(1)).single;
      final same = initial.withUserEdits(
        initial.copyWith(teacher: initial.teacher),
      );
      expect(same.editedFields, isNot(contains('teacher')));
      await db.updateCourse(same);
      service.incoming = [_course('R').copyWith(teacher: 'New remote')];
      await runSync();
      final afterSame = (await db.getCoursesBySchedule(1)).single;
      expect(afterSame.teacher, 'New remote');
      await db.updateCourse(
        afterSame.withUserEdits(afterSame.copyWith(teacher: 'My teacher')),
      );
      service.incoming = [_course('R').copyWith(teacher: 'My teacher')];
      await runSync();
      final caughtUp = (await db.getCoursesBySchedule(1)).single;
      expect(caughtUp.editedFields, contains('teacher'));
      await db.updateCourse(caughtUp.withUserEdits(caughtUp.copyWith()));
      service.incoming = [_course('R').copyWith(teacher: 'Later remote')];
      await runSync();
      expect((await db.getCoursesBySchedule(1)).single.teacher, 'My teacher');
    },
  );

  testWidgets('editor save retains remote metadata and week flags', (
    tester,
  ) async {
    service.incoming = [_course('R')];
    await runSync();
    final original = (await db.getCoursesBySchedule(
      1,
    )).single.copyWith(isOddWeek: true);
    await db.updateCourse(original);
    final provider = _EditorProvider(_schedule, [original]);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: AddCourseScreen(course: original, databaseHelper: db),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '可不填').first,
      'Editor teacher',
    );
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();
    final saved = (await db.getCoursesBySchedule(1)).single;
    expect(saved.id, original.id);
    expect(saved.sourceSystem, 'ug');
    expect(saved.remoteCourseKey, 'R');
    expect(saved.remoteBaseline, original.remoteBaseline);
    expect(saved.weekCode, original.weekCode);
    expect(saved.isOddWeek, true);
    expect(saved.editedFields, contains('teacher'));
  });

  testWidgets('saving without choosing an auto color does not pin color', (
    tester,
  ) async {
    final autoColor = AppCourseColorPalette.candyBox.autoColorToken(
      buildCourseColorSeed('Algebra', 'Professor'),
    );
    service.incoming = [_course('R').copyWith(color: autoColor)];
    await runSync();
    final original = (await db.getCoursesBySchedule(1)).single;
    final provider = _EditorProvider(_schedule, [original]);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: AddCourseScreen(course: original, databaseHelper: db),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();
    expect(
      (await db.getCoursesBySchedule(1)).single.editedFields,
      isNot(contains('color')),
    );
    service.incoming = [_course('R').copyWith(color: '#123456')];
    await runSync();
    expect((await db.getCoursesBySchedule(1)).single.color, '#123456');
  });

  testWidgets('unchanged editor save keeps override after remote catches up', (
    tester,
  ) async {
    service.incoming = [_course('R')];
    await runSync();
    final original = (await db.getCoursesBySchedule(1)).single;
    await db.updateCourse(
      original.withUserEdits(original.copyWith(teacher: 'Mine')),
    );
    service.incoming = [_course('R').copyWith(teacher: 'Mine')];
    await runSync();
    final caughtUp = (await db.getCoursesBySchedule(1)).single;
    expect(caughtUp.editedFields, contains('teacher'));
    final provider = _EditorProvider(_schedule, [caughtUp]);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: AddCourseScreen(course: caughtUp, databaseHelper: db),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();
    expect(
      (await db.getCoursesBySchedule(1)).single.editedFields,
      contains('teacher'),
    );
    service.incoming = [_course('R').copyWith(teacher: 'Later')];
    await runSync();
    expect((await db.getCoursesBySchedule(1)).single.teacher, 'Mine');
  });

  test(
    'migration SQL preserves v1 row IDs and adds provenance columns',
    () async {
      if (!Platform.isWindows) return;
      final fixture =
          '''
      CREATE TABLE schedules (id INTEGER PRIMARY KEY, name TEXT, year TEXT, term TEXT, startDate TEXT, isCurrent INTEGER);
      CREATE TABLE courses (id INTEGER PRIMARY KEY AUTOINCREMENT, scheduleId INTEGER, courseId TEXT, courseName TEXT, teacher TEXT, classRoom TEXT, startWeek INTEGER, endWeek INTEGER, dayOfWeek INTEGER, startNode INTEGER, step INTEGER, isOddWeek INTEGER, isEvenWeek INTEGER, weekCode TEXT, color TEXT, isVirtual INTEGER);
      INSERT INTO schedules VALUES(4, 'keep', '2025', '1', '2025-09-01', 1);
      INSERT INTO courses (id,scheduleId,courseId,courseName) VALUES (19,4,'R','keep');
      ${DatabaseHelper.courseProvenanceMigrationSql.join(';')};
      INSERT INTO courses (scheduleId,courseId,courseName,sourceSystem,remoteCourseKey,remoteBaseline,editedFields)
        VALUES (4,'R2','new','ug','R2','{"teacher":"remote"}','["teacher"]');
      SELECT id || ':' || scheduleId || ':' || sourceSystem || ':' || courseName FROM courses;
      SELECT id || ':' || remoteCourseKey || ':' || remoteBaseline || ':' || editedFields FROM courses WHERE courseId='R2';
      SELECT id || ':' || name FROM schedules;
      PRAGMA table_info(courses);
    ''';
      final result = await Process.run('sqlite3', [':memory:', fixture]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('19:4:legacy:keep'));
      expect(result.stdout, contains('20:4:ug:new'));
      expect(result.stdout, contains('20:R2:{"teacher":"remote"}:["teacher"]'));
      expect(result.stdout, contains('4:keep'));
      for (final field in [
        'sourceSystem',
        'remoteCourseKey',
        'remoteBaseline',
        'editedFields',
      ]) {
        expect(result.stdout, contains('|$field|'));
      }
    },
  );
}
