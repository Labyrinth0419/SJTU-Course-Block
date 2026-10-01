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
import '../utils/course_occurrences.dart';
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
    final events = content
        .replaceAll(RegExp(r'\r?\n[ \t]'), '')
        .split('BEGIN:VEVENT')
        .skip(1);
    final courses = <Course>[];
    final failures = <CourseOperationFailure>[];
    var index = 0;
    for (final ev in events) {
      index++;
      final eventEnd = ev.indexOf('END:VEVENT');
      if (eventEnd < 0) {
        failures.add(
          CourseOperationFailure(label: '第 $index 条日历事件', reason: '缺少事件结束标记'),
        );
        continue;
      }
      final lines = ev.substring(0, eventEnd).split(RegExp(r'\r?\n'));
      List<String> fields(String name) => [
        for (final line in lines)
          if (line.startsWith('$name:') || line.startsWith('$name;'))
            line.substring(line.indexOf(':') + 1).trim(),
      ];
      String? field(String name) => fields(name).firstOrNull;

      final summary = field('SUMMARY');
      final label = summary?.trim().isNotEmpty == true
          ? _unescapeIcsText(summary!)
          : '第 $index 条日历事件';
      if (summary == null || summary.trim().isEmpty) {
        failures.add(
          const CourseOperationFailure(label: '日历事件', reason: '缺少课程名称'),
        );
        continue;
      }
      final dtstart = field('DTSTART');
      if (dtstart == null || dtstart.isEmpty) {
        failures.add(CourseOperationFailure(label: label, reason: '缺少开始时间'));
        continue;
      }
      final rrules = fields('RRULE');
      final rdates = fields('RDATE');
      if (rrules.length > 1 ||
          fields('DTSTART').length > 1 ||
          fields('DTEND').length > 1 ||
          lines.any((line) => line.startsWith('RRULE;')) ||
          (rrules.isNotEmpty && rdates.isNotEmpty) ||
          ((rrules.isNotEmpty || rdates.isNotEmpty) &&
              (dtstart.length == 8 || field('DTEND')?.length == 8)) ||
          fields('EXDATE').isNotEmpty ||
          fields('EXRULE').isNotEmpty ||
          fields('RECURRENCE-ID').isNotEmpty ||
          ['DTSTART', 'DTEND', 'RDATE'].any(
            (name) => lines.any(
              (line) =>
                  (line.startsWith('$name;') &&
                  line.contains('TZID=') &&
                  !line.contains('TZID=Asia/Shanghai:') &&
                  !line.contains('TZID=Asia/Shanghai;')),
            ),
          )) {
        failures.add(
          CourseOperationFailure(label: label, reason: '不支持此日历重复规则或时区'),
        );
        continue;
      }

      final start = _parseIcsDateTime(dtstart);
      if (start == null) {
        failures.add(
          CourseOperationFailure(label: label, reason: '开始时间格式无法识别'),
        );
        continue;
      }
      final dtend = field('DTEND');
      final end = dtend == null ? null : _parseIcsDateTime(dtend);
      if (dtend != null && end == null) {
        failures.add(
          CourseOperationFailure(label: label, reason: '结束时间格式无法识别'),
        );
        continue;
      }
      final week = courseWeekForDate(startDate, start);
      if (week < 1) {
        failures.add(
          CourseOperationFailure(label: label, reason: '课程日期早于学期起始周'),
        );
        continue;
      }
      final startNode = resolveStartNode(start);
      var step = 1;
      if (end != null) {
        final endNode = resolveEndNode(end);
        step = (endNode - startNode + 1).clamp(1, kClassEndTimes.length);
      } else if (field('DURATION') != null) {
        final match = RegExp(r'^PT(\d+)M$').firstMatch(field('DURATION')!);
        if (match != null) {
          final mins = int.tryParse(match.group(1)!) ?? 0;
          step = (mins / 45).ceil();
        }
      }

      final weeks = <int>[week];
      if (rrules.isNotEmpty) {
        final parts = rrules.single.split(';');
        final rule = <String, String>{};
        for (final part in parts) {
          final pair = part.split('=');
          if (pair.length == 2) rule[pair[0]] = pair[1];
        }
        final count = int.tryParse(rule['COUNT'] ?? '');
        final interval = int.tryParse(rule['INTERVAL'] ?? '1');
        if (parts.length != rule.length ||
            rule.keys.any(
              (key) => !{'FREQ', 'COUNT', 'INTERVAL'}.contains(key),
            ) ||
            rule['FREQ'] != 'WEEKLY' ||
            count == null ||
            count < 1 ||
            count > 1000 ||
            interval == null ||
            interval < 1 ||
            interval > 1000 ||
            week + (count - 1) * interval > 1000) {
          failures.add(
            CourseOperationFailure(label: label, reason: '不支持此日历重复规则'),
          );
          continue;
        }
        for (var i = 1; i < count; i++) {
          weeks.add(week + i * interval);
        }
      } else if (rdates.isNotEmpty) {
        var valid = true;
        for (final raw in rdates.expand((entry) => entry.split(','))) {
          final date = _parseIcsDateTime(raw);
          if (date == null ||
              date.weekday != start.weekday ||
              date.hour != start.hour ||
              date.minute != start.minute ||
              date.second != start.second ||
              courseWeekForDate(startDate, date) < 1 ||
              courseWeekForDate(startDate, date) > 1000) {
            valid = false;
            break;
          }
          weeks.add(courseWeekForDate(startDate, date));
        }
        if (!valid || weeks.toSet().length != weeks.length) {
          failures.add(
            CourseOperationFailure(label: label, reason: '不支持此日历附加日期'),
          );
          continue;
        }
        weeks.sort();
        if (weeks.first != week) {
          failures.add(
            CourseOperationFailure(label: label, reason: '附加日期早于开始日期'),
          );
          continue;
        }
      }

      final interval = courseWeekInterval(weeks);
      final isOddWeek = interval == 2 && weeks.first.isOdd;
      final isEvenWeek = interval == 2 && weeks.first.isEven;
      final selectedWeeks = weeks.toSet();
      final weekCode = weeks.length > 1 && interval != 1 && interval != 2
          ? [
              for (var w = 1; w <= weeks.last; w++)
                selectedWeeks.contains(w) ? '1' : '0',
            ].join()
          : null;
      final name = _unescapeIcsText(summary);
      courses.add(
        Course(
          scheduleId: null,
          courseId: '',
          courseName: name,
          teacher: '',
          classRoom: _unescapeIcsText(field('LOCATION') ?? ''),
          startWeek: weeks.first,
          endWeek: weeks.last,
          dayOfWeek: start.weekday,
          startNode: startNode,
          step: step,
          isOddWeek: isOddWeek,
          isEvenWeek: isEvenWeek,
          weekCode: weekCode,
          color: courseColorPalette.autoColorToken(
            buildCourseColorSeed(name, ''),
          ),
        ),
      );
    }
    return _IcsParseResult(courses: courses, failures: failures);
  }

  String _generateIcs(List<Course> courses, DateTime startDate) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//CourseBlock//EN');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');

    for (final course in courses) {
      final weeks = courseOccurrenceWeeks(course);
      if (weeks.isEmpty) continue;
      final baseDate = courseDateForWeek(
        startDate,
        weeks.first,
        course.dayOfWeek,
      );
      final start = classStartDateTime(baseDate, course.startNode);
      final end = classEndDateTime(baseDate, course.startNode, course.step);
      final interval = courseWeekInterval(weeks);

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${_escapeIcsText(course.courseName)}');
      buffer.writeln('LOCATION:${_escapeIcsText(course.classRoom)}');
      buffer.writeln('DTSTART;TZID=Asia/Shanghai:${_formatIcsDateTime(start)}');
      buffer.writeln('DTEND;TZID=Asia/Shanghai:${_formatIcsDateTime(end)}');
      if (interval != null) {
        buffer.writeln(
          'RRULE:FREQ=WEEKLY;INTERVAL=$interval;COUNT=${weeks.length}',
        );
      } else if (weeks.length > 1) {
        final extraDates = [
          for (final week in weeks.skip(1))
            _formatIcsDateTime(
              classStartDateTime(
                courseDateForWeek(startDate, week, course.dayOfWeek),
                course.startNode,
              ),
            ),
        ];
        buffer.writeln('RDATE;TZID=Asia/Shanghai:${extraDates.join(',')}');
      }
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _escapeIcsText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');

  String _unescapeIcsText(String value) => value.replaceAllMapped(
    RegExp(r'\\([\\nN;,])'),
    (match) => match.group(1)!.toLowerCase() == 'n' ? '\n' : match.group(1)!,
  );

  DateTime? _parseIcsDateTime(String value) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
    ).firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4] ?? '0');
    final minute = int.parse(match[5] ?? '0');
    final second = int.parse(match[6] ?? '0');
    if (year < 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    final utc = match[7] != null;
    final date = utc
        ? DateTime.utc(year, month, day, hour, minute, second)
        : DateTime(year, month, day, hour, minute, second);
    if (date.year != year ||
        date.month != month ||
        date.day != day ||
        date.hour != hour ||
        date.minute != minute ||
        date.second != second) {
      return null;
    }
    return utc ? date.toLocal() : date;
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
