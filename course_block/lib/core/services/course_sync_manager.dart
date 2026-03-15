import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_operation_report.dart';
import '../models/schedule.dart';
import '../theme/app_theme.dart';
import '../utils/time_slots.dart';
import 'course_service.dart';
import 'login_session.dart';

class CourseSyncExecutionResult {
  const CourseSyncExecutionResult({
    required this.report,
    required this.currentSchedule,
    required this.schedules,
    required this.courses,
  });

  final CourseSyncReport report;
  final Schedule? currentSchedule;
  final List<Schedule> schedules;
  final List<Course> courses;
}

class CourseSyncManager {
  CourseSyncManager({
    DatabaseHelper? databaseHelper,
    CourseService? courseService,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _courseService = courseService ?? CourseService();

  final DatabaseHelper _databaseHelper;
  final CourseService _courseService;

  Future<CourseSyncExecutionResult> syncCourses({
    required String year,
    required String term,
    required Schedule? currentSchedule,
    required List<Schedule> schedules,
    required List<Course> courses,
    required AppCourseColorPalette courseColorPalette,
    required String defaultScheduleName,
  }) async {
    final syncSystems = await _resolveSyncSystemOrder();
    CourseFetchResult? fetchResult;
    CourseFetchResult? lastEmptyResult;
    CourseSyncException? recoverableException;

    for (final system in syncSystems) {
      try {
        final result = system == AcademicLoginSystem.undergraduate
            ? await _courseService.fetchUndergraduateCourses(
                year,
                term,
                courseColorPalette: courseColorPalette,
              )
            : await _courseService.fetchGraduateCourses(
                year,
                term,
                courseColorPalette: courseColorPalette,
              );

        if (result.courses.isNotEmpty) {
          fetchResult = result;
          break;
        }

        lastEmptyResult = result;
      } on CourseSyncException catch (e) {
        final canFallback =
            syncSystems.length > 1 &&
            (e is AcademicLoginRequiredException ||
                e is GraduateLoginRequiredException);
        if (!canFallback) {
          rethrow;
        }
        recoverableException = e;
      }
    }

    fetchResult ??= lastEmptyResult;
    if (fetchResult == null) {
      if (recoverableException != null) {
        throw recoverableException;
      }
      return CourseSyncExecutionResult(
        report: CourseSyncReport(
          termLabel: _buildTermLabel(year, term),
          sourceLabel: '教务系统',
          added: 0,
          updated: 0,
          skipped: 0,
          failed: 0,
          notes: const ['未获取到课程，请稍后重试。'],
        ),
        currentSchedule: currentSchedule,
        schedules: schedules,
        courses: courses,
      );
    }

    if (fetchResult.courses.isEmpty) {
      return CourseSyncExecutionResult(
        report: CourseSyncReport(
          termLabel: _buildTermLabel(year, term),
          sourceLabel: fetchResult.sourceLabel,
          added: 0,
          updated: 0,
          skipped: 0,
          failed: fetchResult.failures.length,
          notes: [
            ...fetchResult.notes,
            if (fetchResult.failures.isEmpty) '所选学期暂无可同步课程。',
          ],
          failures: fetchResult.failures,
        ),
        currentSchedule: currentSchedule,
        schedules: schedules,
        courses: courses,
      );
    }

    var nextCurrentSchedule = currentSchedule;
    var nextSchedules = [...schedules];
    final termLabel = _buildTermLabel(year, term);

    if (nextCurrentSchedule == null) {
      final now = DateTime.now();
      final today = normalizeDate(now);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

      final newSchedule = Schedule(
        name: '$year-$term 学期',
        year: year,
        term: term,
        startDate: startOfWeek,
        isCurrent: true,
      );
      final id = await _databaseHelper.insertSchedule(newSchedule);
      nextCurrentSchedule = newSchedule.copyWith(id: id);
      nextSchedules = _upsertScheduleCache(nextSchedules, nextCurrentSchedule);
    } else if (nextCurrentSchedule.year != year ||
        nextCurrentSchedule.term != term) {
      nextCurrentSchedule = nextCurrentSchedule.copyWith(
        year: year,
        term: term,
        name:
            _usesGeneratedScheduleName(
              nextCurrentSchedule,
              defaultScheduleName: defaultScheduleName,
            )
            ? _buildScheduleName(year, term)
            : nextCurrentSchedule.name,
      );
      await _databaseHelper.updateSchedule(nextCurrentSchedule);
      nextSchedules = _upsertScheduleCache(nextSchedules, nextCurrentSchedule);
    }

    if (nextCurrentSchedule.id == null) {
      return CourseSyncExecutionResult(
        report: CourseSyncReport(
          termLabel: termLabel,
          sourceLabel: fetchResult.sourceLabel,
          added: 0,
          updated: 0,
          skipped: 0,
          failed: 1,
          notes: const ['当前课表创建失败，无法保存同步结果。'],
          failures: const [
            CourseOperationFailure(label: '当前课表', reason: '未找到可写入的课表'),
          ],
        ),
        currentSchedule: currentSchedule,
        schedules: schedules,
        courses: courses,
      );
    }

    final scheduleId = nextCurrentSchedule.id!;
    final existingCourses = await _databaseHelper.getCoursesBySchedule(
      scheduleId,
    );
    final uniqueCourses = <String, Course>{};
    var duplicateCount = 0;
    for (final course in fetchResult.courses) {
      final key = _courseExactKey(course);
      if (uniqueCourses.containsKey(key)) {
        duplicateCount++;
        continue;
      }
      uniqueCourses[key] = course;
    }

    final targetCourses = uniqueCourses.values
        .map((course) => _bindFetchedCourseToSchedule(course, scheduleId))
        .toList();
    final diff = _diffCourses(existingCourses, targetCourses);

    await _databaseHelper.deleteCoursesBySchedule(scheduleId);

    final insertFailures = <CourseOperationFailure>[];
    for (final course in targetCourses) {
      try {
        await _databaseHelper.insertCourse(course);
      } catch (e) {
        insertFailures.add(
          CourseOperationFailure(
            label: course.courseName,
            reason: '写入失败：${_formatOperationError(e, fallback: '无法保存这条课程')}',
          ),
        );
      }
    }

    final persistedCourses = await _databaseHelper.getCoursesBySchedule(
      scheduleId,
    );
    final notes = <String>[
      ...fetchResult.notes,
      if (duplicateCount > 0) '已合并 $duplicateCount 条重复课程记录。',
      if (diff.removed > 0) '同步后有 ${diff.removed} 条旧课程未保留。',
    ];

    return CourseSyncExecutionResult(
      report: CourseSyncReport(
        termLabel: termLabel,
        sourceLabel: fetchResult.sourceLabel,
        added: diff.added,
        updated: diff.updated,
        skipped: diff.skipped,
        failed: fetchResult.failures.length + insertFailures.length,
        notes: notes,
        failures: [...fetchResult.failures, ...insertFailures],
      ),
      currentSchedule: nextCurrentSchedule,
      schedules: nextSchedules,
      courses: persistedCourses,
    );
  }

  Future<List<AcademicLoginSystem>> _resolveSyncSystemOrder() async {
    final availableSystems = await LoginSessionStorage.loadAvailableSystems();
    if (availableSystems.isEmpty) {
      throw const AcademicLoginRequiredException();
    }

    final activeSystem = await LoginSessionStorage.loadActiveSystem();
    if (activeSystem != null && availableSystems.contains(activeSystem)) {
      return [activeSystem];
    }

    if (availableSystems.length == 1) {
      return availableSystems;
    }

    return [
      if (availableSystems.contains(AcademicLoginSystem.undergraduate))
        AcademicLoginSystem.undergraduate,
      if (availableSystems.contains(AcademicLoginSystem.graduate))
        AcademicLoginSystem.graduate,
    ];
  }

  String _buildScheduleName(String year, String term) => '$year-$term 学期';

  String _buildTermLabel(String year, String term) {
    final nextYear = (int.tryParse(year) ?? 0) + 1;
    final termLabel = switch (term) {
      '2' => '第2学期（春季）',
      '3' => '第3学期（夏季）',
      _ => '第1学期（秋季）',
    };
    return '$year~$nextYear $termLabel';
  }

  bool _usesGeneratedScheduleName(
    Schedule schedule, {
    required String defaultScheduleName,
  }) {
    return schedule.name == defaultScheduleName ||
        schedule.name == _buildScheduleName(schedule.year, schedule.term);
  }

  List<Schedule> _upsertScheduleCache(
    List<Schedule> schedules,
    Schedule schedule,
  ) {
    final nextSchedules = [...schedules];
    final index = nextSchedules.indexWhere((item) => item.id == schedule.id);
    if (index >= 0) {
      nextSchedules[index] = schedule;
      return nextSchedules;
    }
    return [...nextSchedules, schedule];
  }

  Course _bindFetchedCourseToSchedule(Course course, int scheduleId) {
    return course.copyWith(scheduleId: scheduleId, isVirtual: course.isVirtual);
  }

  String _courseExactKey(Course course) {
    return [
      course.courseId.trim(),
      course.courseName.trim(),
      course.teacher.trim(),
      course.classRoom.trim(),
      course.dayOfWeek,
      course.startNode,
      course.step,
      course.startWeek,
      course.endWeek,
      course.isOddWeek ? 1 : 0,
      course.isEvenWeek ? 1 : 0,
      course.weekCode ?? '',
      course.isVirtual ? 1 : 0,
    ].join('|');
  }

  String _courseStableKey(Course course) {
    return [
      course.courseId.trim(),
      course.courseName.trim(),
      course.teacher.trim(),
      course.dayOfWeek,
      course.startNode,
      course.step,
    ].join('|');
  }

  bool _consumeCount(Map<String, int> counts, String key) {
    final current = counts[key] ?? 0;
    if (current <= 0) {
      return false;
    }
    if (current == 1) {
      counts.remove(key);
    } else {
      counts[key] = current - 1;
    }
    return true;
  }

  _CourseDiffSummary _diffCourses(
    List<Course> existingCourses,
    List<Course> incomingCourses,
  ) {
    final exactCounts = <String, int>{};
    final stableCounts = <String, int>{};

    for (final course in existingCourses) {
      final exactKey = _courseExactKey(course);
      final stableKey = _courseStableKey(course);
      exactCounts[exactKey] = (exactCounts[exactKey] ?? 0) + 1;
      stableCounts[stableKey] = (stableCounts[stableKey] ?? 0) + 1;
    }

    var added = 0;
    var updated = 0;
    var skipped = 0;

    for (final course in incomingCourses) {
      final exactKey = _courseExactKey(course);
      final stableKey = _courseStableKey(course);

      if (_consumeCount(exactCounts, exactKey)) {
        _consumeCount(stableCounts, stableKey);
        skipped++;
        continue;
      }

      if (_consumeCount(stableCounts, stableKey)) {
        updated++;
        continue;
      }

      added++;
    }

    final removed = (existingCourses.length - skipped - updated).clamp(
      0,
      existingCourses.length,
    );
    return _CourseDiffSummary(
      added: added,
      updated: updated,
      skipped: skipped,
      removed: removed,
    );
  }

  String _formatOperationError(Object error, {required String fallback}) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
    return raw.isEmpty ? fallback : raw;
  }
}

class _CourseDiffSummary {
  const _CourseDiffSummary({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.removed,
  });

  final int added;
  final int updated;
  final int skipped;
  final int removed;
}
