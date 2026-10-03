import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('real activity stays enabled and is not the switchable launcher', () {
    final main = RegExp(
      r'<activity\s+android:name="\.MainActivity"[\s\S]*?</activity>',
    ).firstMatch(manifest)!.group(0)!;
    expect(main, contains('android:enabled="true"'));
    expect(main, isNot(contains('android.intent.category.LAUNCHER')));
  });

  test('default icon uses an alias targeting the always-enabled activity', () {
    final alias = RegExp(
      r'<activity-alias\s+android:name="\.DefaultLauncher"[\s\S]*?</activity-alias>',
    ).firstMatch(manifest);
    expect(alias, isNotNull);
    expect(alias!.group(0), contains('android:targetActivity=".MainActivity"'));
    expect(alias.group(0), contains('android:enabled="true"'));
    expect(alias.group(0), contains('android.intent.category.LAUNCHER'));
  });

  test('upgrades reconcile aliases without the legacy icon service', () {
    expect(manifest, isNot(contains('FlutterDynamicIconPlusService')));
    expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
    expect(manifest, contains('.LauncherIconUpdateReceiver'));
  });
}
