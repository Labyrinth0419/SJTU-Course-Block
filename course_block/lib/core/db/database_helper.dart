import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/course.dart';
import '../models/schedule.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  Database? _database;

  DatabaseHelper._init();

  // Allows service/widget tests to supply an isolated persistence implementation.
  DatabaseHelper.forTesting();

  static const courseProvenanceMigrationSql = <String>[
    "ALTER TABLE courses ADD COLUMN sourceSystem TEXT NOT NULL DEFAULT 'legacy'",
    'ALTER TABLE courses ADD COLUMN remoteCourseKey TEXT',
    'ALTER TABLE courses ADD COLUMN remoteBaseline TEXT',
    'ALTER TABLE courses ADD COLUMN editedFields TEXT',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('courses_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE schedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      year TEXT NOT NULL,
      term TEXT NOT NULL,
      startDate TEXT NOT NULL,
      isCurrent INTEGER NOT NULL DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE courses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      scheduleId INTEGER,
      courseId TEXT,
      courseName TEXT NOT NULL,
      teacher TEXT,
      classRoom TEXT,
      startWeek INTEGER NOT NULL,
      endWeek INTEGER NOT NULL,
      dayOfWeek INTEGER NOT NULL,
      startNode INTEGER NOT NULL,
      step INTEGER NOT NULL,
      isOddWeek INTEGER NOT NULL,
      isEvenWeek INTEGER NOT NULL,
      weekCode TEXT,
      color TEXT,
      isVirtual INTEGER NOT NULL DEFAULT 0,
      sourceSystem TEXT NOT NULL DEFAULT 'local',
      remoteCourseKey TEXT,
      remoteBaseline TEXT,
      editedFields TEXT,
      FOREIGN KEY (scheduleId) REFERENCES schedules (id) ON DELETE CASCADE
    )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final statement in courseProvenanceMigrationSql) {
        await db.execute(statement);
      }
    }
  }

  Future<int> insertSchedule(Schedule schedule) async {
    final db = await instance.database;
    if (schedule.isCurrent) {
      await db.update('schedules', {'isCurrent': 0});
    }
    return await db.insert('schedules', schedule.toMap());
  }

  Future<int> updateSchedule(Schedule schedule) async {
    final db = await instance.database;
    if (schedule.isCurrent) {
      await db.update('schedules', {'isCurrent': 0});
    }
    return await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await instance.database;
    await db.delete('courses', where: 'scheduleId = ?', whereArgs: [id]);
    return await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Schedule>> getAllSchedules() async {
    final db = await instance.database;
    final result = await db.query('schedules', orderBy: 'id DESC');
    return result.map((json) => Schedule.fromMap(json)).toList();
  }

  Future<Schedule?> getCurrentSchedule() async {
    final db = await instance.database;
    final result = await db.query(
      'schedules',
      where: 'isCurrent = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Schedule.fromMap(result.first);
    }
    return null;
  }

  Future<void> setCurrentSchedule(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update('schedules', {'isCurrent': 0});
      await txn.update(
        'schedules',
        {'isCurrent': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> insertCourse(Course course) async {
    final db = await instance.database;
    return await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCourse(Course course) async {
    final db = await instance.database;
    return await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }

  Future<int> deleteCourse(int id) async {
    final db = await instance.database;
    return await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAllCourses() async {
    final db = await instance.database;
    return await db.delete('courses');
  }

  Future<int> deleteCoursesBySchedule(int scheduleId) async {
    final db = await instance.database;
    return await db.delete(
      'courses',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<List<Course>> getCoursesBySchedule(int scheduleId) async {
    final db = await instance.database;
    final result = await db.query(
      'courses',
      where: 'scheduleId = ?',
      whereArgs: [scheduleId],
    );
    return result.map((json) => Course.fromMap(json)).toList();
  }

  Future<List<Course>> getAllCourses() async {
    final db = await instance.database;
    final result = await db.query('courses');
    return result.map((json) => Course.fromMap(json)).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
