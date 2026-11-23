import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/home/home_screen.dart';
import 'package:course_block/ui/settings/more_functions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCourseProvider extends CourseProvider {
  _TestCourseProvider(this.currentSchedule, {super.now});

  @override
  final Schedule currentSchedule;

  @override
  Future<void> loadCourses({bool recalcWeek = true}) async {}
}

class _ScheduleManager extends CourseScheduleManager {
  _ScheduleManager(this.schedule);

  Schedule schedule;

  @override
  Future<CourseScheduleState> loadScheduleState({
    required String defaultScheduleName,
  }) async => CourseScheduleState(
    schedules: [schedule],
    currentSchedule: schedule,
    courses: [],
  );

  @override
  Future<void> updateSchedule(Schedule schedule) async {
    this.schedule = schedule;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('browsing a week keeps the current week marker fixed', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 23);
    final provider = _TestCourseProvider(
      Schedule(
        name: 'Test schedule',
        year: '2026',
        term: '1',
        startDate: DateTime(now.year, now.month, now.day - 7),
      ),
      now: () => now,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMoreFunctionsSheet(context),
                child: const Text('更多'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.text('当前第 2 周 · 浏览第 1 周'), findsOneWidget);

    final slider = find.byType(Slider);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, greaterThan(2));
    expect(
      find.text('当前第 2 周 · 浏览第 ${provider.currentWeek} 周'),
      findsOneWidget,
    );

    expect(find.text('回到当前周'), findsNothing);
    await tester.tap(find.text('切换显示周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到本周'));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, greaterThan(2));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, 2);
    expect(find.text('当前第 2 周'), findsOneWidget);
    await tester.tap(find.text('切换显示周'));
    await tester.pumpAndSettle();
    expect(find.text('回到本周'), findsNothing);
  });

  testWidgets('calibrates an imported first week to week eleven', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 23);
    final manager = _ScheduleManager(
      Schedule(
        id: 1,
        name: 'Test schedule',
        year: '2026',
        term: '1',
        startDate: now,
        isCurrent: true,
      ),
    );
    final provider = CourseProvider(
      courseScheduleManager: manager,
      now: () => now,
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<CourseProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;

    // Multiple changes before layout must never jump through stale weeks.
    final visitedPages = <double?>[];
    controller.addListener(() => visitedPages.add(controller.page));
    provider.setCurrentWeek(3);
    provider.setCurrentWeek(5);
    await tester.pumpAndSettle();
    expect(visitedPages, isNot(contains(2.0)));
    expect(controller.page, 4);
    expect(provider.academicWeek, 1);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    final dialogSlider = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Slider),
    );

    await tester.tap(find.text('切换显示周'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(dialogSlider).value, 5);
    await tester.tap(find.text('回到本周'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(dialogSlider).value, 1);
    expect(provider.currentWeek, 5);
    tester.widget<Slider>(dialogSlider).onChanged!(8);
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, 8);
    expect(controller.page, 7);
    expect(provider.academicWeek, 1);
    expect(manager.schedule.startDate, now);

    await tester.tap(find.text('校准当前周'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(dialogSlider).value, 1);
    tester.widget<Slider>(dialogSlider).onChanged!(11);
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, 8);
    expect(controller.page, 7);
    expect(manager.schedule.startDate, now);

    await tester.tap(find.text('校准当前周'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(dialogSlider).onChanged!(11);
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.currentWeek, 11);
    expect(controller.page, 10);
    expect(manager.schedule.startDate, DateTime(2026, 9, 14));
    expect(find.text('当前第 11 周'), findsOneWidget);

    provider.setCurrentWeek(4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换显示周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回到本周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(controller.page, 10);

    now = DateTime(2026, 11, 30);
    await provider.loadCourses();
    await tester.pumpAndSettle();
    expect(provider.academicWeek, 12);
    expect(controller.page, 11);
  });
}
