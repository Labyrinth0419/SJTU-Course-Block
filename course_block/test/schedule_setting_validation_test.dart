import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/widgets/schedule_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = CourseSettingsStore();
  const defaults = ScheduleSettingsSnapshot();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'invalid stored float settings recover defaults, including wrong types',
    () async {
      final invalidValues = <String, List<Object>>{
        CourseSettingsStore.gridHeightKey: [
          0.0,
          -1.0,
          double.nan,
          double.infinity,
          double.negativeInfinity,
          1e308,
          64,
          '64',
        ],
        CourseSettingsStore.cornerRadiusKey: [
          -1.0,
          double.nan,
          double.infinity,
          double.negativeInfinity,
          4,
          '4',
        ],
        CourseSettingsStore.backgroundImageOpacityKey: [
          -0.1,
          1.1,
          double.nan,
          double.infinity,
          1,
          '0.3',
        ],
      };
      for (final entry in invalidValues.entries) {
        for (final invalid in entry.value) {
          SharedPreferences.setMockInitialValues({
            store.schedulePrefKey(1, entry.key): invalid,
            entry.key: invalid,
          });
          final loaded = await store.loadScheduleSettings(1);
          expect(
            loaded.gridHeight,
            defaults.gridHeight,
            reason: '${entry.key}: $invalid',
          );
          expect(
            loaded.cornerRadius,
            defaults.cornerRadius,
            reason: '${entry.key}: $invalid',
          );
          expect(
            loaded.backgroundImageOpacity,
            defaults.backgroundImageOpacity,
            reason: '${entry.key}: $invalid',
          );
        }
      }
    },
  );

  test(
    'invalid schedule-specific values fall back to valid legacy values',
    () async {
      SharedPreferences.setMockInitialValues({
        store.schedulePrefKey(1, CourseSettingsStore.gridHeightKey): double.nan,
        CourseSettingsStore.gridHeightKey: 72.5,
        store.schedulePrefKey(1, CourseSettingsStore.cornerRadiusKey): -3.0,
        CourseSettingsStore.cornerRadiusKey: 0.0,
        store.schedulePrefKey(1, CourseSettingsStore.backgroundImageOpacityKey):
            double.infinity,
        CourseSettingsStore.backgroundImageOpacityKey: 1.0,
      });
      final loaded = await store.loadScheduleSettings(1);
      expect(loaded.gridHeight, 72.5);
      expect(loaded.cornerRadius, 0.0);
      expect(loaded.backgroundImageOpacity, 1.0);
    },
  );

  test(
    'invalid writes reject without changing preferences or snapshot',
    () async {
      final validValues = <String, double>{
        CourseSettingsStore.gridHeightKey: 73.5,
        CourseSettingsStore.cornerRadiusKey: 0.0,
        CourseSettingsStore.backgroundImageOpacityKey: 1.0,
      };
      final invalidValues = <String, List<Object>>{
        CourseSettingsStore.gridHeightKey: [
          0.0,
          -1.0,
          double.nan,
          double.infinity,
          1e308,
          73,
        ],
        CourseSettingsStore.cornerRadiusKey: [
          -1.0,
          double.nan,
          double.infinity,
          0,
        ],
        CourseSettingsStore.backgroundImageOpacityKey: [
          -0.1,
          1.1,
          double.nan,
          double.infinity,
          1,
        ],
      };
      var snapshot = defaults;
      for (final entry in validValues.entries) {
        snapshot = await store.updateScheduleSetting(
          scheduleId: 1,
          key: entry.key,
          value: entry.value,
          current: snapshot,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      for (final entry in invalidValues.entries) {
        for (final invalid in entry.value) {
          await expectLater(
            store.updateScheduleSetting(
              scheduleId: 1,
              key: entry.key,
              value: invalid,
              current: snapshot,
            ),
            throwsArgumentError,
            reason: '${entry.key}: $invalid',
          );
          expect(
            prefs.get(store.schedulePrefKey(1, entry.key)),
            validValues[entry.key],
          );
          expect(snapshot.gridHeight, 73.5);
          expect(snapshot.cornerRadius, 0.0);
          expect(snapshot.backgroundImageOpacity, 1.0);
        }
      }
    },
  );

  test('seed rejects invalid float snapshot before any target write', () async {
    final prefs = await SharedPreferences.getInstance();
    final gridKey = store.schedulePrefKey(2, CourseSettingsStore.gridHeightKey);
    final lineKey = store.schedulePrefKey(
      2,
      CourseSettingsStore.showGridLinesKey,
    );
    await prefs.setDouble(gridKey, 80.0);
    await prefs.setBool(lineKey, false);
    for (final invalid in [
      defaults.copyWith(gridHeight: double.infinity),
      defaults.copyWith(cornerRadius: -1.0),
      defaults.copyWith(backgroundImageOpacity: double.nan),
    ]) {
      await expectLater(
        store.seedScheduleSettings(2, invalid),
        throwsArgumentError,
      );
      expect(prefs.getDouble(gridKey), 80.0);
      expect(prefs.getBool(lineKey), false);
    }
  });

  test(
    'valid floats survive writes, seed, and reload without clamping',
    () async {
      var snapshot = defaults;
      for (final (key, value) in [
        (CourseSettingsStore.gridHeightKey, 0.25),
        (CourseSettingsStore.cornerRadiusKey, 12345.75),
        (CourseSettingsStore.backgroundImageOpacityKey, 0.0),
      ]) {
        snapshot = await store.updateScheduleSetting(
          scheduleId: 1,
          key: key,
          value: value,
          current: snapshot,
        );
      }
      await store.seedScheduleSettings(2, snapshot);
      for (final id in [1, 2]) {
        final loaded = await store.loadScheduleSettings(id);
        expect(loaded.gridHeight, 0.25);
        expect(loaded.cornerRadius, 12345.75);
        expect(loaded.backgroundImageOpacity, 0.0);
      }
    },
  );

  testWidgets('recovered height and radius can render schedule grid', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      store.schedulePrefKey(1, CourseSettingsStore.gridHeightKey):
          double.infinity,
      store.schedulePrefKey(1, CourseSettingsStore.cornerRadiusKey): double.nan,
    });
    final settings = await store.loadScheduleSettings(1);
    expect(settings.gridHeight, defaults.gridHeight);
    expect(settings.cornerRadius, defaults.cornerRadius);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: ScheduleGrid(
              courses: [
                Course(
                  courseId: 'demo',
                  courseName: 'Sample',
                  teacher: '',
                  classRoom: '',
                  startWeek: 1,
                  endWeek: 1,
                  dayOfWeek: 1,
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
              onRefreshRequested: () async {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
