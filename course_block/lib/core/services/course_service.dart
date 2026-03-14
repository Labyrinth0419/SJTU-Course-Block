import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../theme/app_theme.dart';
import '../utils/week_utils.dart';

class CourseService {
  static const String UG_COURSE_URL =
      'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXsKb.html';
  static const String GRAD_COURSE_URL =
      'http://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xspkjgcx.do';

  final Dio _dio = Dio();

  Future<List<Course>> fetchUndergraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async {
    String xqm = '3';
    if (term == '2') {
      xqm = '12';
    } else if (term == '3')
      xqm = '16';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getString('cookies') ?? '';

      _dio.options.headers['Cookie'] = cookies;
      _dio.options.headers['User-Agent'] =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/89.0.4389.72';
      _dio.options.headers['Referer'] =
          'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';
      _dio.options.contentType = Headers.formUrlEncodedContentType;

      final response = await _dio.post(
        UG_COURSE_URL,
        data: {'xnm': year, 'xqm': xqm},
      );

      if (response.statusCode == 200) {
        final data = response.data; // automatic json decoding by Dio usually
        final Map<String, dynamic> json = (data is String)
            ? jsonDecode(data)
            : data;

        if (json.containsKey('kbList')) {
          final List<dynamic> kbList = json['kbList'];
          return kbList
              .map(
                (item) => _parseUndergraduateCourse(item, courseColorPalette),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
    return [];
  }

  Future<List<Course>> fetchGraduateCourses(
    String year,
    String term, {
    required AppCourseColorPalette courseColorPalette,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getString('cookies') ?? '';

      _dio.options.headers['Cookie'] = cookies;
      _dio.options.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      _dio.options.headers['Referer'] =
          'http://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
      _dio.options.contentType = Headers.formUrlEncodedContentType;

      final xnxqdm = _convertGradYearTerm(year, term);
      final response = await _dio.post(
        GRAD_COURSE_URL,
        data: {'XNXQDM': xnxqdm, 'XH': ''},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final Map<String, dynamic> json = (data is String)
            ? jsonDecode(data)
            : data;
        try {
          final rows = json['datas']['xspkjgcx']['rows'] as List<dynamic>;
          return _parseGraduateCourses(rows, courseColorPalette);
        } catch (e) {
          debugPrint('Grad course parse error: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching grad courses: $e');
    }
    return [];
  }

  String _convertGradYearTerm(String year, String term) {
    if (term == '2') {
      final next = int.tryParse(year) ?? 0;
      return '${next + 1}02';
    }
    return '${year}09';
  }

  Course _parseUndergraduateCourse(
    Map<String, dynamic> json,
    AppCourseColorPalette courseColorPalette,
  ) {
    final startStep = WeekUtils.getStartAndStep(json['jcs'] as String? ?? '');

    final weekCode = WeekUtils.parseWeekCode(json['zcd'] as String? ?? '');

    int startWeek = 1;
    int endWeek = 16;
    bool isOdd = false;
    bool isEven = false;

    if (weekCode.contains('1')) {
      startWeek = weekCode.indexOf('1') + 1;
      endWeek = weekCode.lastIndexOf('1') + 1;

      bool hasOdd = false;
      bool hasEven = false;
      for (int i = 0; i < weekCode.length; i++) {
        if (weekCode[i] == '1') {
          if ((i + 1) % 2 != 0) {
            hasOdd = true;
          } else {
            hasEven = true;
          }
        }
      }
      if (hasOdd && !hasEven) isOdd = true;
      if (hasEven && !hasOdd) isEven = true;
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
    List<dynamic> rows,
    AppCourseColorPalette courseColorPalette,
  ) {
    final Map<String, Course> map = {};
    final Map<String, int> endMap = {};

    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final classId = row['BJMC']?.toString() ?? '';
      if (classId.isEmpty) continue;

      Course? course = map[classId];
      if (course == null) {
        final weekCode = row['ZCBH']?.toString() ?? '';
        final parsedWeeks = _fromBinaryWeekCode(weekCode);

        course = Course(
          courseId: row['KCDM']?.toString() ?? '',
          courseName: row['KCMC']?.toString() ?? '未知课程',
          teacher: row['JSXM']?.toString() ?? '未知教师',
          classRoom: row['JASMC']?.toString() ?? '未知地点',
          startWeek: parsedWeeks.startWeek,
          endWeek: parsedWeeks.endWeek,
          dayOfWeek: int.tryParse(row['XQ']?.toString() ?? '1') ?? 1,
          startNode: 99, // will be replaced below
          step: 1,
          isOddWeek: parsedWeeks.isOdd,
          isEvenWeek: parsedWeeks.isEven,
          weekCode: parsedWeeks.weekCode,
          color: courseColorPalette.autoColorToken(
            buildCourseColorSeed(
              row['KCMC']?.toString() ?? '',
              row['JSXM']?.toString() ?? '',
            ),
          ),
          isVirtual: false,
        );
        map[classId] = course;
      }

      final classTime = int.tryParse(row['KSJCDM']?.toString() ?? '1') ?? 1;
      course = map[classId];
      if (course != null) {
        final newStart = classTime < course.startNode
            ? classTime
            : course.startNode;
        map[classId] = course.copyWith(startNode: newStart);
        final prevEnd = endMap[classId] ?? classTime;
        if (classTime > prevEnd) endMap[classId] = classTime;
      }
    }

    final List<Course> result = [];
    for (final entry in map.entries) {
      final course = entry.value;
      final end = (endMap[entry.key] ?? course.startNode);
      result.add(course.copyWith(step: end - course.startNode + 1));
    }

    return result;
  }

  _WeekRange _fromBinaryWeekCode(String code) {
    final cleaned = code.padRight(WeekUtils.MAX_WEEKS, '0');
    int first = cleaned.indexOf('1');
    int last = cleaned.lastIndexOf('1');
    if (first == -1) {
      return _WeekRange(1, 16, false, false, cleaned);
    }
    int start = first + 1;
    int end = last + 1;
    bool hasOdd = false;
    bool hasEven = false;
    for (int i = 0; i < cleaned.length; i++) {
      if (cleaned[i] == '1') {
        if ((i + 1).isOdd) {
          hasOdd = true;
        } else {
          hasEven = true;
        }
      }
    }
    return _WeekRange(
      start,
      end,
      hasOdd && !hasEven,
      hasEven && !hasOdd,
      cleaned,
    );
  }
}

class _WeekRange {
  final int startWeek;
  final int endWeek;
  final bool isOdd;
  final bool isEven;
  final String weekCode;
  _WeekRange(
    this.startWeek,
    this.endWeek,
    this.isOdd,
    this.isEven,
    this.weekCode,
  );
}
