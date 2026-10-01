import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/widgets/schedule_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'recovered settings render Monday-anchored dates and today together',
    (tester) async {
      final store = CourseSettingsStore();
      final heightKey = store.schedulePrefKey(
        1,
        CourseSettingsStore.gridHeightKey,
      );
      SharedPreferences.setMockInitialValues({
        heightKey: double.infinity,
        store.schedulePrefKey(1, CourseSettingsStore.cornerRadiusKey): -2.0,
        store.schedulePrefKey(1, CourseSettingsStore.backgroundImageOpacityKey):
            double.nan,
        CourseSettingsStore.gridHeightKey: 'invalid legacy value',
      });

      final recovered = await store.loadScheduleSettings(1);
      expect(
        (
          recovered.gridHeight,
          recovered.cornerRadius,
          recovered.backgroundImageOpacity,
        ),
        (64.0, 4.0, 0.3),
      );
      await expectLater(
        store.updateScheduleSetting(
          scheduleId: 1,
          key: CourseSettingsStore.gridHeightKey,
          value: -1.0,
          current: recovered,
        ),
        throwsArgumentError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(heightKey), double.infinity);
      await store.seedScheduleSettings(2, recovered);
      final settings = await store.loadScheduleSettings(2);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: ScheduleGrid(
                courses: [
                  Course(
                    courseId: 'integration-sample',
                    courseName: 'Sample',
                    teacher: '',
                    classRoom: '',
                    startWeek: 1,
                    endWeek: 2,
                    dayOfWeek: 3,
                    startNode: 1,
                    step: 2,
                  ),
                ],
                currentWeek: 1,
                totalWeeks: settings.totalWeeks,
                maxDailyClasses: settings.maxDailyClasses,
                showGridLines: settings.showGridLines,
                showNonCurrentWeek: settings.showNonCurrentWeek,
                showSaturday: settings.showSaturday,
                showSunday: settings.showSunday,
                outlineText: settings.outlineText,
                gridHeight: settings.gridHeight,
                cornerRadius: settings.cornerRadius,
                courseColorPalette: AppCourseColorPalette.candyBox,
                startDate: DateTime(2026, 9, 9, 17),
                now: DateTime(2026, 9, 9, 10),
                onRefreshRequested: () async {},
              ),
            ),
          ),
        ),
      );

      for (final date in [
        '9/7',
        '9/8',
        '9/9',
        '9/10',
        '9/11',
        '9/12',
        '9/13',
      ]) {
        expect(find.text(date), findsOneWidget);
      }
      expect(
        tester.getCenter(find.text('9/7')).dx,
        tester.getCenter(find.text('一')).dx,
      );
      expect(
        tester.getCenter(find.text('9/9')).dx,
        tester.getCenter(find.text('三')).dx,
      );
      expect(
        tester.widget<Text>(find.text('9/9')).style?.fontWeight,
        FontWeight.bold,
      );
      expect(find.text('(学期未开始)'), findsNothing);
      expect(find.text('(学期已结束)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
