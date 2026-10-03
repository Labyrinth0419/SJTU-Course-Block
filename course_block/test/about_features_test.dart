import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/app_update_service.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/services/launcher_icon_service.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:course_block/ui/screens/about_screen.dart';
import 'package:course_block/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Updates extends AppUpdateService {
  _Updates({this.update, this.fail = false});
  final ReleaseUpdate? update;
  final bool fail;
  int calls = 0;

  @override
  Future<ReleaseUpdate?> checkForUpdate({bool automatic = false}) async {
    calls++;
    if (fail) throw StateError('offline');
    return update;
  }
}

class _Icons extends LauncherIconService {
  bool fail = false;
  bool failRestore = false;
  @override
  Future<void> setIcon(String? name) async {
    if (fail) throw StateError('native icon failure');
  }

  @override
  Future<String?> restoreIcon(String? fallback) async {
    if (failRestore) throw StateError('native restore failure');
    return fallback;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '课程表',
      packageName: 'com.labyrinth.course_block',
      version: '1.1.2',
      buildNumber: '2003',
      buildSignature: 'test',
    );
  });

  Future<void> pumpAbout(
    WidgetTester tester,
    CourseProvider provider, {
    AppUpdateService? updates,
    Future<bool> Function(Uri)? openUrl,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeScheme.morningMist, Brightness.light),
          home: AboutScreen(
            updateService: updates ?? _Updates(),
            openReleaseUrl: openUrl,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'seventh tap unlocks the icon entry and persists across screens',
    (tester) async {
      final provider = CourseProvider();
      addTearDown(provider.dispose);
      await pumpAbout(tester, provider);
      expect(find.text('更改启动器图标'), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('应用版本'));
        await tester.pump();
      }
      expect(find.text('更改启动器图标'), findsNothing);
      await tester.tap(find.text('应用版本'));
      await tester.pumpAndSettle();
      expect(find.text('似乎发生了什么变化'), findsOneWidget);
      expect(find.text('更改启动器图标'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          CourseSettingsStore.hiddenFeaturesUnlockedKey,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      final restarted = CourseProvider();
      addTearDown(restarted.dispose);
      await pumpAbout(tester, restarted);
      expect(find.text('更改启动器图标'), findsOneWidget);
    },
  );

  testWidgets('automatic update defaults on and the switch persists off', (
    tester,
  ) async {
    final provider = CourseProvider();
    addTearDown(provider.dispose);
    await pumpAbout(tester, provider);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.ensureVisible(find.text('自动更新'));
    await tester.tap(find.text('自动更新'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        CourseSettingsStore.autoUpdateEnabledKey,
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    final restarted = CourseProvider();
    addTearDown(restarted.dispose);
    await pumpAbout(tester, restarted);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('manual newer-version dialog downloads only after confirmation', (
    tester,
  ) async {
    final provider = CourseProvider();
    addTearDown(provider.dispose);
    final update = ReleaseUpdate(
      currentVersion: '1.1.2',
      version: '1.1.3',
      releaseUri: Uri.parse(
        '${AppUpdateService.repositoryUrl}/releases/tag/v1.1.3',
      ),
      notes: '修复',
    );
    final updates = _Updates(update: update);
    Uri? opened;
    await pumpAbout(
      tester,
      provider,
      updates: updates,
      openUrl: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v1.1.3'), findsOneWidget);
    expect(opened, isNull);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(opened, isNull);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('前往下载'));
    await tester.pumpAndSettle();
    expect(opened, update.releaseUri);
    expect(updates.calls, 2);
  });

  testWidgets(
    'manual check reports no newer version and permits retry after failure',
    (tester) async {
      final provider = CourseProvider();
      addTearDown(provider.dispose);
      await pumpAbout(tester, provider, updates: _Updates(fail: true));
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('检查更新失败，请检查网络后重试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpAbout(tester, provider);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('当前没有可用的新版本'), findsOneWidget);
    },
  );

  testWidgets('normal settings no longer exposes the hidden icon picker', (
    tester,
  ) async {
    final provider = CourseProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('启动器图标'), findsNothing);
  });

  test('icon failures leave preferences and snapshot unchanged', () async {
    SharedPreferences.setMockInitialValues({
      CourseSettingsStore.launcherIconKey: 'an_an',
    });
    final icons = _Icons()..fail = true;
    final store = CourseSettingsStore(launcherIconService: icons);
    const current = AppSettingsSnapshot(launcherIcon: 'an_an');
    await expectLater(
      store.updateAppSetting(
        key: CourseSettingsStore.launcherIconKey,
        value: 'arisa',
        current: current,
      ),
      throwsStateError,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        CourseSettingsStore.launcherIconKey,
      ),
      'an_an',
    );
    expect(current.launcherIcon, 'an_an');
  });

  test(
    'startup icon failure does not discard theme or update preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        CourseSettingsStore.launcherIconKey: 'an_an',
        CourseSettingsStore.themeModeKey: 'dark',
        CourseSettingsStore.autoUpdateEnabledKey: false,
        CourseSettingsStore.hiddenFeaturesUnlockedKey: true,
      });
      final icons = _Icons()..failRestore = true;
      final snapshot = await CourseSettingsStore(
        launcherIconService: icons,
      ).loadAppSettings();
      expect(snapshot.launcherIcon, 'an_an');
      expect(snapshot.themeMode, ThemeMode.dark);
      expect(snapshot.autoUpdateEnabled, isFalse);
      expect(snapshot.hiddenFeaturesUnlocked, isTrue);
    },
  );

  test(
    'new boolean setting values reject invalid types without writes',
    () async {
      final store = CourseSettingsStore();
      for (final key in [
        CourseSettingsStore.hiddenFeaturesUnlockedKey,
        CourseSettingsStore.autoUpdateEnabledKey,
      ]) {
        await expectLater(
          store.updateAppSetting(
            key: key,
            value: 'true',
            current: const AppSettingsSnapshot(),
          ),
          throwsArgumentError,
        );
        expect((await SharedPreferences.getInstance()).get(key), isNull);
      }
    },
  );
}
