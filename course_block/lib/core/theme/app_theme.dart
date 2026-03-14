import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

enum AppThemeScheme {
  morningMist,
  springBud,
  apricotGlow,
  sakuraMist,
  tokyoNight,
}

enum AppCourseColorPalette { mildlinerNotes, candyBox, jellySoda, tokyoNeon }

const String _courseColorTokenPrefix = 'palette:';
const List<String> kLegacyCourseColorHexes = [
  '#FF758F',
  '#9B9BFF',
  '#4ADBC8',
  '#FF9F46',
  '#A06CD5',
  '#FFB7B2',
  '#B5EAD7',
  '#C7CEEA',
  '#E2F0CB',
  '#FFDAC1',
  '#FF9AA2',
  '#6EB5FF',
];

AppThemeScheme appThemeSchemeFromStorage(String? value) {
  return switch (value) {
    'spring_bud' => AppThemeScheme.springBud,
    'apricot_glow' => AppThemeScheme.apricotGlow,
    'sakura_mist' => AppThemeScheme.sakuraMist,
    'tokyo_night' => AppThemeScheme.tokyoNight,
    _ => AppThemeScheme.morningMist,
  };
}

AppCourseColorPalette appCourseColorPaletteFromStorage(String? value) {
  return switch (value) {
    'mildliner_notes' => AppCourseColorPalette.mildlinerNotes,
    'jelly_soda' => AppCourseColorPalette.jellySoda,
    'tokyo_neon' => AppCourseColorPalette.tokyoNeon,
    _ => AppCourseColorPalette.candyBox,
  };
}

extension AppThemeSchemeX on AppThemeScheme {
  String get storageKey => switch (this) {
    AppThemeScheme.morningMist => 'morning_mist',
    AppThemeScheme.springBud => 'spring_bud',
    AppThemeScheme.apricotGlow => 'apricot_glow',
    AppThemeScheme.sakuraMist => 'sakura_mist',
    AppThemeScheme.tokyoNight => 'tokyo_night',
  };

  String get label => switch (this) {
    AppThemeScheme.morningMist => '晨雾蓝',
    AppThemeScheme.springBud => '春芽绿',
    AppThemeScheme.apricotGlow => '杏桃橙',
    AppThemeScheme.sakuraMist => '樱雾粉',
    AppThemeScheme.tokyoNight => 'Tokyo Night',
  };

  String get subtitle => switch (this) {
    AppThemeScheme.morningMist => '空气感蓝白',
    AppThemeScheme.springBud => '清新校园绿',
    AppThemeScheme.apricotGlow => '暖调纸面橙',
    AppThemeScheme.sakuraMist => '柔和雾粉紫',
    AppThemeScheme.tokyoNight => '冷峻昼白 / 霓虹夜色',
  };

  AppThemeTone resolve(Brightness brightness) {
    return switch (this) {
      AppThemeScheme.morningMist =>
        brightness == Brightness.dark ? _morningMistDark : _morningMistLight,
      AppThemeScheme.springBud =>
        brightness == Brightness.dark ? _springBudDark : _springBudLight,
      AppThemeScheme.apricotGlow =>
        brightness == Brightness.dark ? _apricotGlowDark : _apricotGlowLight,
      AppThemeScheme.sakuraMist =>
        brightness == Brightness.dark ? _sakuraMistDark : _sakuraMistLight,
      AppThemeScheme.tokyoNight =>
        brightness == Brightness.dark ? _tokyoNightDark : _tokyoDayLight,
    };
  }

  List<Color> preview(Brightness brightness) {
    final tone = resolve(brightness);
    return [tone.primary, tone.secondary, tone.tertiary];
  }

