import 'package:course_block/core/utils/course_occurrences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('civil-date weeks use Monday anchor, without clipping to term', () {
    final start = DateTime(2026, 3, 4, 17); // Wednesday, near US DST change.
    const fixtures = [
      (1, 0, null), // Sunday before week one
      (2, 1, 1), // Monday before configured semester start
      (8, 1, 1), // Last Sunday of week one
      (9, 2, 2), // Next Monday after DST change
      (15, 2, 2), // Last Sunday of week two
      (16, 3, null), // Monday after configured totalWeeks
    ];
    for (final (day, actualWeek, inTerm) in fixtures) {
      for (final date in [
        DateTime(2026, 3, day, 23),
        DateTime.utc(2026, 3, day, 23),
      ]) {
        expect(courseWeekForDate(start, date), actualWeek, reason: '$date');
        expect(
          courseWeekForDateInTerm(start, date, 2),
          inTerm,
          reason: '$date',
        );
      }
    }
    expect(courseDateForWeek(start, 1, 1), DateTime(2026, 3, 2));
  });
}
