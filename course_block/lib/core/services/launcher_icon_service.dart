import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class LauncherIconService {
  static const channel = MethodChannel('course_block/launcher_icon');

  Future<String?> restoreIcon(String? fallback) async {
    if (Platform.isAndroid) {
      return channel.invokeMethod<String>('restoreIcon');
    }
    if (Platform.isIOS && fallback != null) await setIcon(fallback);
    return fallback;
  }

  Future<void> setIcon(String? name) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('setIcon', {'name': name});
    } else if (Platform.isIOS &&
        await FlutterDynamicIconPlus.supportsAlternateIcons) {
      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: name == null ? null : 'com.labyrinth.course_block.$name',
      );
    }
  }
}
