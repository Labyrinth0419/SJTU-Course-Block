import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/course_operation_report.dart';
import '../theme/app_theme.dart';
import '../utils/time_slots.dart';
import 'calendar_service.dart';

class CourseTransferManager {
  CourseTransferManager({
    DatabaseHelper? databaseHelper,
    CalendarService? calendarService,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _calendarService = calendarService ?? CalendarService();

  final DatabaseHelper _databaseHelper;
  final CalendarService _calendarService;

  Future<String> exportCoursesJson(
    List<Course> courses, [
    String? targetPath,
  ]) async {
    final list = courses.map((c) => c.toMap()).toList();
    if (targetPath != null && targetPath.isNotEmpty) {
      final file = File(targetPath);
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(list));
      return file.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/course_export.json');
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(list));
    return file.path;
  }

  Future<String> exportCoursesIcs(
    List<Course> courses,
    DateTime? startDate, [
    String? targetPath,
  ]) async {
    if (startDate == null) {
      return '';
    }
    final ics = _generateIcs(courses, startDate);
    if (targetPath != null && targetPath.isNotEmpty) {
      final file = File(targetPath);
      await file.writeAsString(ics);
      return file.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/course_export.ics');
    await file.writeAsString(ics);
    return file.path;
  }

  Future<Uint8List> exportCoursesJsonBytes(List<Course> courses) async {
    final list = courses.map((c) => c.toMap()).toList();
    final str = JsonEncoder.withIndent('  ').convert(list);
    return Uint8List.fromList(utf8.encode(str));
  }

  Future<Uint8List> exportCoursesIcsBytes(
    List<Course> courses,
    DateTime? startDate,
  ) async {
    if (startDate == null) {
      return Uint8List(0);
    }
    final ics = _generateIcs(courses, startDate);
    return Uint8List.fromList(utf8.encode(ics));
  }

  Future<int> importToSystemCalendar(
    List<Course> courses,
    DateTime? startDate,
  ) async {
    if (startDate == null) {
      return 0;
    }
    return _calendarService.importCourses(courses, startDate);
  }

  Future<bool> shareCoursesIcs(
    List<Course> courses,
    DateTime? startDate,
  ) async {
    final bytes = await exportCoursesIcsBytes(courses, startDate);
    if (bytes.isEmpty) {
      return false;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/course_export.ics');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      text: '课程表 ICS 文件，可在 ICSx5 等日历中订阅',
      subject: 'CourseBlock 课表',
    );
    return true;
  }

  Future<CourseImportReport> importCoursesJson({
    required String path,
    required int? scheduleId,
  }) async {
    if (scheduleId == null) {
      return const CourseImportReport(
        sourceLabel: 'JSON',
        added: 0,
        failed: 1,
        failures: [
          CourseOperationFailure(label: '当前课表', reason: '请先创建或选择一个课表'),
        ],
      );
    }

    try {
      final file = File(path);
      final content = await file.readAsString();
      final decoded = json.decode(content);
      if (decoded is! List) {
        return const CourseImportReport(
          sourceLabel: 'JSON',
          added: 0,
          failed: 1,
          failures: [
            CourseOperationFailure(label: 'JSON 文件', reason: '文件内容不是课程列表'),
          ],
        );
      }

      int inserted = 0;
      final failures = <CourseOperationFailure>[];

      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        final label = _reportLabelFromJsonItem(item, i + 1);
        try {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('这一项不是课程对象');
          }
          final course = Course.fromMap(item);
          final newCourse = course.copyWith(scheduleId: scheduleId);
          await _databaseHelper.insertCourse(newCourse);
          inserted++;
        } catch (e) {
          failures.add(
            CourseOperationFailure(
              label: label,
              reason: _formatOperationError(e, fallback: '无法导入这条课程'),
            ),
          );
        }
      }

      return CourseImportReport(
        sourceLabel: 'JSON',
        added: inserted,
        failed: failures.length,
        notes: [if (failures.isNotEmpty) '其余课程已继续导入。'],
        failures: failures,
      );
    } catch (e) {
      return CourseImportReport(
        sourceLabel: 'JSON',
        added: 0,
        failed: 1,
        failures: [
          CourseOperationFailure(
            label: 'JSON 文件',
            reason: _formatOperationError(e, fallback: '无法读取这个文件'),
          ),
        ],
      );
    }
  }

  Future<CourseImportReport> importCoursesIcs({
    required String path,
    required int? scheduleId,
    required DateTime? startDate,
    required AppCourseColorPalette courseColorPalette,
  }) async {
    if (scheduleId == null || startDate == null) {
      return const CourseImportReport(
        sourceLabel: 'ICS',
        added: 0,
        failed: 1,
        failures: [
          CourseOperationFailure(label: '当前课表', reason: '请先创建或选择一个课表'),
        ],
      );
    }

    try {
      final file = File(path);
      final content = await file.readAsString();
      final parsed = _parseIcs(content, startDate, courseColorPalette);
      int inserted = 0;
      final failures = <CourseOperationFailure>[...parsed.failures];

      for (final course in parsed.courses) {
        try {
          final newCourse = course.copyWith(scheduleId: scheduleId);
          await _databaseHelper.insertCourse(newCourse);
          inserted++;
        } catch (e) {
          failures.add(
            CourseOperationFailure(
              label: course.courseName,
              reason: '写入失败：${_formatOperationError(e, fallback: '无法导入这条课程')}',
            ),
          );
        }
      }

      return CourseImportReport(
        sourceLabel: 'ICS',
        added: inserted,
        failed: failures.length,
        notes: [if (failures.isNotEmpty) '已跳过格式不完整或无法识别的日历事件。'],
        failures: failures,
      );
    } catch (e) {
      return CourseImportReport(
        sourceLabel: 'ICS',
        added: 0,
        failed: 1,
        failures: [
          CourseOperationFailure(
            label: 'ICS 文件',
            reason: _formatOperationError(e, fallback: '无法读取这个文件'),
          ),
        ],
      );
    }
  }

