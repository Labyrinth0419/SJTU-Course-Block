import '../models/course.dart';
import 'time_slots.dart';

/// Returns whether the course is scheduled in the given academic week.
bool courseOccursInWeek(Course course, int week) {
  final code = course.weekCode;
  if (code != null && code.isNotEmpty) {
    return week > 0 && week <= code.length && code[week - 1] == '1';
  }
  if (week < course.startWeek || week > course.endWeek || week < 1) {
    return false;
  }
  if (course.isOddWeek && week.isEven) return false;
  if (course.isEvenWeek && week.isOdd) return false;
  return true;
}

/// Lists the actual weeks of a course, including gaps in its week code.
List<int> courseOccurrenceWeeks(Course course) {
  final code = course.weekCode;
  final lastWeek = code != null && code.isNotEmpty
      ? code.length
      : course.endWeek;
  return [
    for (var week = 1; week <= lastWeek; week++)
      if (courseOccursInWeek(course, week)) week,
  ];
}

/// Returns the regular weekly interval, or null for an irregular sequence.
int? courseWeekInterval(List<int> weeks) {
  if (weeks.length < 2) return null;
  final interval = weeks[1] - weeks[0];
  for (var i = 2; i < weeks.length; i++) {
    if (weeks[i] - weeks[i - 1] != interval) return null;
  }
  return interval;
}

/// Treats the schedule start as a day in academic week one (Monday to Sunday).
DateTime courseDateForWeek(DateTime semesterStart, int week, int dayOfWeek) {
  final start = normalizeDate(semesterStart);
  return DateTime(
    start.year,
    start.month,
    start.day + (1 - start.weekday) + (week - 1) * 7 + dayOfWeek - 1,
  );
}

/// Resolves a calendar date to its academic week using the same Monday anchor.
int courseWeekForDate(DateTime semesterStart, DateTime date) {
  final monday = courseDateForWeek(semesterStart, 1, 1);
  final day = normalizeDate(date);
  final diff = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(monday.year, monday.month, monday.day)).inDays;
  return (diff / 7).floor() + 1;
}
