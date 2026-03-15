import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const Object _unsetSettingValue = Object();

@immutable
class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    this.themeMode = ThemeMode.system,
    this.themeScheme = AppThemeScheme.morningMist,
    this.courseColorPalette = AppCourseColorPalette.candyBox,
    this.launcherIcon,
  });

  final ThemeMode themeMode;
  final AppThemeScheme themeScheme;
  final AppCourseColorPalette courseColorPalette;
  final String? launcherIcon;

  AppSettingsSnapshot copyWith({
    ThemeMode? themeMode,
    AppThemeScheme? themeScheme,
    AppCourseColorPalette? courseColorPalette,
    Object? launcherIcon = _unsetSettingValue,
  }) {
    return AppSettingsSnapshot(
      themeMode: themeMode ?? this.themeMode,
      themeScheme: themeScheme ?? this.themeScheme,
      courseColorPalette: courseColorPalette ?? this.courseColorPalette,
      launcherIcon: identical(launcherIcon, _unsetSettingValue)
          ? this.launcherIcon
          : launcherIcon as String?,
    );
  }
}

@immutable
class AppSettingsUpdateResult {
  const AppSettingsUpdateResult({
    required this.snapshot,
    required this.shouldRefreshWidgets,
  });

  final AppSettingsSnapshot snapshot;
  final bool shouldRefreshWidgets;
}

@immutable
class ScheduleSettingsSnapshot {
  const ScheduleSettingsSnapshot({
    this.showGridLines = true,
    this.showNonCurrentWeek = false,
    this.showSaturday = true,
    this.showSunday = true,
    this.outlineText = false,
    this.maxDailyClasses = 14,
    this.totalWeeks = 20,
    this.gridHeight = 64.0,
    this.cornerRadius = 4.0,
    this.backgroundColorLight,
    this.backgroundColorDark,
    this.backgroundImagePath,
    this.backgroundImageOpacity = 0.3,
  });

  final bool showGridLines;
  final bool showNonCurrentWeek;
  final bool showSaturday;
  final bool showSunday;
  final bool outlineText;
  final int maxDailyClasses;
  final int totalWeeks;
  final double gridHeight;
  final double cornerRadius;
  final int? backgroundColorLight;
  final int? backgroundColorDark;
  final String? backgroundImagePath;
  final double backgroundImageOpacity;

  ScheduleSettingsSnapshot copyWith({
    bool? showGridLines,
    bool? showNonCurrentWeek,
    bool? showSaturday,
    bool? showSunday,
    bool? outlineText,
    int? maxDailyClasses,
    int? totalWeeks,
    double? gridHeight,
    double? cornerRadius,
    Object? backgroundColorLight = _unsetSettingValue,
    Object? backgroundColorDark = _unsetSettingValue,
    Object? backgroundImagePath = _unsetSettingValue,
    double? backgroundImageOpacity,
  }) {
    return ScheduleSettingsSnapshot(
      showGridLines: showGridLines ?? this.showGridLines,
      showNonCurrentWeek: showNonCurrentWeek ?? this.showNonCurrentWeek,
      showSaturday: showSaturday ?? this.showSaturday,
      showSunday: showSunday ?? this.showSunday,
      outlineText: outlineText ?? this.outlineText,
      maxDailyClasses: maxDailyClasses ?? this.maxDailyClasses,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      gridHeight: gridHeight ?? this.gridHeight,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      backgroundColorLight: identical(backgroundColorLight, _unsetSettingValue)
          ? this.backgroundColorLight
          : backgroundColorLight as int?,
      backgroundColorDark: identical(backgroundColorDark, _unsetSettingValue)
          ? this.backgroundColorDark
          : backgroundColorDark as int?,
      backgroundImagePath: identical(backgroundImagePath, _unsetSettingValue)
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      backgroundImageOpacity:
          backgroundImageOpacity ?? this.backgroundImageOpacity,
    );
  }
}