  _IcsParseResult _parseIcs(
    String content,
    DateTime startDate,
    AppCourseColorPalette courseColorPalette,
  ) {
    final events = content.split('BEGIN:VEVENT').skip(1);
    final list = <Course>[];
    final failures = <CourseOperationFailure>[];
    final normalizedStart = normalizeDate(startDate);
    var index = 0;
    for (final ev in events) {
      index++;

      String? readField(String name) {
        final reg = RegExp('$name[^:]*:(.+)');
        final m = reg.firstMatch(ev);
        return m?.group(1)?.trim();
      }

      final summary = readField('SUMMARY');
      final location = readField('LOCATION');
      final dtstart = readField('DTSTART');
      final dtend = readField('DTEND');
      final duration = readField('DURATION');
      final rrule = readField('RRULE');
      final label = summary?.trim().isNotEmpty == true
          ? summary!.trim()
          : '第 $index 条日历事件';
      if (summary == null || summary.trim().isEmpty) {
        failures.add(
          const CourseOperationFailure(label: '日历事件', reason: '缺少课程名称'),
        );
        continue;
      }
      if (dtstart == null || dtstart.trim().isEmpty) {
        failures.add(CourseOperationFailure(label: label, reason: '缺少开始时间'));
        continue;
      }

      final start = _parseIcsDateTime(dtstart);
      if (start == null) {
        failures.add(
          CourseOperationFailure(label: label, reason: '开始时间格式无法识别'),
        );
        continue;
      }

      DateTime? end;
      if (dtend != null) {
        end = _parseIcsDateTime(dtend);
        if (end == null) {
          failures.add(
            CourseOperationFailure(label: label, reason: '结束时间格式无法识别'),
          );
          continue;
        }
      }

      final diff = start.difference(normalizedStart).inDays;
      var week = (diff / 7).floor() + 1;
      if (week < 1) {
        week = 1;
      }
      final day = start.weekday;

      final startNode = resolveStartNode(start);
      var step = 1;
      if (end != null) {
        final endNode = resolveEndNode(end);
        step = (endNode - startNode + 1).clamp(1, kClassEndTimes.length);
      } else if (duration != null) {
        final match = RegExp(r'PT(\d+)M').firstMatch(duration);
        if (match != null) {
          final mins = int.tryParse(match.group(1)!) ?? 0;
          step = (mins / 45).ceil();
        }
      }

      var endWeek = week;
      if (rrule != null) {
        final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
        if (countMatch != null) {
          final cnt = int.tryParse(countMatch.group(1)!) ?? 1;
          endWeek = week + cnt - 1;
        }
      }

      list.add(
        Course(
          scheduleId: null,
          courseId: '',
          courseName: summary,
          teacher: '',
          classRoom: location ?? '',
          startWeek: week,
          endWeek: endWeek,
          dayOfWeek: day,
          startNode: startNode,
          step: step,
          isOddWeek: false,
          isEvenWeek: false,
          weekCode: null,
          color: courseColorPalette.autoColorToken(
            buildCourseColorSeed(summary, ''),
          ),
        ),
      );
    }
    return _IcsParseResult(courses: list, failures: failures);
  }

  String _generateIcs(List<Course> courses, DateTime startDate) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//CourseBlock//EN');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');

    final normalizedStart = normalizeDate(startDate);

    for (final course in courses) {
      final baseDate = normalizedStart.add(
        Duration(days: (course.startWeek - 1) * 7 + (course.dayOfWeek - 1)),
      );

      final start = classStartDateTime(baseDate, course.startNode);
      final end = classEndDateTime(baseDate, course.startNode, course.step);

      var interval = 1;
      var count = course.endWeek - course.startWeek + 1;
      if (course.isOddWeek ^ course.isEvenWeek) {
        interval = 2;
        count = ((course.endWeek - course.startWeek) / 2).floor() + 1;
      }

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${course.courseName}');
      buffer.writeln('LOCATION:${course.classRoom}');
      buffer.writeln('DTSTART;TZID=Asia/Shanghai:${_formatIcsDateTime(start)}');
      buffer.writeln('DTEND;TZID=Asia/Shanghai:${_formatIcsDateTime(end)}');
      buffer.writeln('RRULE:FREQ=WEEKLY;INTERVAL=$interval;COUNT=$count');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  DateTime? _parseIcsDateTime(String value) {
    try {
      if (value.endsWith('Z')) {
        return DateFormat("yyyyMMdd'T'HHmmss'Z'").parseUtc(value).toLocal();
      }
      return DateFormat("yyyyMMdd'T'HHmmss").parseStrict(value);
    } catch (_) {
      try {
        return DateFormat('yyyyMMdd').parseStrict(value);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatIcsDateTime(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss").format(dt);
  }

  String _formatOperationError(Object error, {required String fallback}) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
    return raw.isEmpty ? fallback : raw;
  }

  String _reportLabelFromJsonItem(dynamic item, int index) {
    if (item is Map) {
      final courseName =
          item['courseName']?.toString() ??
          item['kcmc']?.toString() ??
          item['courseId']?.toString();
      if (courseName != null && courseName.trim().isNotEmpty) {
        return courseName.trim();
      }
    }
    return '第 $index 条';
  }
}

class _IcsParseResult {
  const _IcsParseResult({required this.courses, required this.failures});

  final List<Course> courses;
  final List<CourseOperationFailure> failures;
}