  List<Color> courseFallbackPalette(Brightness brightness) {
    final colors = switch (this) {
      AppThemeScheme.morningMist => <Color>[
        const Color(0xFF4C82C3),
        const Color(0xFF4E9DB1),
        const Color(0xFF6573C3),
        const Color(0xFF4F8F7E),
        const Color(0xFFB86E67),
        const Color(0xFF8A73C6),
        const Color(0xFF6A9A58),
        const Color(0xFFD38A5B),
      ],
      AppThemeScheme.springBud => <Color>[
        const Color(0xFF58B889),
        const Color(0xFF449F78),
        const Color(0xFF6ABF6A),
        const Color(0xFF7CA65B),
        const Color(0xFF3C9E91),
        const Color(0xFFA48E45),
        const Color(0xFF679F89),
        const Color(0xFFCC9358),
      ],
      AppThemeScheme.apricotGlow => <Color>[
        const Color(0xFFE2924F),
        const Color(0xFFD9785D),
        const Color(0xFFC98B45),
        const Color(0xFFB86C6C),
        const Color(0xFFA97045),
        const Color(0xFFD1A14D),
        const Color(0xFFBE7E55),
        const Color(0xFF8F6959),
      ],
      AppThemeScheme.sakuraMist => <Color>[
        const Color(0xFFD985A5),
        const Color(0xFFB08CDD),
        const Color(0xFF7ABFB7),
        const Color(0xFFC16F8C),
        const Color(0xFF8B76C9),
        const Color(0xFF679E9A),
        const Color(0xFFA15E78),
        const Color(0xFF6E78B8),
      ],
      AppThemeScheme.tokyoNight => <Color>[
        const Color(0xFF4C6EF5),
        const Color(0xFF7C63FF),
        const Color(0xFF159DB2),
        const Color(0xFF2C7BE5),
        const Color(0xFF2FB7A8),
        const Color(0xFF9A67EA),
        const Color(0xFF3B5CCC),
        const Color(0xFF2A8E9E),
      ],
    };

    if (brightness == Brightness.light) {
      return colors;
    }

    final brighten = this == AppThemeScheme.tokyoNight ? 0.08 : 0.05;
    return [
      for (final color in colors) Color.lerp(color, Colors.white, brighten)!,
    ];
  }
}

extension AppCourseColorPaletteX on AppCourseColorPalette {
  String get storageKey => switch (this) {
    AppCourseColorPalette.mildlinerNotes => 'mildliner_notes',
    AppCourseColorPalette.candyBox => 'candy_box',
    AppCourseColorPalette.jellySoda => 'jelly_soda',
    AppCourseColorPalette.tokyoNeon => 'tokyo_neon',
  };

  String get label => switch (this) {
    AppCourseColorPalette.mildlinerNotes => 'Mildliner 笔记',
    AppCourseColorPalette.candyBox => '糖果盒',
    AppCourseColorPalette.jellySoda => '果冻汽水',
    AppCourseColorPalette.tokyoNeon => 'Tokyo Neon',
  };

  String get subtitle => switch (this) {
    AppCourseColorPalette.mildlinerNotes => '柔和记号笔',
    AppCourseColorPalette.candyBox => '糖纸粉蓝橙',
    AppCourseColorPalette.jellySoda => '高辨识汽水感',
    AppCourseColorPalette.tokyoNeon => '冷色霓虹高亮',
  };

  List<Color> colors(Brightness brightness) {
    final base = switch (this) {
      AppCourseColorPalette.mildlinerNotes => <Color>[
        const Color(0xFFD38A5C),
        const Color(0xFFC9A23F),
        const Color(0xFF90A94B),
        const Color(0xFF57A79B),
        const Color(0xFF6C98CF),
        const Color(0xFF9A85D6),
        const Color(0xFFD578A0),
        const Color(0xFFB6885E),
      ],
      AppCourseColorPalette.candyBox => <Color>[
        const Color(0xFFFF7B9C),
        const Color(0xFFFFB347),
        const Color(0xFF62C770),
        const Color(0xFF58B8FF),
        const Color(0xFF9B7BFF),
        const Color(0xFFFF8A65),
        const Color(0xFF44CFBF),
        const Color(0xFFF06CC6),
      ],
      AppCourseColorPalette.jellySoda => <Color>[
        const Color(0xFFFF5D73),
        const Color(0xFFFF9F1C),
        const Color(0xFF2EC4B6),
        const Color(0xFF3A86FF),
        const Color(0xFF8338EC),
        const Color(0xFFFB5607),
        const Color(0xFF06D6A0),
        const Color(0xFF5E60CE),
      ],
      AppCourseColorPalette.tokyoNeon => <Color>[
        const Color(0xFF4C6EF5),
        const Color(0xFF7C63FF),
        const Color(0xFF159DB2),
        const Color(0xFF2FB7A8),
        const Color(0xFF9A67EA),
        const Color(0xFF3B5CCC),
        const Color(0xFF1F8EA3),
        const Color(0xFFF4B86A),
      ],
    };

    if (brightness == Brightness.light) {
      return base;
    }

    final boost = this == AppCourseColorPalette.tokyoNeon ? 0.06 : 0.04;
    return [for (final color in base) Color.lerp(color, Colors.white, boost)!];
  }

  int get colorCount => colors(Brightness.light).length;

  List<Color> preview(Brightness brightness) =>
      colors(brightness).take(4).toList();

  String colorToken(int index) => buildCourseColorToken(index % colorCount);

  String autoColorToken(String seed) =>
      buildCourseColorToken(stableCourseColorIndex(seed, colorCount));
}