class CourseSettingsStore {
  static const String themeModeKey = 'theme_mode';
  static const String themeSchemeKey = 'theme_scheme';
  static const String courseColorPaletteKey = 'course_color_palette';
  static const String launcherIconKey = 'app_icon_choice';

  static const String showGridLinesKey = 'show_grid_lines';
  static const String showNonCurrentWeekKey = 'show_non_current_week';
  static const String showSaturdayKey = 'show_saturday';
  static const String showSundayKey = 'show_sunday';
  static const String outlineTextKey = 'outline_text';
  static const String maxDailyClassesKey = 'max_daily_classes';
  static const String totalWeeksKey = 'total_weeks';
  static const String gridHeightKey = 'grid_height';
  static const String cornerRadiusKey = 'corner_radius';
  static const String backgroundColorLightKey = 'background_color_light';
  static const String backgroundColorDarkKey = 'background_color_dark';
  static const String backgroundImagePathKey = 'background_image_path';
  static const String backgroundImageOpacityKey = 'background_image_opacity';

  static const List<String> scheduleSettingKeys = [
    showGridLinesKey,
    showNonCurrentWeekKey,
    showSaturdayKey,
    showSundayKey,
    outlineTextKey,
    maxDailyClassesKey,
    totalWeeksKey,
    gridHeightKey,
    cornerRadiusKey,
    backgroundColorLightKey,
    backgroundColorDarkKey,
    backgroundImagePathKey,
    backgroundImageOpacityKey,
  ];

  static const Set<String> _appSettingKeys = {
    themeModeKey,
    themeSchemeKey,
    courseColorPaletteKey,
    launcherIconKey,
  };

  static const Set<String> _excludedLauncherIcons = {
    'ic_launcher',
    'default',
    'flutter',
  };

  bool isAppSettingKey(String key) => _appSettingKeys.contains(key);

  String schedulePrefKey(int scheduleId, String key) =>
      'schedule_${scheduleId}_$key';

