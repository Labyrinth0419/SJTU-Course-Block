import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../models/course_operation_report.dart';
import '../theme/app_theme.dart';
import '../utils/week_utils.dart';
import 'graduate_course_parser.dart';
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

class GraduateScheduleParsingPendingException extends CourseSyncException {
  GraduateScheduleParsingPendingException({int? courseCount})
    : super(
        courseCount == null
            ? '已从研究生教务获取到课表数据，但暂时没能识别上课时间。请稍后重试，或把该学期的排课文本反馈给开发者继续适配。'
            : '已从研究生教务获取到 $courseCount 条课程数据，但暂时没能识别上课时间。请稍后重试，或把该学期的排课文本反馈给开发者继续适配。',
      );
}

class CourseFetchResult {
  const CourseFetchResult({
    required this.sourceSystem,
    required this.courses,
    this.failures = const [],
    this.notes = const [],
  });

  final AcademicLoginSystem sourceSystem;
  final List<Course> courses;
  final List<CourseOperationFailure> failures;
  final List<String> notes;

  String get sourceLabel => sourceSystem.label;
}

class CourseService {
  static const String _ugCourseUrl =
      'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXsKb.html';
  static const String _gradCourseUrl =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';
  static const String _gradReferer =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/*default/index.do?THEME=indigo&EMAP_LANG=zh#/xskcb';

  final Dio _dio = Dio();
  final GraduateCourseParser _graduateCourseParser =
      const GraduateCourseParser();

  Future<CourseFetchResult> fetchUndergraduateCourses(
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
        return const CourseFetchResult(
          sourceSystem: AcademicLoginSystem.undergraduate,
          courses: [],
        );
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
          return CourseFetchResult(
            sourceSystem: AcademicLoginSystem.undergraduate,
            courses: kbList
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => _parseUndergraduateCourse(item, courseColorPalette),
                )
                .toList(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching undergraduate courses: $e');
    }
    return const CourseFetchResult(
      sourceSystem: AcademicLoginSystem.undergraduate,
      courses: [],
    );
  }

  Future<CourseFetchResult> fetchGraduateCourses(
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

    final requestedXnxqdm = _graduateCourseParser.convertYearTerm(year, term);
    final response = await _dio.post<dynamic>(
      '$_gradCourseUrl?_=${DateTime.now().millisecondsSinceEpoch}',
      data: {
        'XNXQDM': requestedXnxqdm,
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
    final parsedResult = _graduateCourseParser.parseRows(
      rows,
      courseColorPalette: courseColorPalette,
    );
    if (parsedResult.courses.isNotEmpty || rows.isEmpty) {
      final notes = <String>[
        if (parsedResult.failures.isNotEmpty)
          '已跳过 ${parsedResult.failures.length} 条暂未识别的研究生排课。',
      ];
      return CourseFetchResult(
        sourceSystem: AcademicLoginSystem.graduate,
        courses: parsedResult.courses,
        failures: parsedResult.failures,
        notes: notes,
      );
    }

    throw GraduateScheduleParsingPendingException(courseCount: rows.length);
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
      courseId: _stringOf(json['kch']) ?? _stringOf(json['kch_id']) ?? '',
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
