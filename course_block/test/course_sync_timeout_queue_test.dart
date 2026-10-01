import 'dart:async';
import 'dart:typed_data';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/services/course_service.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _schedule = Schedule(
  id: 1,
  name: '2025-1 学期',
  year: '2025',
  term: '1',
  startDate: DateTime(2025, 9, 1),
  isCurrent: true,
);

Course _course({String id = 'R', String teacher = 'Original'}) => Course(
  courseId: id,
  courseName: 'Algebra',
  teacher: teacher,
  classRoom: 'A101',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startNode: 1,
  step: 2,
  weekCode: '1111',
  color: '#FF5722',
);

ResponseBody _response(String teacher) => ResponseBody.fromString(
  '{"kbList":[{"kch":"R","kcmc":"Algebra","xm":"$teacher",'
  '"cdmc":"A101","jcs":"1-2","zcd":"1-16周","xqj":"1"}]}',
  200,
);

class _Rows extends DatabaseHelper {
  _Rows() : super.forTesting();

  final rows = <int, Map<String, dynamic>>{};
  int nextId = 1;

  @override
  Future<Schedule?> getCurrentSchedule() async => _schedule;

  @override
  Future<List<Schedule>> getAllSchedules() async => [_schedule];

  @override
  Future<List<Course>> getCoursesBySchedule(int scheduleId) async => rows.values
      .where((row) => row['scheduleId'] == scheduleId)
      .map(Course.fromMap)
      .toList();

  @override
  Future<int> insertCourse(Course course) => withCourseWriteLock(() async {
    final id = course.id ?? nextId++;
    rows[id] = {...course.toMap(), 'id': id};
    return id;
  });

  @override
  Future<int> updateCourse(Course course) => withCourseWriteLock(() async {
    rows[course.id!] = course.toMap();
    return 1;
  });

  @override
  Future<int> deleteCourse(int id) =>
      withCourseWriteLock(() async => rows.remove(id) == null ? 0 : 1);

  List<Course> get persisted => rows.values.map(Course.fromMap).toList();
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(Future<void>?) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(cancelFuture);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'timeout frees queued local write and later sync; late response is ignored',
    () async {
      SharedPreferences.setMockInitialValues({
        'ug_cookies': 'fake-session',
        'active_login_system': 'ug',
      });
      final db = _Rows();
      await db.insertCourse(_course().copyWith(scheduleId: 1).bindRemote('ug'));
      final firstStarted = Completer<void>();
      final cancelled = Completer<void>();
      final lateReply = Completer<ResponseBody>();
      var requests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _Adapter((cancelFuture) {
        requests++;
        if (requests == 1) {
          firstStarted.complete();
          cancelFuture?.then((_) => cancelled.complete());
          return lateReply.future;
        }
        return Future.value(_response('Newer'));
      });
      final manager = CourseSyncManager(
        databaseHelper: db,
        courseService: CourseService(
          dio: dio,
          requestTimeout: const Duration(milliseconds: 80),
        ),
      );
      Future<CourseSyncExecutionResult> sync() => manager.syncCourses(
        year: '2025',
        term: '1',
        currentSchedule: _schedule,
        schedules: [_schedule],
        courses: db.persisted,
        courseColorPalette: AppCourseColorPalette.candyBox,
        defaultScheduleName: '默认课表',
      );

      final first = sync();
      await firstStarted.future.timeout(const Duration(milliseconds: 500));
      final localWrite = db.insertCourse(
        _course(id: 'local', teacher: 'Local').copyWith(scheduleId: 1),
      );
      final next = sync();
      expect(db.persisted.single.teacher, 'Original');

      final timedOut = await first.timeout(const Duration(milliseconds: 500));
      expect(timedOut.report.failed, 1);
      expect(timedOut.report.failures.single.reason, contains('超时'));
      await cancelled.future.timeout(const Duration(milliseconds: 500));
      expect(
        db.persisted.where((row) => row.courseId == 'R').single.teacher,
        'Original',
      );

      await localWrite.timeout(const Duration(milliseconds: 500));
      final second = await next.timeout(const Duration(milliseconds: 500));
      expect(second.report.failed, 0);
      expect(requests, 2);
      expect(
        db.persisted.where((row) => row.courseId == 'R').single.teacher,
        'Newer',
      );
      expect(
        db.persisted.where((row) => row.courseId == 'local').single.teacher,
        'Local',
      );

      lateReply.complete(_response('Older'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        db.persisted.where((row) => row.courseId == 'R').single.teacher,
        'Newer',
      );
      expect(
        db.persisted.where((row) => row.courseId == 'local').single.teacher,
        'Local',
      );
    },
  );
}