String buildCourseColorToken(int index) => '$_courseColorTokenPrefix$index';

int? parseCourseColorToken(String? value) {
  if (value == null || !value.startsWith(_courseColorTokenPrefix)) {
    return null;
  }
  return int.tryParse(value.substring(_courseColorTokenPrefix.length));
}

int stableCourseColorIndex(String seed, int length) {
  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return length == 0 ? 0 : hash % length;
}

String buildCourseColorSeed(String courseName, String teacher) {
  String normalize(String value) => value.trim().toLowerCase();
  return '${normalize(courseName)}|${normalize(teacher)}';
}

int? resolveCourseColorSelectionIndex(String? value, int colorCount) {
  if (colorCount <= 0) return null;
  final tokenIndex = parseCourseColorToken(value);
  if (tokenIndex != null) {
    return tokenIndex % colorCount;
  }
  if (value != null) {
    final legacyIndex = kLegacyCourseColorHexes.indexWhere(
      (item) => item.toUpperCase() == value.toUpperCase(),
    );
    if (legacyIndex >= 0) {
      return legacyIndex % colorCount;
    }
  }
  return null;
}

Color resolveCourseCardColor({
  required String? colorValue,
  required AppCourseColorPalette palette,
  required Brightness brightness,
  required String seed,
}) {
  final swatches = palette.colors(brightness);
  final selectionIndex = resolveCourseColorSelectionIndex(
    colorValue,
    swatches.length,
  );
  if (selectionIndex != null) {
    return swatches[selectionIndex];
  }
  if (colorValue != null && colorValue.startsWith('#')) {
    try {
      return Color(int.parse(colorValue.replaceFirst('#', '0xFF')));
    } catch (_) {
      // Fall through to the deterministic palette color.
    }
  }
  return swatches[stableCourseColorIndex(seed, swatches.length)];
}