  Future<List<String>> getAvailableLauncherIcons() async {
    final names = <String>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final key in manifest.listAssets()) {
        if (!key.startsWith('assets/icons/') &&
            !key.startsWith('assets/icon/')) {
          continue;
        }
        final iconName = p.basenameWithoutExtension(key);
        if (iconName.isEmpty || _excludedLauncherIcons.contains(iconName)) {
          continue;
        }
        names.add(iconName);
      }
    } catch (e) {
      debugPrint('Error loading AssetManifest: $e');
    }
    final availableIcons = names.toList()..sort();
    return availableIcons;
  }

  Future<void> seedScheduleSettings(
    int targetScheduleId,
    ScheduleSettingsSnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      schedulePrefKey(targetScheduleId, showGridLinesKey),
      snapshot.showGridLines,
    );
    await prefs.setBool(
      schedulePrefKey(targetScheduleId, showNonCurrentWeekKey),
      snapshot.showNonCurrentWeek,
    );
    await prefs.setBool(
      schedulePrefKey(targetScheduleId, showSaturdayKey),
      snapshot.showSaturday,
    );
    await prefs.setBool(
      schedulePrefKey(targetScheduleId, showSundayKey),
      snapshot.showSunday,
    );
    await prefs.setBool(
      schedulePrefKey(targetScheduleId, outlineTextKey),
      snapshot.outlineText,
    );
    await prefs.setInt(
      schedulePrefKey(targetScheduleId, maxDailyClassesKey),
      snapshot.maxDailyClasses,
    );
    await prefs.setInt(
      schedulePrefKey(targetScheduleId, totalWeeksKey),
      snapshot.totalWeeks,
    );
    await prefs.setDouble(
      schedulePrefKey(targetScheduleId, gridHeightKey),
      snapshot.gridHeight,
    );
    await prefs.setDouble(
      schedulePrefKey(targetScheduleId, cornerRadiusKey),
      snapshot.cornerRadius,
    );
    await prefs.setDouble(
      schedulePrefKey(targetScheduleId, backgroundImageOpacityKey),
      snapshot.backgroundImageOpacity,
    );

    await _setNullableInt(
      prefs,
      schedulePrefKey(targetScheduleId, backgroundColorLightKey),
      snapshot.backgroundColorLight,
    );
    await _setNullableInt(
      prefs,
      schedulePrefKey(targetScheduleId, backgroundColorDarkKey),
      snapshot.backgroundColorDark,
    );
    await _setNullableString(
      prefs,
      schedulePrefKey(targetScheduleId, backgroundImagePathKey),
      snapshot.backgroundImagePath,
    );
  }

  Future<void> deleteScheduleSettings(int scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in scheduleSettingKeys) {
      await prefs.remove(schedulePrefKey(scheduleId, key));
    }
  }

  Future<AppSettingsSnapshot> loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final launcherIcon = prefs.getString(launcherIconKey);
    if (launcherIcon != null) {
      await _applyLauncherIcon(launcherIcon);
    }

    return AppSettingsSnapshot(
      launcherIcon: launcherIcon,
      themeMode: _themeModeFromStorage(prefs.getString(themeModeKey)),
      themeScheme: appThemeSchemeFromStorage(prefs.getString(themeSchemeKey)),
      courseColorPalette: appCourseColorPaletteFromStorage(
        prefs.getString(courseColorPaletteKey),
      ),
    );
  }

  Future<ScheduleSettingsSnapshot> loadScheduleSettings(int? scheduleId) async {
    if (scheduleId == null) {
      return const ScheduleSettingsSnapshot();
    }

    final prefs = await SharedPreferences.getInstance();
    return ScheduleSettingsSnapshot(
      showGridLines:
          prefs.getBool(schedulePrefKey(scheduleId, showGridLinesKey)) ??
          prefs.getBool(showGridLinesKey) ??
          true,
      showNonCurrentWeek:
          prefs.getBool(schedulePrefKey(scheduleId, showNonCurrentWeekKey)) ??
          prefs.getBool(showNonCurrentWeekKey) ??
          false,
      showSaturday:
          prefs.getBool(schedulePrefKey(scheduleId, showSaturdayKey)) ??
          prefs.getBool(showSaturdayKey) ??
          true,
      showSunday:
          prefs.getBool(schedulePrefKey(scheduleId, showSundayKey)) ??
          prefs.getBool(showSundayKey) ??
          true,
      outlineText:
          prefs.getBool(schedulePrefKey(scheduleId, outlineTextKey)) ??
          prefs.getBool(outlineTextKey) ??
          false,
      maxDailyClasses:
          prefs.getInt(schedulePrefKey(scheduleId, maxDailyClassesKey)) ??
          prefs.getInt(maxDailyClassesKey) ??
          14,
      totalWeeks:
          prefs.getInt(schedulePrefKey(scheduleId, totalWeeksKey)) ??
          prefs.getInt(totalWeeksKey) ??
          20,
      gridHeight:
          prefs.getDouble(schedulePrefKey(scheduleId, gridHeightKey)) ??
          prefs.getDouble(gridHeightKey) ??
          64.0,
      cornerRadius:
          prefs.getDouble(schedulePrefKey(scheduleId, cornerRadiusKey)) ??
          prefs.getDouble(cornerRadiusKey) ??
          4.0,
      backgroundColorLight:
          prefs.getInt(schedulePrefKey(scheduleId, backgroundColorLightKey)) ??
          prefs.getInt(backgroundColorLightKey),
      backgroundColorDark:
          prefs.getInt(schedulePrefKey(scheduleId, backgroundColorDarkKey)) ??
          prefs.getInt(backgroundColorDarkKey),
      backgroundImagePath:
          prefs.getString(
            schedulePrefKey(scheduleId, backgroundImagePathKey),
          ) ??
          prefs.getString(backgroundImagePathKey),
      backgroundImageOpacity:
          prefs.getDouble(
            schedulePrefKey(scheduleId, backgroundImageOpacityKey),
          ) ??
          prefs.getDouble(backgroundImageOpacityKey) ??
          0.3,
    );
  }

  Future<AppSettingsUpdateResult> updateAppSetting({
    required String key,
    required dynamic value,
    required AppSettingsSnapshot current,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRefreshWidgets =
        key == themeModeKey ||
        key == themeSchemeKey ||
        key == courseColorPaletteKey;
    var snapshot = current;

    if (value == null) {
      if (key == launcherIconKey) {
        await prefs.remove(key);
        snapshot = current.copyWith(launcherIcon: null);
        await _applyLauncherIcon(null);
      }
    } else if (value is String) {
      await prefs.setString(key, value);
      switch (key) {
        case themeModeKey:
          snapshot = current.copyWith(themeMode: _themeModeFromStorage(value));
          break;
        case themeSchemeKey:
          snapshot = current.copyWith(
            themeScheme: appThemeSchemeFromStorage(value),
          );
          break;
        case courseColorPaletteKey:
          snapshot = current.copyWith(
            courseColorPalette: appCourseColorPaletteFromStorage(value),
          );
          break;
        case launcherIconKey:
          snapshot = current.copyWith(launcherIcon: value);
          await _applyLauncherIcon(value);
          break;
      }
    }

    return AppSettingsUpdateResult(
      snapshot: snapshot,
      shouldRefreshWidgets: shouldRefreshWidgets,
    );
  }

  Future<ScheduleSettingsSnapshot> updateScheduleSetting({
    required int scheduleId,
    required String key,
    required dynamic value,
    required ScheduleSettingsSnapshot current,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedKey = schedulePrefKey(scheduleId, key);

    if (value == null) {
      if (key == backgroundImagePathKey) {
        await prefs.remove(resolvedKey);
        return current.copyWith(backgroundImagePath: null);
      }
      return current;
    }

    if (value is bool) {
      await prefs.setBool(resolvedKey, value);
      return switch (key) {
        showGridLinesKey => current.copyWith(showGridLines: value),
        showNonCurrentWeekKey => current.copyWith(showNonCurrentWeek: value),
        showSaturdayKey => current.copyWith(showSaturday: value),
        showSundayKey => current.copyWith(showSunday: value),
        outlineTextKey => current.copyWith(outlineText: value),
        _ => current,
      };
    }

    if (value is int) {
      await prefs.setInt(resolvedKey, value);
      return switch (key) {
        maxDailyClassesKey => current.copyWith(maxDailyClasses: value),
        totalWeeksKey => current.copyWith(totalWeeks: value),
        backgroundColorLightKey => current.copyWith(
          backgroundColorLight: value,
        ),
        backgroundColorDarkKey => current.copyWith(backgroundColorDark: value),
        _ => current,
      };
    }

    if (value is double) {
      await prefs.setDouble(resolvedKey, value);
      return switch (key) {
        gridHeightKey => current.copyWith(gridHeight: value),
        cornerRadiusKey => current.copyWith(cornerRadius: value),
        backgroundImageOpacityKey => current.copyWith(
          backgroundImageOpacity: value,
        ),
        _ => current,
      };
    }

    if (value is String) {
      await prefs.setString(resolvedKey, value);
      return key == backgroundImagePathKey
          ? current.copyWith(backgroundImagePath: value)
          : current;
    }

    return current;
  }

  ThemeMode _themeModeFromStorage(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _setNullableInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setInt(key, value);
  }

  Future<void> _setNullableString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }

  Future<void> _applyLauncherIcon(String? name) async {
    try {
      if (await FlutterDynamicIconPlus.supportsAlternateIcons) {
        final fullName = name == null
            ? null
            : 'com.labyrinth.course_block.$name';
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: fullName,
          blacklistBrands: [
            'vivo',
            'VIVO',
            'iqoo',
            'IQOO',
            'Xiaomi',
            'Redmi',
            'OPPO',
            'OnePlus',
          ],
          blacklistManufactures: [
            'vivo',
            'VIVO',
            'iqoo',
            'IQOO',
            'Xiaomi',
            'Redmi',
          ],
        );
      }
    } catch (e) {
      debugPrint('error setting launcher icon: $e');
    }
  }
}
