import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/widgets/schedule_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGrid(
  WidgetTester tester, {
  required DateTime now,
  DateTime? startDate,
  int currentWeek = 1,
  int totalWeeks = 2,
  bool showSaturday = true,
  bool showSunday = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 300,
          child: ScheduleGrid(
            courses: const [],
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            maxDailyClasses: 1,
            showGridLines: true,
            showNonCurrentWeek: false,
            showSaturday: showSaturday,
            showSunday: showSunday,
            outlineText: false,
            gridHeight: 80,
            cornerRadius: 8,
            courseColorPalette: AppCourseColorPalette.candyBox,
            startDate: startDate,
            now: now,
            onRefreshRequested: () async {},
          ),
        ),
      ),
    ),
  );
}

void _expectHeaders(WidgetTester tester, List<String> dates) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final renderedDates = tester.widgetList<Text>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(widget.data ?? ''),
    ),
  );
  expect(renderedDates.map((text) => text.data).toList(), dates);
  for (var i = 0; i < dates.length; i++) {
    expect(find.text(weekdays[i]), findsOneWidget);
    expect(find.text(dates[i]), findsOneWidget);
    expect(
      tester.getCenter(find.text(dates[i])).dx,
      tester.getCenter(find.text(weekdays[i])).dx,
    );
  }
}

void main() {
  final wednesdayStart = DateTime(2026, 9, 9, 17);
  final fixedNow = DateTime(2026, 9, 9, 10);

  testWidgets(
    'Wednesday term start anchors week one and later headers to Monday',
    (tester) async {
      await _pumpGrid(tester, now: fixedNow, startDate: wednesdayStart);
      _expectHeaders(tester, [
        '9/7',
        '9/8',
        '9/9',
        '9/10',
        '9/11',
        '9/12',
        '9/13',
      ]);
      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: wednesdayStart,
        currentWeek: 2,
      );
      _expectHeaders(tester, [
        '9/14',
        '9/15',
        '9/16',
        '9/17',
        '9/18',
        '9/19',
        '9/20',
      ]);
    },
  );

  testWidgets(
    'today highlights its actual weekday header, not the shifted column',
    (tester) async {
      await _pumpGrid(tester, now: fixedNow, startDate: wednesdayStart);
      final palette = buildAppTheme(
        AppThemeScheme.morningMist,
        Brightness.light,
      ).extension<AppThemePalette>()!;
      expect(
        tester.getCenter(find.text('9/9')).dx,
        tester.getCenter(find.text('三')).dx,
      );
      final today = tester.widget<Text>(find.text('9/9'));
      final monday = tester.widget<Text>(find.text('9/7'));
      expect(today.style?.color, palette.gridTodayText);
      expect(today.style?.fontWeight, FontWeight.bold);
      expect(monday.style?.color, palette.gridMinorText);
      expect(monday.style?.fontWeight, FontWeight.normal);
    },
  );

  testWidgets(
    'term status begins before week one Monday and ends after last Sunday',
    (tester) async {
      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: wednesdayStart,
        currentWeek: 0,
      );
      _expectHeaders(tester, [
        '8/31',
        '9/1',
        '9/2',
        '9/3',
        '9/4',
        '9/5',
        '9/6',
      ]);
      expect(find.text('(学期未开始)'), findsNWidgets(7));
      expect(find.text('(学期已结束)'), findsNothing);

      await _pumpGrid(tester, now: fixedNow, startDate: wednesdayStart);
      _expectHeaders(tester, [
        '9/7',
        '9/8',
        '9/9',
        '9/10',
        '9/11',
        '9/12',
        '9/13',
      ]);
      expect(find.text('(学期未开始)'), findsNothing);
      expect(find.text('(学期已结束)'), findsNothing);

      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: wednesdayStart,
        currentWeek: 2,
      );
      _expectHeaders(tester, [
        '9/14',
        '9/15',
        '9/16',
        '9/17',
        '9/18',
        '9/19',
        '9/20',
      ]);
      expect(find.text('(学期未开始)'), findsNothing);
      expect(find.text('(学期已结束)'), findsNothing);

      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: wednesdayStart,
        currentWeek: 3,
      );
      _expectHeaders(tester, [
        '9/21',
        '9/22',
        '9/23',
        '9/24',
        '9/25',
        '9/26',
        '9/27',
      ]);
      expect(find.text('(学期未开始)'), findsNothing);
      expect(find.text('(学期已结束)'), findsNWidgets(7));
    },
  );

  testWidgets(
    'Monday term start keeps weekday headers and weekend visibility',
    (tester) async {
      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: DateTime(2026, 9, 7, 17),
        showSaturday: false,
        showSunday: false,
      );
      _expectHeaders(tester, ['9/7', '9/8', '9/9', '9/10', '9/11']);
      expect(find.text('六'), findsNothing);
      expect(find.text('日'), findsNothing);
      expect(find.text('(学期未开始)'), findsNothing);

      await _pumpGrid(
        tester,
        now: fixedNow,
        startDate: DateTime(2026, 9, 7, 17),
        currentWeek: 2,
        showSaturday: false,
        showSunday: true,
      );
      _expectHeaders(tester, [
        '9/14',
        '9/15',
        '9/16',
        '9/17',
        '9/18',
        '9/19',
        '9/20',
      ]);
      expect(find.text('(学期已结束)'), findsNothing);
    },
  );

  testWidgets('without a term start, headers use captured now week Monday', (
    tester,
  ) async {
    await _pumpGrid(tester, now: fixedNow, currentWeek: 4);
    _expectHeaders(tester, [
      '9/7',
      '9/8',
      '9/9',
      '9/10',
      '9/11',
      '9/12',
      '9/13',
    ]);
    expect(find.text('(学期未开始)'), findsNothing);
    expect(find.text('(学期已结束)'), findsNothing);
  });
}
