import '../db/database_helper.dart';

class PerformanceTestDataResult {
  const PerformanceTestDataResult({
    required this.scheduleCount,
    required this.courseCount,
  });

  final int scheduleCount;
  final int courseCount;
}

class PerformanceTestDataService {
  PerformanceTestDataService({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  static const schedulePrefix = '性能测试课表';
  static const scheduleCount = 10;
  static const coursesPerSchedule = 150;

  final DatabaseHelper _databaseHelper;

  Future<PerformanceTestDataResult> replaceWithLargeDataset() async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      final oldSchedules = await txn.query(
        'schedules',
        columns: ['id'],
        where: 'name LIKE ?',
        whereArgs: ['$schedulePrefix%'],
      );
      final oldIds = oldSchedules
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      if (oldIds.isNotEmpty) {
        final placeholders = List.filled(oldIds.length, '?').join(',');
        await txn.delete(
          'courses',
          where: 'scheduleId IN ($placeholders)',
          whereArgs: oldIds,
        );
        await txn.delete(
          'schedules',
          where: 'id IN ($placeholders)',
          whereArgs: oldIds,
        );
      }

      await txn.update('schedules', {'isCurrent': 0});
      final monday = _startOfCurrentWeek();

      for (
        var scheduleIndex = 0;
        scheduleIndex < scheduleCount;
        scheduleIndex++
      ) {
        final scheduleId = await txn.insert('schedules', {
          'name': '$schedulePrefix ${scheduleIndex + 1}',
          'year': '${monday.year}-${monday.year + 1}',
          'term': '1',
          'startDate': monday.toIso8601String(),
          'isCurrent': scheduleIndex == 0 ? 1 : 0,
        });

        for (
          var courseIndex = 0;
          courseIndex < coursesPerSchedule;
          courseIndex++
        ) {
          await txn.insert('courses', _courseRow(scheduleId, courseIndex));
        }
      }
    });

    return const PerformanceTestDataResult(
      scheduleCount: scheduleCount,
      courseCount: scheduleCount * coursesPerSchedule,
    );
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  Map<String, Object?> _courseRow(int scheduleId, int index) {
    final dayOfWeek = index % 7 + 1;
    final startNode = index % 12 + 1;
    final step = index % 3 == 0 ? 2 : 1;
    final courseNumber = index + 1;
    final color = _colors[index % _colors.length];

    return {
      'scheduleId': scheduleId,
      'courseId': 'PERF-${scheduleId.toString().padLeft(2, '0')}-$courseNumber',
      'courseName': '性能测试课程 ${courseNumber.toString().padLeft(3, '0')}',
      'teacher': '测试教师 ${index % 24 + 1}',
      'classRoom': '测试楼${index % 8 + 1}-${index % 30 + 101}',
      'startWeek': 1,
      'endWeek': 20,
      'dayOfWeek': dayOfWeek,
      'startNode': startNode,
      'step': step,
      'isOddWeek': 0,
      'isEvenWeek': 0,
      'weekCode': '1-20',
      'color': color,
      'isVirtual': 0,
    };
  }

  static const _colors = [
    '#FF758F',
    '#9B9BFF',
    '#4ADBC8',
    '#FF9F46',
    '#A06CD5',
    '#FFB7B2',
    '#B5EAD7',
    '#C7CEEA',
    '#E2F0CB',
    '#FFDAC1',
    '#FF9AA2',
    '#6EB5FF',
  ];
}
