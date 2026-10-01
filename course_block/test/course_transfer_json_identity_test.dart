import 'dart:convert';
import 'dart:io';

import 'package:course_block/core/db/database_helper.dart';
import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/services/course_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

const _portableFields = {
  'courseId',
  'courseName',
  'teacher',
  'classRoom',
  'startWeek',
  'endWeek',
  'dayOfWeek',
  'startNode',
  'step',
  'isOddWeek',
  'isEvenWeek',
  'weekCode',
  'color',
  'isVirtual',
};

Course _course({int? id, int? scheduleId, String name = 'Calculus'}) => Course(
  id: id,
  scheduleId: scheduleId,
  courseId: 'MATH101',
  courseName: name,
  teacher: 'Tutor',
  classRoom: 'A101',
  startWeek: 2,
  endWeek: 10,
  dayOfWeek: 3,
  startNode: 1,
  step: 2,
  isOddWeek: true,
  weekCode: '0101010101',
  color: '#FF758F',
  isVirtual: true,
);

class _ReplaceOnPrimaryKeyDatabase implements DatabaseHelper {
  final rows = <int, Course>{};
  final inserted = <Course>[];
  var _nextId = 1;

  void seed(Course course) {
    final id = course.id!;
    rows[id] = course;
    if (id >= _nextId) _nextId = id + 1;
  }

  @override
  Future<int> insertCourse(Course course) async {
    inserted.add(course);
    final id = course.id ?? _nextId++;
    if (id >= _nextId) _nextId = id + 1;
    rows[id] = course.copyWith(id: id);
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('course-json-'),
  );
  tearDown(() async => temp.delete(recursive: true));

  Future<String> writeJson(Object value) async {
    final file = File('${temp.path}/import.json');
    await file.writeAsString(jsonEncode(value));
    return file.path;
  }

  test('file and byte exports contain only portable course fields', () async {
    final course = _course(id: 12, scheduleId: 7);
    final manager = CourseTransferManager();
    final path = '${temp.path}/export.json';
    await manager.exportCoursesJson([course], path);
    final fileItems = jsonDecode(await File(path).readAsString()) as List;
    final byteItems =
        jsonDecode(utf8.decode(await manager.exportCoursesJsonBytes([course])))
            as List;

    for (final item in [fileItems.single, byteItems.single]) {
      final payload = item as Map<String, dynamic>;
      expect(payload.keys.toSet(), _portableFields);
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('scheduleId')));
      expect(payload, isNot(contains('sourceId')));
      expect(payload, isNot(contains('remoteId')));
    }
    expect(fileItems, byteItems);
  });

  test('legacy JSON id cannot replace the source schedule course', () async {
    final db = _ReplaceOnPrimaryKeyDatabase();
    final source = _course(id: 10, scheduleId: 1, name: 'Original');
    db.seed(source);
    final path = await writeJson([
      {..._course(id: 10, scheduleId: 1, name: 'Imported').toMap()},
    ]);

    final report = await CourseTransferManager(
      databaseHelper: db,
    ).importCoursesJson(path: path, scheduleId: 2);

    expect(report.added, 1);
    expect(report.failed, 0);
    expect(db.rows[10], same(source));
    expect(db.rows, hasLength(2));
    expect(db.inserted.single.id, isNull);
    final imported = db.rows.values.singleWhere((row) => row.id != 10);
    expect(imported.id, greaterThan(10));
    expect(imported.scheduleId, 2);
    expect(imported.courseName, 'Imported');
  });

  test(
    'foreign ids cannot overwrite existing rows in either schedule',
    () async {
      final db = _ReplaceOnPrimaryKeyDatabase();
      final current = _course(id: 3, scheduleId: 2, name: 'Current');
      final other = _course(id: 8, scheduleId: 4, name: 'Other');
      db.seed(current);
      db.seed(other);
      final path = await writeJson([
        {
          ..._course(id: 3, scheduleId: 99, name: 'Foreign A').toMap(),
          'remoteId': 'remote-a',
        },
        {
          ..._course(id: 8, scheduleId: 99, name: 'Foreign B').toMap(),
          'sourceId': 'remote-b',
        },
      ]);

      final report = await CourseTransferManager(
        databaseHelper: db,
      ).importCoursesJson(path: path, scheduleId: 2);

      expect(report.added, 2);
      expect(report.failed, 0);
      expect(db.rows[3], same(current));
      expect(db.rows[8], same(other));
      expect(db.rows, hasLength(4));
      expect(db.inserted.every((row) => row.id == null), isTrue);
      expect(db.inserted.every((row) => row.scheduleId == 2), isTrue);
      final imported = db.rows.values.where(
        (row) => row.id != 3 && row.id != 8,
      );
      expect(imported.map((row) => row.id).toSet(), {9, 10});
      expect(imported.every((row) => row.scheduleId == 2), isTrue);
    },
  );

  test('malformed JSON items retain per-item failure reporting', () async {
    final db = _ReplaceOnPrimaryKeyDatabase();
    final path = await writeJson([
      _course(name: 'First').toMap(),
      'not a course',
      {..._course(name: 'Bad').toMap(), 'startWeek': 'not an integer'},
      _course(name: 'Last').toMap(),
    ]);

    final report = await CourseTransferManager(
      databaseHelper: db,
    ).importCoursesJson(path: path, scheduleId: 2);

    expect(report.added, 2);
    expect(report.failed, 2);
    expect(report.failures.map((failure) => failure.label), ['第 2 条', 'Bad']);
    expect(
      report.failures.every((failure) => failure.reason.isNotEmpty),
      isTrue,
    );
    expect(report.notes, isNotEmpty);
    expect(db.rows.values.map((row) => row.courseName), ['First', 'Last']);
  });

  test(
    'portable JSON round-trips fields and binds to the chosen schedule',
    () async {
      final original = _course(id: 15, scheduleId: 1);
      final manager = CourseTransferManager();
      final path = '${temp.path}/portable.json';
      await manager.exportCoursesJson([original], path);
      final db = _ReplaceOnPrimaryKeyDatabase()..seed(original);

      final report = await CourseTransferManager(
        databaseHelper: db,
      ).importCoursesJson(path: path, scheduleId: 7);

      expect(report.added, 1);
      expect(report.failed, 0);
      expect(db.rows[15], same(original));
      final imported = db.rows.values.singleWhere((row) => row.id != 15);
      expect(imported.id, greaterThan(15));
      expect(imported.scheduleId, 7);
      final exported = jsonDecode(await File(path).readAsString()) as List;
      expect(exported.single, {
        for (final key in _portableFields) key: imported.toMap()[key],
      });
    },
  );
}
