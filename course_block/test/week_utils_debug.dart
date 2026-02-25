import 'package:course_block/core/utils/week_utils.dart';

void main() {
  testWeekParsing('1-16(双)');
  testWeekParsing('1-16');
  testWeekParsing('3-18');
  testWeekParsing('1-8, 10-16');
}

void testWeekParsing(String weekStr) {
  print('Testing: "$weekStr"');
  final code = WeekUtils.parseWeekCode(weekStr);
  print('Code: $code');
  if (code.contains('1')) {
    final start = code.indexOf('1') + 1;
    final end = code.lastIndexOf('1') + 1;
    print('Start: $start, End: $end');
  } else {
    print('No weeks found');
  }
}
