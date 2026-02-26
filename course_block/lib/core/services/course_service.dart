import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../utils/week_utils.dart';

class CourseService {
  static const String UG_COURSE_URL =
      'https://i.sjtu.edu.cn/kbcx/xskbcx_cxXsKb.html';
  static const String GRAD_COURSE_URL =
      'http://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xspkjgcx.do';

  final Dio _dio = Dio();

  Future<List<Course>> fetchUndergraduateCourses(
    String year,
    String term,
  ) async {
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
          return kbList.map((item) => _parseUndergraduateCourse(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
    return [];
  }

  Course _parseUndergraduateCourse(Map<String, dynamic> json) {
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
      color: Course.COLORS[Random().nextInt(Course.COLORS.length)],
      isVirtual: (json['xkbz'] as String? ?? '').contains('虚拟'),
    );
  }
}
