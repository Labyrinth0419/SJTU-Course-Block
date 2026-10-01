import 'dart:convert';
import 'dart:io';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/services/course_service.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/services/course_transfer_manager.dart';
import 'package:course_block/core/services/login_session.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/core/utils/course_occurrences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course _course(String courseId) => Course(
  courseId: courseId,
  courseName: 'Calculus',
  teacher: 'Professor',
  classRoom: 'A101',
  startWeek: 1,
  endWeek: 8,
  dayOfWeek: 3,
  startNode: 1,
  step: 2,
  weekCode: '10100001',
);

final _schedule = Schedule(
  id: 2,
  name: 'Imported schedule',
  year: '2026',
  term: '2',
  startDate: DateTime(2026, 3, 2),
  isCurrent: true,
);

class _Database extends DatabaseHelper {
  _Database() : super.forTesting();

  final rows = <int, Map<String, dynamic>>{};
  int nextId = 1;

  @override
  Future<int> insertCourse(Course course) async {
    final id = course.id ?? nextId++;
    if (id >= nextId) nextId = id + 1;
    rows[id] = {...course.toMap(), 'id': id};
    return id;
  }

  @override
  Future<int> updateCourse(Course course) async {
    if (!rows.containsKey(course.id)) throw StateError('Missing row');
    rows[course.id!] = course.toMap();
    return 1;
  }

  @override
  Future<int> deleteCourse(int id) async => rows.remove(id) == null ? 0 : 1;

  @override
  Future<List<Course>> getCoursesBySchedule(int scheduleId) async => [
    for (final row in rows.values)
      if (row['scheduleId'] == scheduleId) Course.fromMap(row),
  ];
}

class _CourseService extends CourseService {
  List<Course> incoming = [];

  @override
  Future<CourseFetchResult> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async => CourseFetchResult(
    sourceSystem: AcademicLoginSystem.undergraduate,
    courses: incoming,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late _Database db;
  late _CourseService service;
  late CourseTransferManager transfer;
  late CourseSyncManager sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ug_cookies': 'test-session',
      'active_login_system': 'ug',
    });
    temp = await Directory.systemTemp.createTemp('course-data-integration-');
    db = _Database();
    service = _CourseService();
    transfer = CourseTransferManager(databaseHelper: db);
    sync = CourseSyncManager(databaseHelper: db, courseService: service);
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<void> refresh() async {
    final result = await sync.syncCourses(
      year: _schedule.year,
      term: _schedule.term,
      currentSchedule: _schedule,
      schedules: [_schedule],
      courses: await db.getCoursesBySchedule(_schedule.id!),
      courseColorPalette: AppCourseColorPalette.candyBox,
      defaultScheduleName: 'Default',
    );
    expect(result.report.failed, 0);
  }

  Future<void> expectImportSurvivesSync(int id) async {
    final before = Map<String, dynamic>.from(db.rows[id]!);
    service.incoming = [_course('R')];
    await refresh();
    service.incoming = [_course('S')];
    await refresh();
    await refresh();
    expect(db.rows[id], before);
    final saved = await db.getCoursesBySchedule(_schedule.id!);
    expect(saved, hasLength(2));
    expect(saved.singleWhere((c) => c.id == id).sourceSystem, 'local');
    expect(saved.singleWhere((c) => c.sourceSystem == 'ug').courseId, 'S');
  }

  test('JSON cannot inject persistence or remote override metadata', () async {
    final existing = _course(
      'Original',
    ).bindRemote('ug').copyWith(id: 7, scheduleId: 1);
    await db.insertCourse(existing);
    final originalRow = Map<String, dynamic>.from(db.rows[7]!);
    final file = File('${temp.path}/untrusted.json');
    await file.writeAsString(
      jsonEncode([
        {
          ..._course('R').toMap(),
          'id': 7,
          'scheduleId': 1,
          'sourceSystem': 'ug',
          'remoteCourseKey': 'R',
          'remoteBaseline': 'not valid JSON',
          'editedFields': 'not valid JSON',
        },
      ]),
    );

    final report = await transfer.importCoursesJson(
      path: file.path,
      scheduleId: _schedule.id,
    );
    expect((report.added, report.failed), (1, 0));
    expect(db.rows[7], originalRow);
    final imported = (await db.getCoursesBySchedule(_schedule.id!)).single;
    expect(imported.id, isNot(7));
    expect(imported.sourceSystem, 'local');
    expect(imported.remoteCourseKey, isNull);
    expect(imported.remoteBaseline, isNull);
    expect(imported.editedFields, isEmpty);
    await expectImportSurvivesSync(imported.id!);
    expect(db.rows[7], originalRow);
  });

  test('exported remote edits become independent local JSON courses', () async {
    final remote = _course('R').bindRemote('ug');
    final edited = remote.withUserEdits(remote.copyWith(classRoom: 'My room'));
    final exported =
        jsonDecode(utf8.decode(await transfer.exportCoursesJsonBytes([edited])))
            as List;
    final payload = exported.single as Map<String, dynamic>;
    for (final key in [
      'id',
      'scheduleId',
      'sourceSystem',
      'remoteCourseKey',
      'remoteBaseline',
      'editedFields',
    ]) {
      expect(payload.containsKey(key), isFalse, reason: key);
    }
    final file = File('${temp.path}/portable.json');
    await file.writeAsString(jsonEncode(exported));
    final report = await transfer.importCoursesJson(
      path: file.path,
      scheduleId: _schedule.id,
    );
    expect((report.added, report.failed), (1, 0));
    final imported = (await db.getCoursesBySchedule(_schedule.id!)).single;
    expect(imported.classRoom, 'My room');
    expect(imported.sourceSystem, 'local');
    expect(imported.editedFields, isEmpty);
    await expectImportSurvivesSync(imported.id!);
  });

  test(
    'sparse ICS import remains local through remote refresh and removal',
    () async {
      final file = File('${temp.path}/portable.ics');
      await file.writeAsBytes(
        await transfer.exportCoursesIcsBytes([
          _course('R').bindRemote('ug'),
        ], _schedule.startDate),
      );
      final report = await transfer.importCoursesIcs(
        path: file.path,
        scheduleId: _schedule.id,
        startDate: _schedule.startDate,
        courseColorPalette: AppCourseColorPalette.candyBox,
      );
      expect((report.added, report.failed), (1, 0));
      final imported = (await db.getCoursesBySchedule(_schedule.id!)).single;
      expect(imported.sourceSystem, 'local');
      expect(imported.remoteCourseKey, isNull);
      expect(courseOccurrenceWeeks(imported), [1, 3, 8]);
      await expectImportSurvivesSync(imported.id!);
    },
  );
}
