import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScheduleManager extends CourseScheduleManager {
  final schedule = Schedule(
    id: 1,
    name: 'Term',
    year: '2026',
    term: '1',
    startDate: DateTime(2026, 3, 4, 17),
    isCurrent: true,
  );

  @override
  Future<CourseScheduleState> loadScheduleState({
    required String defaultScheduleName,
  }) async => CourseScheduleState(
    schedules: [schedule],
    currentSchedule: schedule,
    courses: <Course>[],
  );

  @override
  Future<List<Course>> normalizeCourseColors({
    required List<Course> courses,
    required AppCourseColorPalette courseColorPalette,
  }) async => courses;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'provider browsing clamps, while academic week follows Monday anchor',
    () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 3, 1, 7);
      final provider = CourseProvider(
        courseScheduleManager: _ScheduleManager(),
        now: () => now,
      );
      addTearDown(provider.dispose);
      await provider.loadCourses();
      await provider.updateCurrentScheduleSetting(
        CourseSettingsStore.totalWeeksKey,
        2,
      );
      expect(provider.currentWeek, 1); // Before week one: display clamps.
      provider.setCurrentWeek(99);
      expect(provider.currentWeek, 2);
      now = DateTime(2026, 3, 2, 7); // Monday, before configured Wednesday.
      await provider.loadCourses();
      expect(provider.currentWeek, 1);
      now = DateTime(2026, 3, 9, 7); // Next Monday.
      await provider.loadCourses();
      expect(provider.currentWeek, 2);
      now = DateTime(2026, 3, 16, 7); // Past the end of week two.
      await provider.loadCourses();
      expect(provider.currentWeek, 2); // Browsing only; widgets must be empty.
    },
  );
}