class AppThemeTone {
  const AppThemeTone({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surface,
    required this.scaffoldBackground,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color surface;
  final Color scaffoldBackground;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
}

@immutable
class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.headerAddContainer,
    required this.headerAddForeground,
    required this.headerImportContainer,
    required this.headerImportForeground,
    required this.headerExportContainer,
    required this.headerExportForeground,
    required this.headerMoreContainer,
    required this.headerMoreForeground,
    required this.floatingSheetSurface,
    required this.floatingSheetShadow,
    required this.floatingSheetAction,
    required this.weekStripBackground,
    required this.weekStripAccent,
    required this.weekStripThumb,
    required this.currentScheduleGradientStart,
    required this.currentScheduleGradientEnd,
    required this.toolSettingColor,
    required this.toolHelpColor,
    required this.toolAboutColor,
    required this.toolGlobalColor,
    required this.aboutGradientStart,
    required this.aboutGradientEnd,
    required this.gridMinorText,
    required this.gridTodayText,
    required this.gridOutOfTermText,
    required this.gridLineColor,
    required this.courseTextShadow,
    required this.courseOutline,
    required this.nonCurrentCourseLabel,
    required this.virtualCourseFill,
    required this.backgroundImageOverlay,
    required this.nonCurrentCourseAlpha,
  });

  final Color headerAddContainer;
  final Color headerAddForeground;
  final Color headerImportContainer;
  final Color headerImportForeground;
  final Color headerExportContainer;
  final Color headerExportForeground;
  final Color headerMoreContainer;
  final Color headerMoreForeground;
  final Color floatingSheetSurface;
  final Color floatingSheetShadow;
  final Color floatingSheetAction;
  final Color weekStripBackground;
  final Color weekStripAccent;
  final Color weekStripThumb;
  final Color currentScheduleGradientStart;
  final Color currentScheduleGradientEnd;
  final Color toolSettingColor;
  final Color toolHelpColor;
  final Color toolAboutColor;
  final Color toolGlobalColor;
  final Color aboutGradientStart;
  final Color aboutGradientEnd;
  final Color gridMinorText;
  final Color gridTodayText;
  final Color gridOutOfTermText;
  final Color gridLineColor;
  final Color courseTextShadow;
  final Color courseOutline;
  final Color nonCurrentCourseLabel;
  final Color virtualCourseFill;
  final Color backgroundImageOverlay;
  final double nonCurrentCourseAlpha;

  factory AppThemePalette.fromTone(
    AppThemeScheme scheme,
    AppThemeTone tone,
    Brightness brightness,
  ) {
    final isTokyoNight = scheme == AppThemeScheme.tokyoNight;
    final moreBase = isTokyoNight
        ? Color.lerp(tone.secondary, tone.tertiary, 0.34)!
        : Color.lerp(tone.primary, tone.secondary, 0.45)!;
    final actionBlend = isTokyoNight
        ? (brightness == Brightness.light ? 0.54 : 0.44)
        : (brightness == Brightness.light ? 0.72 : 0.7);
    final actionTarget = isTokyoNight && brightness == Brightness.dark
        ? tone.surfaceContainerHighest
        : brightness == Brightness.light
        ? tone.surface
        : Colors.black;
    final weekStripBackground = isTokyoNight
        ? (brightness == Brightness.light
              ? Color.lerp(tone.primary, tone.surface, 0.7)!
              : Color.lerp(tone.primary, tone.surfaceContainerHighest, 0.38)!)
        : brightness == Brightness.light
        ? Color.lerp(tone.primary, tone.surface, 0.82)!
        : Color.lerp(tone.primary, tone.surfaceContainerHighest, 0.55)!;
    final weekStripAccent = isTokyoNight
        ? (brightness == Brightness.light
              ? Color.lerp(tone.primary, Colors.black, 0.08)!
              : Color.lerp(tone.primary, Colors.white, 0.14)!)
        : brightness == Brightness.light
        ? Color.lerp(tone.primary, Colors.black, 0.18)!
        : Color.lerp(tone.primary, Colors.white, 0.08)!;
    final weekStripThumb = isTokyoNight
        ? (brightness == Brightness.light
              ? Color.lerp(tone.primary, tone.onSurfaceVariant, 0.38)!
              : Color.lerp(tone.primary, Colors.white, 0.18)!)
        : brightness == Brightness.light
        ? Color.lerp(tone.primary, tone.onSurfaceVariant, 0.55)!
        : Color.lerp(tone.primary, Colors.white, 0.35)!;
    final gradientStart = isTokyoNight
        ? (brightness == Brightness.light
              ? Color.lerp(tone.secondary, tone.primary, 0.56)!
              : Color.lerp(tone.secondary, tone.primary, 0.38)!)
        : brightness == Brightness.light
        ? Color.lerp(tone.primary, tone.surface, 0.35)!
        : Color.lerp(tone.primary, Colors.white, 0.12)!;
    final gradientEnd = isTokyoNight
        ? (brightness == Brightness.light
              ? Color.lerp(tone.tertiary, tone.primary, 0.18)!
              : Color.lerp(tone.primary, tone.tertiary, 0.14)!)
        : brightness == Brightness.light
        ? tone.primary
        : Color.lerp(tone.primary, tone.surface, 0.22)!;
    final toolBlend = isTokyoNight ? 0.34 : 0.18;

    return AppThemePalette(
      headerAddContainer: _actionBackground(
        tone.secondary,
        actionTarget,
        brightness,
        blend: actionBlend,
      ),
      headerAddForeground: _actionForeground(tone.secondary, brightness),
      headerImportContainer: _actionBackground(
        tone.primary,
        actionTarget,
        brightness,
        blend: actionBlend,
      ),
      headerImportForeground: _actionForeground(tone.primary, brightness),
      headerExportContainer: _actionBackground(
        tone.tertiary,
        actionTarget,
        brightness,
        blend: actionBlend,
      ),
      headerExportForeground: _actionForeground(tone.tertiary, brightness),
      headerMoreContainer: _actionBackground(
        moreBase,
        actionTarget,
        brightness,
        blend: actionBlend,
      ),
      headerMoreForeground: _actionForeground(moreBase, brightness),
      floatingSheetSurface: brightness == Brightness.light
          ? (isTokyoNight ? tone.surface : Colors.white)
          : (isTokyoNight
                ? Color.lerp(tone.surfaceContainerHighest, tone.surface, 0.18)!
                : tone.surfaceContainerHighest),
      floatingSheetShadow: Colors.black.withValues(
        alpha: isTokyoNight
            ? (brightness == Brightness.light ? 0.12 : 0.36)
            : (brightness == Brightness.light ? 0.08 : 0.28),
      ),
      floatingSheetAction: Color.lerp(
        tone.onSurfaceVariant,
        tone.primary,
        isTokyoNight
            ? (brightness == Brightness.light ? 0.42 : 0.24)
            : (brightness == Brightness.light ? 0.25 : 0.12),
      )!,
      weekStripBackground: weekStripBackground,
      weekStripAccent: weekStripAccent,
      weekStripThumb: weekStripThumb,
      currentScheduleGradientStart: gradientStart,
      currentScheduleGradientEnd: gradientEnd,
      toolSettingColor: Color.lerp(tone.onSurface, tone.primary, toolBlend)!,
      toolHelpColor: Color.lerp(tone.onSurface, tone.secondary, toolBlend)!,
      toolAboutColor: Color.lerp(tone.onSurface, moreBase, toolBlend + 0.02)!,
      toolGlobalColor: Color.lerp(tone.onSurface, tone.tertiary, toolBlend)!,
      aboutGradientStart: isTokyoNight ? tone.secondary : tone.primary,
      aboutGradientEnd: isTokyoNight ? tone.primary : tone.secondary,
      gridMinorText: isTokyoNight
          ? Color.lerp(tone.onSurfaceVariant, tone.onSurface, 0.16)!
          : tone.onSurfaceVariant,
      gridTodayText: isTokyoNight
          ? tone.tertiary
          : Color.lerp(tone.primary, tone.secondary, 0.18)!,
      gridOutOfTermText: isTokyoNight
          ? const Color(0xFFFF8E8E)
          : const Color(0xFFE06161),
      gridLineColor: isTokyoNight
          ? tone.outlineVariant.withValues(alpha: 0.9)
          : tone.outlineVariant.withValues(alpha: 0.62),
      courseTextShadow: isTokyoNight
          ? Colors.black.withValues(alpha: 0.44)
          : Colors.black.withValues(alpha: 0.18),
      courseOutline: isTokyoNight ? const Color(0xFF0D111B) : Colors.black,
      nonCurrentCourseLabel: isTokyoNight
          ? const Color(0xFFCBD6FF)
          : Colors.white.withValues(alpha: 0.72),
      virtualCourseFill: isTokyoNight
          ? const Color(0xFF5A627D)
          : const Color(0xFFD8DDE7),
      backgroundImageOverlay: brightness == Brightness.light
          ? Colors.white
          : (isTokyoNight ? const Color(0xFF0B0D13) : Colors.black),
      nonCurrentCourseAlpha: isTokyoNight
          ? (brightness == Brightness.light ? 0.38 : 0.48)
          : (brightness == Brightness.light ? 0.3 : 0.34),
    );
  }

  @override
  AppThemePalette copyWith({
    Color? headerAddContainer,
    Color? headerAddForeground,
    Color? headerImportContainer,
    Color? headerImportForeground,
    Color? headerExportContainer,
    Color? headerExportForeground,
    Color? headerMoreContainer,
    Color? headerMoreForeground,
    Color? floatingSheetSurface,
    Color? floatingSheetShadow,
    Color? floatingSheetAction,
    Color? weekStripBackground,
    Color? weekStripAccent,
    Color? weekStripThumb,
    Color? currentScheduleGradientStart,
    Color? currentScheduleGradientEnd,
    Color? toolSettingColor,
    Color? toolHelpColor,
    Color? toolAboutColor,
    Color? toolGlobalColor,
    Color? aboutGradientStart,
    Color? aboutGradientEnd,
    Color? gridMinorText,
    Color? gridTodayText,
    Color? gridOutOfTermText,
    Color? gridLineColor,
    Color? courseTextShadow,
    Color? courseOutline,
    Color? nonCurrentCourseLabel,
    Color? virtualCourseFill,
    Color? backgroundImageOverlay,
    double? nonCurrentCourseAlpha,
  }) {
    return AppThemePalette(
      headerAddContainer: headerAddContainer ?? this.headerAddContainer,
      headerAddForeground: headerAddForeground ?? this.headerAddForeground,
      headerImportContainer:
          headerImportContainer ?? this.headerImportContainer,
      headerImportForeground:
          headerImportForeground ?? this.headerImportForeground,
      headerExportContainer:
          headerExportContainer ?? this.headerExportContainer,
      headerExportForeground:
          headerExportForeground ?? this.headerExportForeground,
      headerMoreContainer: headerMoreContainer ?? this.headerMoreContainer,
      headerMoreForeground: headerMoreForeground ?? this.headerMoreForeground,
      floatingSheetSurface: floatingSheetSurface ?? this.floatingSheetSurface,
      floatingSheetShadow: floatingSheetShadow ?? this.floatingSheetShadow,
      floatingSheetAction: floatingSheetAction ?? this.floatingSheetAction,
      weekStripBackground: weekStripBackground ?? this.weekStripBackground,
      weekStripAccent: weekStripAccent ?? this.weekStripAccent,
      weekStripThumb: weekStripThumb ?? this.weekStripThumb,
      currentScheduleGradientStart:
          currentScheduleGradientStart ?? this.currentScheduleGradientStart,
      currentScheduleGradientEnd:
          currentScheduleGradientEnd ?? this.currentScheduleGradientEnd,
      toolSettingColor: toolSettingColor ?? this.toolSettingColor,
      toolHelpColor: toolHelpColor ?? this.toolHelpColor,
      toolAboutColor: toolAboutColor ?? this.toolAboutColor,
      toolGlobalColor: toolGlobalColor ?? this.toolGlobalColor,
      aboutGradientStart: aboutGradientStart ?? this.aboutGradientStart,
      aboutGradientEnd: aboutGradientEnd ?? this.aboutGradientEnd,
      gridMinorText: gridMinorText ?? this.gridMinorText,
      gridTodayText: gridTodayText ?? this.gridTodayText,
      gridOutOfTermText: gridOutOfTermText ?? this.gridOutOfTermText,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      courseTextShadow: courseTextShadow ?? this.courseTextShadow,
      courseOutline: courseOutline ?? this.courseOutline,
      nonCurrentCourseLabel:
          nonCurrentCourseLabel ?? this.nonCurrentCourseLabel,
      virtualCourseFill: virtualCourseFill ?? this.virtualCourseFill,
      backgroundImageOverlay:
          backgroundImageOverlay ?? this.backgroundImageOverlay,
      nonCurrentCourseAlpha:
          nonCurrentCourseAlpha ?? this.nonCurrentCourseAlpha,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) {
      return this;
    }

    return AppThemePalette(
      headerAddContainer: Color.lerp(
        headerAddContainer,
        other.headerAddContainer,
        t,
      )!,
      headerAddForeground: Color.lerp(
        headerAddForeground,
        other.headerAddForeground,
        t,
      )!,
      headerImportContainer: Color.lerp(
        headerImportContainer,
        other.headerImportContainer,
        t,
      )!,
      headerImportForeground: Color.lerp(
        headerImportForeground,
        other.headerImportForeground,
        t,
      )!,
      headerExportContainer: Color.lerp(
        headerExportContainer,
        other.headerExportContainer,
        t,
      )!,
      headerExportForeground: Color.lerp(
        headerExportForeground,
        other.headerExportForeground,
        t,
      )!,
      headerMoreContainer: Color.lerp(
        headerMoreContainer,
        other.headerMoreContainer,
        t,
      )!,
      headerMoreForeground: Color.lerp(
        headerMoreForeground,
        other.headerMoreForeground,
        t,
      )!,
      floatingSheetSurface: Color.lerp(
        floatingSheetSurface,
        other.floatingSheetSurface,
        t,
      )!,
      floatingSheetShadow: Color.lerp(
        floatingSheetShadow,
        other.floatingSheetShadow,
        t,
      )!,
      floatingSheetAction: Color.lerp(
        floatingSheetAction,
        other.floatingSheetAction,
        t,
      )!,
      weekStripBackground: Color.lerp(
        weekStripBackground,
        other.weekStripBackground,
        t,
      )!,
      weekStripAccent: Color.lerp(weekStripAccent, other.weekStripAccent, t)!,
      weekStripThumb: Color.lerp(weekStripThumb, other.weekStripThumb, t)!,
      currentScheduleGradientStart: Color.lerp(
        currentScheduleGradientStart,
        other.currentScheduleGradientStart,
        t,
      )!,
      currentScheduleGradientEnd: Color.lerp(
        currentScheduleGradientEnd,
        other.currentScheduleGradientEnd,
        t,
      )!,
      toolSettingColor: Color.lerp(
        toolSettingColor,
        other.toolSettingColor,
        t,
      )!,
      toolHelpColor: Color.lerp(toolHelpColor, other.toolHelpColor, t)!,
      toolAboutColor: Color.lerp(toolAboutColor, other.toolAboutColor, t)!,
      toolGlobalColor: Color.lerp(toolGlobalColor, other.toolGlobalColor, t)!,
      aboutGradientStart: Color.lerp(
        aboutGradientStart,
        other.aboutGradientStart,
        t,
      )!,
      aboutGradientEnd: Color.lerp(
        aboutGradientEnd,
        other.aboutGradientEnd,
        t,
      )!,
      gridMinorText: Color.lerp(gridMinorText, other.gridMinorText, t)!,
      gridTodayText: Color.lerp(gridTodayText, other.gridTodayText, t)!,
      gridOutOfTermText: Color.lerp(
        gridOutOfTermText,
        other.gridOutOfTermText,
        t,
      )!,
      gridLineColor: Color.lerp(gridLineColor, other.gridLineColor, t)!,
      courseTextShadow: Color.lerp(
        courseTextShadow,
        other.courseTextShadow,
        t,
      )!,
      courseOutline: Color.lerp(courseOutline, other.courseOutline, t)!,
      nonCurrentCourseLabel: Color.lerp(
        nonCurrentCourseLabel,
        other.nonCurrentCourseLabel,
        t,
      )!,
      virtualCourseFill: Color.lerp(
        virtualCourseFill,
        other.virtualCourseFill,
        t,
      )!,
      backgroundImageOverlay: Color.lerp(
        backgroundImageOverlay,
        other.backgroundImageOverlay,
        t,
      )!,
      nonCurrentCourseAlpha: lerpDouble(
        nonCurrentCourseAlpha,
        other.nonCurrentCourseAlpha,
        t,
      )!,
    );
  }
}

