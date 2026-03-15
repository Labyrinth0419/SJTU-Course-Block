import 'package:course_block/core/services/graduate_course_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Graduate term code mapping', () {
    const parser = GraduateCourseParser();

    test('autumn uses academic year start with 09 suffix', () {
      expect(parser.convertYearTerm('2025', '1'), '202509');
    });

    test('spring uses next calendar year with 02 suffix', () {
      expect(parser.convertYearTerm('2025', '2'), '202602');
    });

    test('summer uses next calendar year with 06 suffix', () {
      expect(parser.convertYearTerm('2025', '3'), '202606');
    });
  });
}
