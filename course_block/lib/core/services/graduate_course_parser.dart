import '../models/course.dart';
import '../models/course_operation_report.dart';
import '../theme/app_theme.dart';
import '../utils/week_utils.dart';

class GraduateCourseParseResult {
  const GraduateCourseParseResult({
    required this.courses,
    required this.failures,
  });

  final List<Course> courses;
  final List<CourseOperationFailure> failures;
}

class GraduateCourseParser {
  const GraduateCourseParser();

  String convertYearTerm(String year, String term) {
    if (term == '2') {
      final next = int.tryParse(year) ?? 0;
      return '${next + 1}02';
    }
    if (term == '3') {
      final next = int.tryParse(year) ?? 0;
      return '${next + 1}06';
    }
    return '${year}09';
  }

  GraduateCourseParseResult parseRows(
    List<Map<String, dynamic>> rows, {
    required AppCourseColorPalette courseColorPalette,
  }) {
    if (rows.isEmpty) {
      return const GraduateCourseParseResult(courses: [], failures: []);
    }

    final accumulators = <String, _GraduateCourseAccumulator>{};
    final failures = <CourseOperationFailure>[];
    final usesZeroBasedSections = rows.any((row) {
      final source = _stringOf(row['PKSJDD']) ?? _stringOf(row['PKSJ']) ?? '';
      return RegExp(r'\[\s*0(?:-\d+)?节\]').hasMatch(source);
    });

    for (final row in rows) {
      final courseName =
          _stringOf(row['KCMC']) ?? _stringOf(row['KCMCYW']) ?? '未知课程';
      final teacher =
          _stringOf(row['RKJS']) ?? _stringOf(row['JSXM']) ?? '未知教师';
      final classId =
          _stringOf(row['BJDM']) ??
          _stringOf(row['BJMC']) ??
          _stringOf(row['KCDM']) ??
          courseName;
      final courseId =
          _stringOf(row['KCDM']) ?? _stringOf(row['BJDM']) ?? classId;
      final defaultRoom =
          _stringOf(row['PKDD']) ??
          _stringOf(row['PKDD_DISPLAY']) ??
          _stringOf(row['XQDM_DISPLAY']);
      final segments = _extractScheduleSegments(
        row,
        usesZeroBasedSections: usesZeroBasedSections,
      );

      if (segments.isEmpty) {
        final scheduleText =
            _stringOf(row['PKSJDD']) ?? _stringOf(row['PKSJ']) ?? '未提供排课文本';
        failures.add(
          CourseOperationFailure(
            label: courseName,
            reason: '未识别排课：${_shortenText(scheduleText)}',
          ),
        );
        continue;
      }

      for (final segment in segments) {
        final room = segment.location ?? defaultRoom ?? '未知地点';
        final key =
            '$classId|$courseName|$teacher|$room|${segment.dayOfWeek}|${segment.startNode}|${segment.endNode}';
        final accumulator =
            accumulators[key] ??
            _GraduateCourseAccumulator(
              courseId: courseId,
              courseName: courseName,
              teacher: teacher,
              classRoom: room,
              dayOfWeek: segment.dayOfWeek,
              startNode: segment.startNode,
              endNode: segment.endNode,
            );
        accumulator.addWeekCode(segment.weekCode);
        accumulators[key] = accumulator;
      }
    }

    return GraduateCourseParseResult(
      courses: accumulators.values
          .map((item) => item.toCourse(courseColorPalette))
          .whereType<Course>()
          .toList(),
      failures: failures,
    );
  }

  List<_GraduateScheduleSegment> _extractScheduleSegments(
    Map<String, dynamic> row, {
    required bool usesZeroBasedSections,
  }) {
    final source = _normalizeScheduleSource(
      _stringOf(row['PKSJDD']) ?? _stringOf(row['PKSJ']),
    );
    if (source == null || source.isEmpty) {
      return const [];
    }

    final matches = RegExp(
      r'(?:([0-9,\-~～至单双\(\)（） ]+周(?:\((?:单|双)\)|（(?:单|双)）)?)\s*)?星期([一二三四五六日天])\[(\d+)(?:-(\d+))?节\]',
    ).allMatches(source).toList();
    if (matches.isEmpty) {
      return const [];
    }

    final segments = <_GraduateScheduleSegment>[];
    String? lastWeeks;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final weeksText = match.group(1)?.trim();
      if (weeksText != null && weeksText.isNotEmpty) {
        lastWeeks = weeksText;
      }

      final effectiveWeeks = (weeksText != null && weeksText.isNotEmpty)
          ? weeksText
          : lastWeeks;
      if (effectiveWeeks == null || effectiveWeeks.isEmpty) {
        continue;
      }

      final weekCode = _buildWeekCode(effectiveWeeks);
      if (weekCode == null) {
        continue;
      }

      final dayOfWeek = _dayOfWeek(match.group(2));
      final rawStart = int.tryParse(match.group(3) ?? '');
      final rawEnd = int.tryParse(match.group(4) ?? match.group(3) ?? '');
      final nodeRange = _nodeRange(
        rawStart,
        rawEnd,
        usesZeroBasedSections: usesZeroBasedSections,
      );
      if (dayOfWeek == null || nodeRange == null) {
        continue;
      }

      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : source.length;
      final room = _normalizeLocation(source.substring(match.end, nextStart));

      segments.add(
        _GraduateScheduleSegment(
          weekCode: weekCode,
          dayOfWeek: dayOfWeek,
          startNode: nodeRange.$1,
          endNode: nodeRange.$2,
          location: room,
        ),
      );
    }

