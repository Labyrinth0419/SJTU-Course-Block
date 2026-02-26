import 'package:flutter_test/flutter_test.dart';
import 'package:course_block/core/utils/week_utils.dart';

void main() {
  test('Parse week code with ZH string "周"', () {
    String weekStr = "1-16周";
    String code = WeekUtils.parseWeekCode(weekStr);
    expect(code[0], '1'); // Week 1 has course
    expect(code[15], '1'); // Week 16 has course
    expect(code[16], '0'); // Week 17 no course
  });

  test('Parse week code with ZH string "周" and suffix (双)', () {
    String weekStr = "2-16周(双)";
    String code = WeekUtils.parseWeekCode(weekStr);
    expect(code[0], '0'); // Week 1 no course (even weeks only starting from 2)
    expect(code[1], '1'); // Week 2 has course
    expect(code[2], '0'); // Week 3 no course
    expect(code[3], '1'); // Week 4 has course
  });

  test('Parse step with "节"', () {
    List<int> step = WeekUtils.getStartAndStep("3-4节");
    expect(step[0], 3);
    expect(step[1], 2); // 3,4 -> 2 nodes
  });
}