extension AppThemeBuildContext on BuildContext {
  AppThemePalette get appTheme => Theme.of(this).extension<AppThemePalette>()!;
}

ThemeData buildAppTheme(AppThemeScheme scheme, Brightness brightness) {
  final tone = scheme.resolve(brightness);
  final palette = AppThemePalette.fromTone(scheme, tone, brightness);
  final baseScheme = ColorScheme.fromSeed(
    seedColor: tone.primary,
    brightness: brightness,
  );

  final colorScheme = baseScheme.copyWith(
    primary: tone.primary,
    onPrimary: _onColor(tone.primary),
    primaryContainer: _containerColor(scheme, tone.primary, brightness),
    onPrimaryContainer: _onColor(
      _containerColor(scheme, tone.primary, brightness),
    ),
    secondary: tone.secondary,
    onSecondary: _onColor(tone.secondary),
    secondaryContainer: _containerColor(scheme, tone.secondary, brightness),
    onSecondaryContainer: _onColor(
      _containerColor(scheme, tone.secondary, brightness),
    ),
    tertiary: tone.tertiary,
    onTertiary: _onColor(tone.tertiary),
    tertiaryContainer: _containerColor(scheme, tone.tertiary, brightness),
    onTertiaryContainer: _onColor(
      _containerColor(scheme, tone.tertiary, brightness),
    ),
    surface: tone.surface,
    onSurface: tone.onSurface,
    onSurfaceVariant: tone.onSurfaceVariant,
    outlineVariant: tone.outlineVariant,
    surfaceContainerHighest: tone.surfaceContainerHighest,
    surfaceContainerHigh: Color.lerp(
      tone.surface,
      tone.surfaceContainerHighest,
      0.72,
    )!,
    surfaceContainer: Color.lerp(
      tone.surface,
      tone.surfaceContainerHighest,
      0.56,
    )!,
    surfaceContainerLow: Color.lerp(
      tone.surface,
      tone.surfaceContainerHighest,
      0.32,
    )!,
    surfaceContainerLowest: tone.surface,
  );

  final theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tone.scaffoldBackground,
  );

  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.surface,
      contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    extensions: [palette],
  );
}