    return segments;
  }

  String? _buildWeekCode(String weekText) {
    final normalized = _normalizeWeekText(weekText);
    if (normalized.isEmpty || !RegExp(r'\d').hasMatch(normalized)) {
      return null;
    }

    final parsed = WeekUtils.parseWeekCode(normalized);
    return parsed.contains('1') ? parsed : null;
  }

  String _normalizeWeekText(String raw) {
    var text = raw
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll(';', ',')
        .replaceAll('；', ',')
        .replaceAll('至', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('～', '-')
        .replaceAll('~', '-')
        .replaceAll('单周', '(单)')
        .replaceAll('双周', '(双)')
        .replaceAll(' odd weeks', '(单)')
        .replaceAll(' even weeks', '(双)')
        .replaceAll('Odd weeks', '(单)')
        .replaceAll('Even weeks', '(双)')
        .replaceAll('周(', '(')
        .replaceAll('周次', '')
        .replaceAll('第', '')
        .replaceAll(' ', '');

    if (RegExp(r'\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b').hasMatch(text)) {
      return '';
    }

    final weekMatches = WeekUtils.extractWeekExpressions(text);
    if (weekMatches.isNotEmpty) {
      return weekMatches.join(',');
    }

    return text;
  }

  String? _normalizeScheduleSource(String? value) {
    final text = _stringOf(value);
    if (text == null) {
      return null;
    }

    return text
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('<br/>', ';')
        .replaceAll('<br />', ';')
        .replaceAll('<br>', ';')
        .replaceAll('\r\n', ';')
        .replaceAll('\n', ';')
        .replaceAll('，', ',')
        .replaceAll('；', ';')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? _dayOfWeek(String? value) {
    switch (value) {
      case '一':
        return 1;
      case '二':
        return 2;
      case '三':
        return 3;
      case '四':
        return 4;
      case '五':
        return 5;
      case '六':
        return 6;
      case '日':
      case '天':
        return 7;
      default:
        return null;
    }
  }

  (int, int)? _nodeRange(
    int? rawStart,
    int? rawEnd, {
    required bool usesZeroBasedSections,
  }) {
    if (rawStart == null || rawEnd == null) {
      return null;
    }

    final zeroBased = usesZeroBasedSections || rawStart == 0 || rawEnd == 0;
    var start = zeroBased ? rawStart + 1 : rawStart;
    var end = zeroBased ? rawEnd + 1 : rawEnd;

    start = start.clamp(1, 14);
    end = end.clamp(start, 14);
    return (start, end);
  }

  String? _normalizeLocation(String raw) {
    final trimmed = raw
        .replaceAll(RegExp(r'^[,;、，；\s]+'), '')
        .replaceAll(RegExp(r'[,;、，；\s]+$'), '')
        .trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _shortenText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 36) {
      return normalized;
    }
    return '${normalized.substring(0, 36)}...';
  }

  String? _stringOf(dynamic value) {
    final text = value?.toString();
    if (text == null) {
      return null;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == 'null') {
      return null;
    }
    return trimmed;
  }
}

class _GraduateScheduleSegment {
  const _GraduateScheduleSegment({
    required this.weekCode,
    required this.dayOfWeek,
    required this.startNode,
    required this.endNode,
    required this.location,
  });

  final String weekCode;
  final int dayOfWeek;
  final int startNode;
  final int endNode;
  final String? location;
}

class _GraduateCourseAccumulator {
  _GraduateCourseAccumulator({
    required this.courseId,
    required this.courseName,
    required this.teacher,
    required this.classRoom,
    required this.dayOfWeek,
    required this.startNode,
    required this.endNode,
  }) : _weekFlags = List<bool>.filled(WeekUtils.maxWeeks, false);

  final String courseId;
  final String courseName;
  final String teacher;
  final String classRoom;
  final int dayOfWeek;
  final int startNode;
  final int endNode;
  final List<bool> _weekFlags;

  void addWeekCode(String weekCode) {
    final normalized = weekCode.padRight(WeekUtils.maxWeeks, '0');
    for (var i = 0; i < WeekUtils.maxWeeks; i++) {
      if (normalized[i] == '1') {
        _weekFlags[i] = true;
      }
    }
  }

  Course? toCourse(AppCourseColorPalette courseColorPalette) {
    final weekCode = _weekFlags.map((flag) => flag ? '1' : '0').join();
    final firstWeek = weekCode.indexOf('1');
    final lastWeek = weekCode.lastIndexOf('1');
    if (firstWeek == -1 || lastWeek == -1) {
      return null;
    }

    var hasOdd = false;
    var hasEven = false;
    for (var i = 0; i < _weekFlags.length; i++) {
      if (_weekFlags[i]) {
        if ((i + 1).isOdd) {
          hasOdd = true;
        } else {
          hasEven = true;
        }
      }
    }

    return Course(
      courseId: courseId,
      courseName: courseName,
      teacher: teacher,
      classRoom: classRoom,
      startWeek: firstWeek + 1,
      endWeek: lastWeek + 1,
      dayOfWeek: dayOfWeek,
      startNode: startNode,
      step: endNode - startNode + 1,
      isOddWeek: hasOdd && !hasEven,
      isEvenWeek: hasEven && !hasOdd,
      weekCode: weekCode,
      color: courseColorPalette.autoColorToken(
        buildCourseColorSeed(courseName, teacher),
      ),
    );
  }
}
