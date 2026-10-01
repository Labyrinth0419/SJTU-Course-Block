import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_operation_report.dart';
import '../models/schedule.dart';
import '../theme/app_theme.dart';
import '../utils/time_slots.dart';
import 'course_service.dart';
import 'course_sync_merge.dart';
import 'login_session.dart';

class SemesterStartDateRequiredException extends CourseSyncException {
  const SemesterStartDateRequiredException()
    : super('请先选择该学期第一周的开学日期，再创建课表并同步。');
}

class AmbiguousSemesterSyncException extends CourseSyncException {
  AmbiguousSemesterSyncException(String year, String term)
    : super('学期 $year-$term 有多个课表；请先切换到要同步的课表，再重试。');
}

class CourseSyncExecutionResult {
  const CourseSyncExecutionResult({
    required this.report,
    required this.currentSchedule,
    required this.schedules,
    required this.courses,
    this.createdSchedule = false,
  });

  final CourseSyncReport report;
  final Schedule? currentSchedule;
  final List<Schedule> schedules;
  final List<Course> courses;
  final bool createdSchedule;
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
    DateTime? startDate,
  }) => _databaseHelper.withCourseWriteLock(() async {
    // Full requests are ordered at invocation, not at fetch completion: an
    // older response must never apply after a newer one. Network wait holds
    // this lane, so local writes may wait for a slow sync.
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

    // Target resolution and creation run against persisted schedules inside
    // the same lane as the course merge, not against a caller's stale cache.
    final persistedSchedules = await _databaseHelper.getAllSchedules();
    final persistedCurrent = await _databaseHelper.getCurrentSchedule();
    final matches = persistedSchedules
        .where((schedule) => schedule.year == year && schedule.term == term)
        .toList();
    final preferredId =
        persistedCurrent?.year == year && persistedCurrent?.term == term
        ? persistedCurrent?.id
        : currentSchedule?.id;
    Schedule? nextCurrentSchedule;
    for (final match in matches) {
      if (match.id == preferredId) nextCurrentSchedule = match;
    }
    if (nextCurrentSchedule == null && matches.length == 1) {
      nextCurrentSchedule = matches.single;
    }
    if (nextCurrentSchedule == null && matches.length > 1) {
      throw AmbiguousSemesterSyncException(year, term);
    }

    var createdSchedule = false;
    final placeholder =
        persistedSchedules.length == 1 &&
            persistedSchedules.single.name == defaultScheduleName
        ? persistedSchedules.single
        : null;
    final bindsPlaceholder =
        placeholder != null &&
        (nextCurrentSchedule == null ||
            nextCurrentSchedule.id == placeholder.id) &&
        (await _databaseHelper.getCoursesBySchedule(placeholder.id!)).isEmpty;
    if (bindsPlaceholder) {
      if (startDate == null) throw const SemesterStartDateRequiredException();
      nextCurrentSchedule = placeholder.copyWith(
        name: _buildScheduleName(year, term),
        year: year,
        term: term,
        startDate: normalizeDate(startDate),
        isCurrent: true,
      );
      await _databaseHelper.updateSchedule(nextCurrentSchedule);
    } else if (nextCurrentSchedule == null) {
      if (startDate == null) throw const SemesterStartDateRequiredException();
      final newSchedule = Schedule(
        name: _buildScheduleName(year, term),
        year: year,
        term: term,
        startDate: normalizeDate(startDate),
        isCurrent: true,
      );
      final id = await _databaseHelper.insertSchedule(newSchedule);
      nextCurrentSchedule = newSchedule.copyWith(id: id);
      createdSchedule = true;
    } else if (nextCurrentSchedule.id != persistedCurrent?.id) {
      await _databaseHelper.setCurrentSchedule(nextCurrentSchedule.id!);
    }
    final nextSchedules = await _databaseHelper.getAllSchedules();
    nextCurrentSchedule = nextCurrentSchedule.copyWith(isCurrent: true);
    final termLabel = _buildTermLabel(year, term);

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
    final hasMissingCourseIds = targetCourses.any(
      (course) => course.courseId.trim().isEmpty,
    );
    final plan = planCourseSync(
      existing: existingCourses,
      incoming: targetCourses,
      sourceSystem: fetchResult.sourceSystem.storageKey,
      allowRemoval: fetchResult.failures.isEmpty && !hasMissingCourseIds,
    );
    final writeFailures = <CourseOperationFailure>[];
    var added = 0;
    var updated = 0;
    var removed = 0;
    for (final course in plan.updates) {
      try {
        await _databaseHelper.updateCourse(course);
        if (course.sourceSystem == fetchResult.sourceSystem.storageKey) {
          updated++;
        }
      } catch (e) {
        writeFailures.add(
          CourseOperationFailure(
            label: course.courseName,
            reason: '更新失败：${_formatOperationError(e, fallback: '无法保存这条课程')}',
          ),
        );
      }
    }
    for (final course in plan.inserts) {
      try {
        await _databaseHelper.insertCourse(course);
        added++;
      } catch (e) {
        writeFailures.add(
          CourseOperationFailure(
            label: course.courseName,
            reason: '写入失败：${_formatOperationError(e, fallback: '无法保存这条课程')}',
          ),
        );
      }
    }
    for (final id in plan.deletes) {
      try {
        removed += await _databaseHelper.deleteCourse(id);
      } catch (e) {
        writeFailures.add(
          CourseOperationFailure(
            label: '课程 $id',
            reason: '删除失败：${_formatOperationError(e, fallback: '无法保存这条课程')}',
          ),
        );
      }
    }

    final persistedCourses = await _databaseHelper.getCoursesBySchedule(
      scheduleId,
    );
    final notes = <String>[
      ...fetchResult.notes,
      ...plan.notes,
      if (duplicateCount > 0) '已合并 $duplicateCount 条重复课程记录。',
      if (removed > 0) '同步后移除了 $removed 条教务系统已删除的课程。',
      if (fetchResult.failures.isNotEmpty) '部分排课解析失败，本次未删除旧教务课程。',
      if (hasMissingCourseIds) '部分课程缺少教务编号，本次未删除旧教务课程。',
    ];

    return CourseSyncExecutionResult(
      report: CourseSyncReport(
        termLabel: termLabel,
        sourceLabel: fetchResult.sourceLabel,
        added: added,
        updated: updated,
        skipped: plan.skipped,
        failed: fetchResult.failures.length + writeFailures.length,
        notes: notes,
        failures: [...fetchResult.failures, ...writeFailures],
      ),
      currentSchedule: nextCurrentSchedule,
      schedules: nextSchedules,
      courses: persistedCourses,
      createdSchedule: createdSchedule,
    );
  });

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

  Course _bindFetchedCourseToSchedule(Course course, int scheduleId) {
    // Upstream data must never reuse a local database ID or imported provenance.
    return Course.fromMap({
      ...course.toMap(),
      'id': null,
      'scheduleId': scheduleId,
      'sourceSystem': 'local',
      'remoteCourseKey': null,
      'remoteBaseline': null,
      'editedFields': '[]',
    });
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

  String _formatOperationError(Object error, {required String fallback}) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
    return raw.isEmpty ? fallback : raw;
  }
}