Color _containerColor(
  AppThemeScheme scheme,
  Color color,
  Brightness brightness,
) {
  final isTokyoNight = scheme == AppThemeScheme.tokyoNight;
  return brightness == Brightness.light
      ? Color.lerp(color, Colors.white, isTokyoNight ? 0.66 : 0.78)!
      : Color.lerp(color, Colors.black, isTokyoNight ? 0.48 : 0.6)!;
}

Color _actionBackground(
  Color accent,
  Color target,
  Brightness brightness, {
  required double blend,
}) {
  return Color.lerp(accent, target, blend)!;
}

Color _actionForeground(Color color, Brightness brightness) {
  return brightness == Brightness.light
      ? Color.lerp(color, Colors.black, 0.28)!
      : Color.lerp(color, Colors.white, 0.22)!;
}

Color _onColor(Color color) {
  return color.computeLuminance() > 0.45
      ? const Color(0xFF151823)
      : Colors.white;
}

const AppThemeTone _morningMistLight = AppThemeTone(
  primary: Color(0xFF7E96F0),
  secondary: Color(0xFF62D3C7),
  tertiary: Color(0xFFF4B86A),
  surface: Color(0xFFFFFFFF),
  scaffoldBackground: Color(0xFFF5F7FF),
  surfaceContainerHighest: Color(0xFFE8EDF9),
  onSurface: Color(0xFF1B2238),
  onSurfaceVariant: Color(0xFF66708A),
  outlineVariant: Color(0xFFD1D9EA),
);

