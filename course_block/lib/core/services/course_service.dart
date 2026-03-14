import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../theme/app_theme.dart';
import '../utils/week_utils.dart';
import 'login_session.dart';

class CourseSyncException implements Exception {
  const CourseSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AcademicLoginRequiredException extends CourseSyncException {
  const AcademicLoginRequiredException() : super('请先在应用设置中登录教务系统');
}

class GraduateLoginRequiredException extends CourseSyncException {
  const GraduateLoginRequiredException() : super('研究生登录已失效，请重新登录研究生教务系统');
}

class GraduateCurrentTermOnlyException extends CourseSyncException {
  GraduateCurrentTermOnlyException({required this.currentTermLabel})
    : super('研究生目前仅支持同步当前学期（$currentTermLabel）');

  final String currentTermLabel;
}

class GraduateScheduleParsingPendingException extends CourseSyncException {
  const GraduateScheduleParsingPendingException()
    : super('研究生课表已抓取到，但当前排课文本仍有未适配格式');
}

class CourseService {
  static const String _ugCourseUrl =
      'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXsKb.html';
  static const String _gradPublicInfoUrl =
      'https://yjsxk.sjtu.edu.cn/yjsxkapp/sys/xsxkapp/xsxkHome/loadPublicInfo_index.do';
  static const String _gradCourseUrl =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';
  static const String _gradReferer =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/*default/index.do?THEME=indigo&EMAP_LANG=zh#/xskcb';

  final Dio _dio = Dio();

  Future<List<Course>> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async {
    var xqm = '3';
    if (term == '2') {
      xqm = '12';
    } else if (term == '3') {
      xqm = '16';
    }

    try {
      final cookies = await LoginSessionStorage.loadCookies(
        AcademicLoginSystem.undergraduate,
      );
      if (cookies.trim().isEmpty) {
        return [];
      }

      _dio.options.headers['Cookie'] = cookies;
      _dio.options.headers['User-Agent'] =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 '
          'Mobile/15E148 Safari/604.1 Edg/89.0.4389.72';
      _dio.options.headers['Referer'] =
          'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';
      _dio.options.contentType = Headers.formUrlEncodedContentType;

      final response = await _dio.post<dynamic>(
        _ugCourseUrl,
        data: {'xnm': year, 'xqm': xqm},
      );

      if (response.statusCode == 200) {
        final json = _decodeJsonMap(response.data);
        final kbList = json?['kbList'];
        if (kbList is List) {
          return kbList
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => _parseUndergraduateCourse(item, courseColorPalette),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching undergraduate courses: $e');
    }
    return [];
  }

  Future<List<Course>> fetchGraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async {
    final cookies = await LoginSessionStorage.loadCookies(
      AcademicLoginSystem.graduate,
    );
    if (cookies.trim().isEmpty) {
      throw const GraduateLoginRequiredException();
    }

    final requestedXnxqdm = _convertGradYearTerm(year, term);
    final currentTerm = await _loadGraduateCurrentTerm();
    if (requestedXnxqdm != currentTerm.code) {
      throw GraduateCurrentTermOnlyException(
        currentTermLabel: currentTerm.label,
      );
    }

    final response = await _dio.post<dynamic>(
      '$_gradCourseUrl?_=${DateTime.now().millisecondsSinceEpoch}',
      data: {
        'XNXQDM': currentTerm.code,
        'XH': '',
        'pageNumber': '1',
        'pageSize': '200',
      },
      options: Options(
        headers: {
          'Cookie': cookies,
          'Referer': _gradReferer,
          'Origin': 'https://yjs.sjtu.edu.cn',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        followRedirects: false,
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200) {
      throw const GraduateLoginRequiredException();
    }

    final json = _decodeJsonMap(response.data);
    if (json == null || json['code']?.toString() != '0') {
      throw const GraduateLoginRequiredException();
    }

    final datas = json['datas'];
    if (datas is! Map<String, dynamic>) {
      throw const GraduateLoginRequiredException();
    }

    final result = datas['xsjxrwcx'];
    if (result is! Map<String, dynamic>) {
      throw const GraduateLoginRequiredException();
    }

    final rows = _normalizeList(result['rows']);
    final parsedCourses = _parseGraduateCourses(rows, courseColorPalette);
    if (parsedCourses.isNotEmpty || rows.isEmpty) {
      return parsedCourses;
    }

    throw const GraduateScheduleParsingPendingException();
  }

  Future<_GraduateCurrentTerm> _loadGraduateCurrentTerm() async {
    final response = await _dio.get<dynamic>(
      _gradPublicInfoUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final json = _decodeJsonMap(response.data);
    final lcxx = json?['lcxx'];
    if (lcxx is! Map<String, dynamic>) {
      throw const GraduateScheduleParsingPendingException();
    }

    final code = lcxx['XNXQDM']?.toString();
    if (code == null || code.isEmpty) {
      throw const GraduateScheduleParsingPendingException();
    }

    final label = lcxx['XNXQMC']?.toString();
    return _GraduateCurrentTerm(
      code: code,
      label: label == null || label.trim().isEmpty ? code : label.trim(),
    );
  }

  String _convertGradYearTerm(String year, String term) {
    if (term == '2') {
      final next = int.tryParse(year) ?? 0;
      return '${next + 1}02';
    }
    if (term == '3') {
      final next = int.tryParse(year) ?? 0;
      return '${next + 1}03';
    }
    return '${year}09';
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    return value.whereType<Map<String, dynamic>>().toList();
  }

  Course _parseUndergraduateCourse(
    Map<String, dynamic> json,
    AppCourseColorPalette courseColorPalette,
  ) {
    final startStep = WeekUtils.getStartAndStep(json['jcs'] as String? ?? '');
    final weekCode = WeekUtils.parseWeekCode(json['zcd'] as String? ?? '');

    var startWeek = 1;
    var endWeek = 16;
    var isOdd = false;
    var isEven = false;

    if (weekCode.contains('1')) {
      startWeek = weekCode.indexOf('1') + 1;
      endWeek = weekCode.lastIndexOf('1') + 1;

      var hasOdd = false;
      var hasEven = false;
      for (var i = 0; i < weekCode.length; i++) {
        if (weekCode[i] == '1') {
          if ((i + 1).isOdd) {
            hasOdd = true;
          } else {
            hasEven = true;
          }
        }
      }
      if (hasOdd && !hasEven) {
        isOdd = true;
      }
      if (hasEven && !hasOdd) {
        isEven = true;
      }
    }

    return Course(
      courseId: json['kch_id'] as String? ?? '',
      courseName: json['kcmc'] as String? ?? '未知课程',
      teacher: json['xm'] as String? ?? '未知教师',
      classRoom: json['cdmc'] as String? ?? '未知地点',
      startWeek: startWeek,
      endWeek: endWeek,
      dayOfWeek: json['xqj'] is int
          ? json['xqj']
          : int.tryParse(json['xqj']?.toString() ?? '1') ?? 1,
      startNode: startStep[0],
      step: startStep[1],
      isOddWeek: isOdd,
      isEvenWeek: isEven,
      weekCode: weekCode,
      color: courseColorPalette.autoColorToken(
        buildCourseColorSeed(
          json['kcmc']?.toString() ?? '',
          json['xm']?.toString() ?? '',
        ),
      ),
      isVirtual: (json['xkbz'] as String? ?? '').contains('虚拟'),
    );
  }

  List<Course> _parseGraduateCourses(
    List<Map<String, dynamic>> rows,
    AppCourseColorPalette courseColorPalette,
  ) {
    if (rows.isEmpty) {
      return const [];
    }

    final accumulators = <String, _GraduateCourseAccumulator>{};
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

      for (final segment in _extractGraduateScheduleSegments(
        row,
        usesZeroBasedSections: usesZeroBasedSections,
      )) {
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

    return accumulators.values
        .map((item) => item.toCourse(courseColorPalette))
        .whereType<Course>()
        .toList();
  }

  List<_GraduateScheduleSegment> _extractGraduateScheduleSegments(
    Map<String, dynamic> row, {
    required bool usesZeroBasedSections,
  }) {
    final source = _normalizeGraduateScheduleSource(
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

      final weekCode = _buildGraduateWeekCode(effectiveWeeks);
      if (weekCode == null) {
        continue;
      }

      final dayOfWeek = _graduateDayOfWeek(match.group(2));
      final rawStart = int.tryParse(match.group(3) ?? '');
      final rawEnd = int.tryParse(match.group(4) ?? match.group(3) ?? '');
      final nodeRange = _graduateNodeRange(
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
      final room = _normalizeGraduateLocation(
        source.substring(match.end, nextStart),
      );

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

  String? _buildGraduateWeekCode(String weekText) {
    final normalized = _normalizeGraduateWeekText(weekText);
    if (normalized.isEmpty || !RegExp(r'\d').hasMatch(normalized)) {
      return null;
    }

    final parsed = WeekUtils.parseWeekCode(normalized);
    return parsed.contains('1') ? parsed : null;
  }

  String _normalizeGraduateWeekText(String raw) {
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

    final weekMatches = RegExp(
      r'((?:[1-9]|1\d|2[0-4])(?:-(?:[1-9]|1\d|2[0-4]))?(?:\((?:单|双)\))?)',
    ).allMatches(text).map((match) => match.group(1)!).toList();
    if (weekMatches.isNotEmpty) {
      return weekMatches.join(',');
    }

    return text;
  }

  String? _normalizeGraduateScheduleSource(String? value) {
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

  int? _graduateDayOfWeek(String? value) {
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

  (int, int)? _graduateNodeRange(
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

  String? _normalizeGraduateLocation(String raw) {
    final trimmed = raw
        .replaceAll(RegExp(r'^[,;、，；\s]+'), '')
        .replaceAll(RegExp(r'[,;、，；\s]+$'), '')
        .trim();
    return trimmed.isEmpty ? null : trimmed;
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

class _GraduateCurrentTerm {
  const _GraduateCurrentTerm({required this.code, required this.label});

  final String code;
  final String label;
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
  }) : _weekFlags = List<bool>.filled(WeekUtils.MAX_WEEKS, false);

  final String courseId;
  final String courseName;
  final String teacher;
  final String classRoom;
  final int dayOfWeek;
  final int startNode;
  final int endNode;
  final List<bool> _weekFlags;

  void addWeekCode(String weekCode) {
    final normalized = weekCode.padRight(WeekUtils.MAX_WEEKS, '0');
    for (var i = 0; i < WeekUtils.MAX_WEEKS; i++) {
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
