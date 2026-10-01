import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/ui/settings/schedule_structure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScreenProvider extends CourseProvider {
  double height = 64.0;
  double radius = 4.0;
  final writes = <(String, double)>[];

  @override
  double get gridHeight => height;

  @override
  double get cornerRadius => radius;

  @override
  Future<void> updateCurrentScheduleSetting(String key, dynamic value) async {
    writes.add((key, value as double));
    if (key == CourseSettingsStore.gridHeightKey) height = value;
    if (key == CourseSettingsStore.cornerRadiusKey) radius = value;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (title, key, invalid, corrected) in [
    (
      '课程格子高度',
      CourseSettingsStore.gridHeightKey,
      ['-1', '0', 'NaN', 'Infinity', '1e308', 'not a number'],
      '72.5',
    ),
    (
      '格子圆角半径',
      CourseSettingsStore.cornerRadiusKey,
      ['-1', 'NaN', 'Infinity', 'not a number'],
      '0',
    ),
  ]) {
    testWidgets(
      '$title rejects invalid input inline, then accepts correction',
      (tester) async {
        final provider = _ScreenProvider();
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<CourseProvider>.value(
            value: provider,
            child: const MaterialApp(home: ScheduleStructureScreen()),
          ),
        );
        await tester.tap(find.text(title).first);
        await tester.pumpAndSettle();
        final original = key == CourseSettingsStore.gridHeightKey
            ? provider.height
            : provider.radius;
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          original.toString(),
        );
        for (final input in invalid) {
          await tester.enterText(find.byType(TextField), input);
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget, reason: input);
          expect(find.text('请输入有效的数值'), findsOneWidget, reason: input);
          expect(provider.writes, isEmpty, reason: input);
          expect(
            key == CourseSettingsStore.gridHeightKey
                ? provider.height
                : provider.radius,
            original,
          );
        }
        await tester.enterText(find.byType(TextField), corrected);
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(provider.writes, [(key, double.parse(corrected))]);
      },
    );
  }
}