const AppThemeTone _morningMistDark = AppThemeTone(
  primary: Color(0xFF9EB2FF),
  secondary: Color(0xFF70E0D4),
  tertiary: Color(0xFFFFC77D),
  surface: Color(0xFF1B2133),
  scaffoldBackground: Color(0xFF121725),
  surfaceContainerHighest: Color(0xFF252C42),
  onSurface: Color(0xFFE8ECF8),
  onSurfaceVariant: Color(0xFFABB4CE),
  outlineVariant: Color(0xFF3A435E),
);

const AppThemeTone _springBudLight = AppThemeTone(
  primary: Color(0xFF58B889),
  secondary: Color(0xFF8AD7C2),
  tertiary: Color(0xFFF0C66E),
  surface: Color(0xFFFFFDFB),
  scaffoldBackground: Color(0xFFF6FBF7),
  surfaceContainerHighest: Color(0xFFE4F1E8),
  onSurface: Color(0xFF1A3026),
  onSurfaceVariant: Color(0xFF587266),
  outlineVariant: Color(0xFFCFE2D8),
);

const AppThemeTone _springBudDark = AppThemeTone(
  primary: Color(0xFF7ED1A4),
  secondary: Color(0xFF6ECBB6),
  tertiary: Color(0xFFE3BC6A),
  surface: Color(0xFF16231C),
  scaffoldBackground: Color(0xFF101813),
  surfaceContainerHighest: Color(0xFF24372E),
  onSurface: Color(0xFFE6F3EC),
  onSurfaceVariant: Color(0xFFA4C2B4),
  outlineVariant: Color(0xFF385046),
);

