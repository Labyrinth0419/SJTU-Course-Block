import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/utils/course_occurrences.dart';
import 'package:flutter_test/flutter_test.dart';

Course course({
  int startWeek = 1,
  int endWeek = 8,
  String? weekCode,
  bool odd = false,
  bool even = false,
}) => Course(
  courseId: 'C1',
  courseName: 'Math',
  teacher: '',
  classRoom: '',
  startWeek: startWeek,
  endWeek: endWeek,
  dayOfWeek: 3,
  startNode: 1,
  step: 2,
  weekCode: weekCode,
  isOddWeek: odd,
  isEvenWeek: even,
);

void main() {
  test('week code has precedence over bounds and odd/even flags', () {
    final sparse = course(
      startWeek: 2,
      endWeek: 5,
      weekCode: '10100001',
      even: true,
    );
    expect(courseOccurrenceWeeks(sparse), [1, 3, 8]);
    expect(
      [for (var week = 0; week <= 9; week++) courseOccursInWeek(sparse, week)],
      [false, true, false, true, false, false, false, false, true, false],
    );
    expect(courseWeekInterval(courseOccurrenceWeeks(sparse)), isNull);
    expect(courseOccurrenceWeeks(course(weekCode: '00000000')), isEmpty);
  });

  test('odd and even parity follows academic week, not start bounds', () {
    expect(courseOccurrenceWeeks(course(startWeek: 2, odd: true)), [3, 5, 7]);
    expect(
      courseOccurrenceWeeks(course(startWeek: 1, endWeek: 7, even: true)),
      [2, 4, 6],
    );
    expect(courseWeekInterval([3, 5, 7]), 2);
    expect(courseOccurrenceWeeks(course(startWeek: 1, endWeek: 4)), [
      1,
      2,
      3,
      4,
    ]);
    expect(courseWeekInterval([1, 2, 3, 4]), 1);
  });

  test('week one anchors to Monday even if semester date is Wednesday', () {
    final semesterStart = DateTime(2026, 3, 4, 17); // Wednesday
    expect(courseDateForWeek(semesterStart, 1, 1), DateTime(2026, 3, 2));
    expect(courseDateForWeek(semesterStart, 1, 3), DateTime(2026, 3, 4));
    expect(courseDateForWeek(semesterStart, 8, 3), DateTime(2026, 4, 22));
    expect(courseWeekForDate(semesterStart, DateTime(2026, 3, 2)), 1);
    expect(courseWeekForDate(semesterStart, DateTime(2026, 3, 8)), 1);
    expect(courseWeekForDate(semesterStart, DateTime(2026, 3, 9)), 2);
  });
}