const AppThemeTone _apricotGlowLight = AppThemeTone(
  primary: Color(0xFFE59A5C),
  secondary: Color(0xFFF3C789),
  tertiary: Color(0xFFD96B6B),
  surface: Color(0xFFFFFEFC),
  scaffoldBackground: Color(0xFFFFF8F1),
  surfaceContainerHighest: Color(0xFFF7EADF),
  onSurface: Color(0xFF362313),
  onSurfaceVariant: Color(0xFF7A6352),
  outlineVariant: Color(0xFFE7D6C8),
);

const AppThemeTone _apricotGlowDark = AppThemeTone(
  primary: Color(0xFFF0AF78),
  secondary: Color(0xFFE6C08E),
  tertiary: Color(0xFFE48B8B),
  surface: Color(0xFF241810),
  scaffoldBackground: Color(0xFF19110B),
  surfaceContainerHighest: Color(0xFF38281C),
  onSurface: Color(0xFFF8ECE3),
  onSurfaceVariant: Color(0xFFCBB3A2),
  outlineVariant: Color(0xFF564437),
);

const AppThemeTone _sakuraMistLight = AppThemeTone(
  primary: Color(0xFFD98AA4),
  secondary: Color(0xFFA59AE6),
  tertiary: Color(0xFF6FC8C2),
  surface: Color(0xFFFFFFFF),
  scaffoldBackground: Color(0xFFFFF6F8),
  surfaceContainerHighest: Color(0xFFF5E7ED),
  onSurface: Color(0xFF36212B),
  onSurfaceVariant: Color(0xFF7D6370),
  outlineVariant: Color(0xFFE7D5DD),
);

const AppThemeTone _sakuraMistDark = AppThemeTone(
  primary: Color(0xFFE2A5BA),
  secondary: Color(0xFFB7AEF1),
  tertiary: Color(0xFF7CD5CF),
  surface: Color(0xFF241821),
  scaffoldBackground: Color(0xFF191118),
  surfaceContainerHighest: Color(0xFF382934),
  onSurface: Color(0xFFF8EAF0),
  onSurfaceVariant: Color(0xFFC7AFBA),
  outlineVariant: Color(0xFF5A4450),
);

const AppThemeTone _tokyoDayLight = AppThemeTone(
  primary: Color(0xFF4C6EF5),
  secondary: Color(0xFF7C63FF),
  tertiary: Color(0xFF159DB2),
  surface: Color(0xFFF9FBFF),
  scaffoldBackground: Color(0xFFEDEFF6),
  surfaceContainerHighest: Color(0xFFD8DEEC),
  onSurface: Color(0xFF161B2C),
  onSurfaceVariant: Color(0xFF4F5A77),
  outlineVariant: Color(0xFFBEC7DA),
);

const AppThemeTone _tokyoNightDark = AppThemeTone(
  primary: Color(0xFF82AAFF),
  secondary: Color(0xFFC099FF),
  tertiary: Color(0xFF41C7D9),
  surface: Color(0xFF16161E),
  scaffoldBackground: Color(0xFF0F1117),
  surfaceContainerHighest: Color(0xFF1F2335),
  onSurface: Color(0xFFC8D3F5),
  onSurfaceVariant: Color(0xFF7D8AB3),
  outlineVariant: Color(0xFF2E3550),
);
