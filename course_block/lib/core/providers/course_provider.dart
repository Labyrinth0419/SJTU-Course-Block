import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/models/schedule.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/course_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../utils/time_slots.dart';
import '../services/calendar_service.dart';
import 'package:share_plus/share_plus.dart';
import '../services/widget_sync_service.dart';

class CourseProvider extends ChangeNotifier {
  static const String defaultScheduleName = '默认课表';
  static const String _themeModeKey = 'theme_mode';
  static const String _themeSchemeKey = 'theme_scheme';
  static const String _courseColorPaletteKey = 'course_color_palette';
  static const String _launcherIconKey = 'app_icon_choice';

  static const String _showGridLinesKey = 'show_grid_lines';
  static const String _showNonCurrentWeekKey = 'show_non_current_week';
  static const String _showSaturdayKey = 'show_saturday';
  static const String _showSundayKey = 'show_sunday';
  static const String _outlineTextKey = 'outline_text';
  static const String _maxDailyClassesKey = 'max_daily_classes';
  static const String _totalWeeksKey = 'total_weeks';
  static const String _gridHeightKey = 'grid_height';
  static const String _cornerRadiusKey = 'corner_radius';
  static const String _backgroundColorLightKey = 'background_color_light';
  static const String _backgroundColorDarkKey = 'background_color_dark';
  static const String _backgroundImagePathKey = 'background_image_path';
  static const String _backgroundImageOpacityKey = 'background_image_opacity';
  static const List<String> _scheduleSettingKeys = [
    _showGridLinesKey,
    _showNonCurrentWeekKey,
    _showSaturdayKey,
    _showSundayKey,
    _outlineTextKey,
    _maxDailyClassesKey,
    _totalWeeksKey,
    _gridHeightKey,
    _cornerRadiusKey,
    _backgroundColorLightKey,
    _backgroundColorDarkKey,
    _backgroundImagePathKey,
    _backgroundImageOpacityKey,
  ];

  List<Course> _courses = [];
  List<Schedule> _schedules = [];
  Schedule? _currentSchedule;
  bool _isLoading = false;
  int _currentWeek = 1; // Displayed week

  bool _showGridLines = true;
  bool _showNonCurrentWeek = false;
  bool _showSaturday = true;
  bool _showSunday = true;
  bool _outlineText = false;
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeScheme _themeScheme = AppThemeScheme.morningMist;
  AppCourseColorPalette _courseColorPalette = AppCourseColorPalette.candyBox;
  int _maxDailyClasses = 14;
  int _totalWeeks = 20;
  double _gridHeight = 64.0;
  double _cornerRadius = 4.0;
  int? _backgroundColorLight;
  int? _backgroundColorDark;
  String? _backgroundImagePath;
  double _backgroundImageOpacity = 0.3;

  List<Course> get courses => _courses;
  List<Schedule> get schedules => _schedules;
  Schedule? get currentSchedule => _currentSchedule;
  bool get isLoading => _isLoading;
  int get currentWeek => _currentWeek;
  bool get requiresSyncTermSelection {
    final schedule = _currentSchedule;
    if (schedule == null) return true;

    final isDefaultPlaceholder =
        schedule.name == defaultScheduleName &&
        _schedules.length <= 1 &&
        _courses.isEmpty;
    return isDefaultPlaceholder;
  }

  bool get showGridLines => _showGridLines;
  bool get showNonCurrentWeek => _showNonCurrentWeek;
  bool get showSaturday => _showSaturday;
  bool get showSunday => _showSunday;
  bool get outlineText => _outlineText;
  ThemeMode get themeMode => _themeMode;
  AppThemeScheme get themeScheme => _themeScheme;
  AppCourseColorPalette get courseColorPalette => _courseColorPalette;
  int get maxDailyClasses => _maxDailyClasses;
  int get totalWeeks => _totalWeeks;
  double get gridHeight => _gridHeight;
  double get cornerRadius => _cornerRadius;
  Color? get backgroundColorLight =>
      _backgroundColorLight != null ? Color(_backgroundColorLight!) : null;
  Color? get backgroundColorDark =>
      _backgroundColorDark != null ? Color(_backgroundColorDark!) : null;
  String? get backgroundImagePath => _backgroundImagePath;
  double get backgroundImageOpacity => _backgroundImageOpacity;

  String? _launcherIcon;
  String? get launcherIcon => _launcherIcon;

  /// Scan assets/icons/* directory for alternate launcher icons.
  ///
  /// Uses the official AssetManifest API that handles both JSON and binary
  /// formats; no manual decoding required.
  Future<List<String>> getAvailableLauncherIcons() async {
    final names = <String>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final key in manifest.listAssets()) {
        if (key.startsWith('assets/icons/') || key.startsWith('assets/icon/')) {
          final iconName = p.basenameWithoutExtension(key);
          if (iconName == 'ic_launcher') continue; // skip default
          names.add(iconName);
        }
      }
    } catch (e) {
      debugPrint('Error loading AssetManifest: $e');
    }
    return names.toList();
  }

  final CourseService _courseService = CourseService();
  final CalendarService _calendarService = CalendarService();

  CourseProvider() {
    _loadAppSettings();
  }

  String _schedulePrefKey(int scheduleId, String key) =>
      'schedule_${scheduleId}_$key';

  bool _isAppSettingKey(String key) =>
      key == _themeModeKey ||
      key == _themeSchemeKey ||
      key == _courseColorPaletteKey ||
      key == _launcherIconKey;

  void _clampCurrentWeek() {
    if (_currentWeek < 1) {
      _currentWeek = 1;
    }
    if (_currentWeek > _totalWeeks) {
      _currentWeek = _totalWeeks;
    }
  }

  void _recalculateWeekFromCurrentSchedule() {
    final schedule = _currentSchedule;
    if (schedule == null) {
      _currentWeek = 1;
      return;
    }

    final diff = normalizeDate(
      DateTime.now(),
    ).difference(normalizeDate(schedule.startDate)).inDays;
    _currentWeek = (diff / 7).floor() + 1;
    _clampCurrentWeek();
  }

  void _resetScheduleSettings() {
    _showGridLines = true;
    _showNonCurrentWeek = false;
    _showSaturday = true;
    _showSunday = true;
    _outlineText = false;
    _maxDailyClasses = 14;
    _totalWeeks = 20;
    _gridHeight = 64.0;
    _cornerRadius = 4.0;
    _backgroundColorLight = null;
    _backgroundColorDark = null;
    _backgroundImagePath = null;
    _backgroundImageOpacity = 0.3;
  }

  Future<void> _seedCurrentScheduleSettings(int targetScheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _schedulePrefKey(targetScheduleId, _showGridLinesKey),
      _showGridLines,
    );
    await prefs.setBool(
      _schedulePrefKey(targetScheduleId, _showNonCurrentWeekKey),
      _showNonCurrentWeek,
    );
    await prefs.setBool(
      _schedulePrefKey(targetScheduleId, _showSaturdayKey),
      _showSaturday,
    );
    await prefs.setBool(
      _schedulePrefKey(targetScheduleId, _showSundayKey),
      _showSunday,
    );
    await prefs.setBool(
      _schedulePrefKey(targetScheduleId, _outlineTextKey),
      _outlineText,
    );
    await prefs.setInt(
      _schedulePrefKey(targetScheduleId, _maxDailyClassesKey),
      _maxDailyClasses,
    );
    await prefs.setInt(
      _schedulePrefKey(targetScheduleId, _totalWeeksKey),
      _totalWeeks,
    );
    await prefs.setDouble(
      _schedulePrefKey(targetScheduleId, _gridHeightKey),
      _gridHeight,
    );
    await prefs.setDouble(
      _schedulePrefKey(targetScheduleId, _cornerRadiusKey),
      _cornerRadius,
    );
    await prefs.setDouble(
      _schedulePrefKey(targetScheduleId, _backgroundImageOpacityKey),
      _backgroundImageOpacity,
    );

    if (_backgroundColorLight != null) {
      await prefs.setInt(
        _schedulePrefKey(targetScheduleId, _backgroundColorLightKey),
        _backgroundColorLight!,
      );
    }
    if (_backgroundColorDark != null) {
      await prefs.setInt(
        _schedulePrefKey(targetScheduleId, _backgroundColorDarkKey),
        _backgroundColorDark!,
      );
    }
    if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty) {
      await prefs.setString(
        _schedulePrefKey(targetScheduleId, _backgroundImagePathKey),
        _backgroundImagePath!,
      );
    }
  }

  Future<void> _deleteScheduleSettings(int scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _scheduleSettingKeys) {
      await prefs.remove(_schedulePrefKey(scheduleId, key));
    }
  }

  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _launcherIcon = prefs.getString(_launcherIconKey);
    if (_launcherIcon != null) {
      _applyLauncherIcon(_launcherIcon);
    }
    _themeScheme = appThemeSchemeFromStorage(prefs.getString(_themeSchemeKey));
    _courseColorPalette = appCourseColorPaletteFromStorage(
      prefs.getString(_courseColorPaletteKey),
    );
    final mode = prefs.getString(_themeModeKey);
    switch (mode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _loadCurrentScheduleSettings({
    SharedPreferences? prefs,
    bool notify = true,
  }) async {
    final scheduleId = _currentSchedule?.id;
    if (scheduleId == null) {
      _resetScheduleSettings();
      if (notify) {
        notifyListeners();
      }
      return;
    }

    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    _showGridLines =
        resolvedPrefs.getBool(
          _schedulePrefKey(scheduleId, _showGridLinesKey),
        ) ??
        resolvedPrefs.getBool(_showGridLinesKey) ??
        true;
    _showNonCurrentWeek =
        resolvedPrefs.getBool(
          _schedulePrefKey(scheduleId, _showNonCurrentWeekKey),
        ) ??
        resolvedPrefs.getBool(_showNonCurrentWeekKey) ??
        false;
    _showSaturday =
        resolvedPrefs.getBool(_schedulePrefKey(scheduleId, _showSaturdayKey)) ??
        resolvedPrefs.getBool(_showSaturdayKey) ??
        true;
    _showSunday =
        resolvedPrefs.getBool(_schedulePrefKey(scheduleId, _showSundayKey)) ??
        resolvedPrefs.getBool(_showSundayKey) ??
        true;
    _outlineText =
        resolvedPrefs.getBool(_schedulePrefKey(scheduleId, _outlineTextKey)) ??
        resolvedPrefs.getBool(_outlineTextKey) ??
        false;
    _maxDailyClasses =
        resolvedPrefs.getInt(
          _schedulePrefKey(scheduleId, _maxDailyClassesKey),
        ) ??
        resolvedPrefs.getInt(_maxDailyClassesKey) ??
        14;
    _totalWeeks =
        resolvedPrefs.getInt(_schedulePrefKey(scheduleId, _totalWeeksKey)) ??
        resolvedPrefs.getInt(_totalWeeksKey) ??
        20;
    _gridHeight =
        resolvedPrefs.getDouble(_schedulePrefKey(scheduleId, _gridHeightKey)) ??
        resolvedPrefs.getDouble(_gridHeightKey) ??
        64.0;
    _cornerRadius =
        resolvedPrefs.getDouble(
          _schedulePrefKey(scheduleId, _cornerRadiusKey),
        ) ??
        resolvedPrefs.getDouble(_cornerRadiusKey) ??
        4.0;
    _backgroundColorLight =
        resolvedPrefs.getInt(
          _schedulePrefKey(scheduleId, _backgroundColorLightKey),
        ) ??
        resolvedPrefs.getInt(_backgroundColorLightKey);
    _backgroundColorDark =
        resolvedPrefs.getInt(
          _schedulePrefKey(scheduleId, _backgroundColorDarkKey),
        ) ??
        resolvedPrefs.getInt(_backgroundColorDarkKey);
    _backgroundImagePath =
        resolvedPrefs.getString(
          _schedulePrefKey(scheduleId, _backgroundImagePathKey),
        ) ??
        resolvedPrefs.getString(_backgroundImagePathKey);
    _backgroundImageOpacity =
        resolvedPrefs.getDouble(
          _schedulePrefKey(scheduleId, _backgroundImageOpacityKey),
        ) ??
        resolvedPrefs.getDouble(_backgroundImageOpacityKey) ??
        0.3;
    _clampCurrentWeek();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> updateAppSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRefreshWidgets =
        key == _themeModeKey ||
        key == _themeSchemeKey ||
        key == _courseColorPaletteKey;
    if (value == null) {
      if (key == _launcherIconKey) {
        await prefs.remove(key);
        _launcherIcon = null;
        await _applyLauncherIcon(null);
      }
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == _themeModeKey) {
        switch (value) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      }
      if (key == _themeSchemeKey) {
        _themeScheme = appThemeSchemeFromStorage(value);
      }
      if (key == _courseColorPaletteKey) {
        _courseColorPalette = appCourseColorPaletteFromStorage(value);
      }
      if (key == _launcherIconKey) {
        _launcherIcon = value;
        await _applyLauncherIcon(value);
      }
    }
    notifyListeners();
    if (shouldRefreshWidgets) {
      await _updateWidgetsSafe();
    }
  }

  Future<void> updateCurrentScheduleSetting(String key, dynamic value) async {
    final scheduleId = _currentSchedule?.id;
    if (scheduleId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final resolvedKey = _schedulePrefKey(scheduleId, key);

    if (value == null) {
      if (key == _backgroundImagePathKey) {
        await prefs.remove(resolvedKey);
        _backgroundImagePath = null;
      }
    } else if (value is bool) {
      await prefs.setBool(resolvedKey, value);
      if (key == _showGridLinesKey) _showGridLines = value;
      if (key == _showNonCurrentWeekKey) _showNonCurrentWeek = value;
      if (key == _showSaturdayKey) _showSaturday = value;
      if (key == _showSundayKey) _showSunday = value;
      if (key == _outlineTextKey) _outlineText = value;
    } else if (value is int) {
      await prefs.setInt(resolvedKey, value);
      if (key == _maxDailyClassesKey) _maxDailyClasses = value;
      if (key == _totalWeeksKey) {
        _totalWeeks = value;
        _clampCurrentWeek();
      }
      if (key == _backgroundColorLightKey) _backgroundColorLight = value;
      if (key == _backgroundColorDarkKey) _backgroundColorDark = value;
    } else if (value is double) {
      await prefs.setDouble(resolvedKey, value);
      if (key == _gridHeightKey) _gridHeight = value;
      if (key == _cornerRadiusKey) _cornerRadius = value;
      if (key == _backgroundImageOpacityKey) _backgroundImageOpacity = value;
    } else if (value is String) {
      await prefs.setString(resolvedKey, value);
      if (key == _backgroundImagePathKey) _backgroundImagePath = value;
    }

    notifyListeners();
    await _updateWidgetsSafe();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    if (_isAppSettingKey(key)) {
      await updateAppSetting(key, value);
      return;
    }
    await updateCurrentScheduleSetting(key, value);
  }

  Future<void> _applyLauncherIcon(String? name) async {
    try {
      if (await FlutterDynamicIconPlus.supportsAlternateIcons) {
        final String? fullName = name == null
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

  Future<void> loadCourses({bool recalcWeek = true}) async {
    debugPrint('CourseProvider.loadCourses called');
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _schedules = await DatabaseHelper.instance.getAllSchedules();

      final oldScheduleId = _currentSchedule?.id;

      _currentSchedule = await DatabaseHelper.instance.getCurrentSchedule();

      if (_currentSchedule == null) {
        if (_schedules.isNotEmpty) {
          _currentSchedule = _schedules.first;
          await DatabaseHelper.instance.setCurrentSchedule(
            _currentSchedule!.id!,
          );
        } else {
          final now = DateTime.now();
          final today = normalizeDate(now);
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

          final defaultSchedule = Schedule(
            name: defaultScheduleName,
            year: now.year.toString(),
            term: '1',
            startDate: startOfWeek, // Starts this Monday
            isCurrent: true,
          );
          final id = await DatabaseHelper.instance.insertSchedule(
            defaultSchedule,
          );
          _currentSchedule = defaultSchedule.copyWith(id: id);
          _schedules = [_currentSchedule!];
        }
      }

      await _loadCurrentScheduleSettings(prefs: prefs, notify: false);

      if (recalcWeek || _currentSchedule?.id != oldScheduleId) {
        _recalculateWeekFromCurrentSchedule();
      }

      if (_currentSchedule != null && _currentSchedule!.id != null) {
        _courses = await DatabaseHelper.instance.getCoursesBySchedule(
          _currentSchedule!.id!,
        );
        await _normalizeCurrentScheduleCourseColors();
      } else {
        _courses = [];
      }
    } catch (e) {
      debugPrint('Error loading courses/schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidgetsSafe();
    }
  }

  String _buildScheduleName(String year, String term) => '$year-$term 学期';

  bool _usesGeneratedScheduleName(Schedule schedule) =>
      schedule.name == defaultScheduleName ||
      schedule.name == _buildScheduleName(schedule.year, schedule.term);

  void _upsertScheduleCache(Schedule schedule) {
    final index = _schedules.indexWhere((item) => item.id == schedule.id);
    if (index >= 0) {
      _schedules[index] = schedule;
      return;
    }
    _schedules = [..._schedules, schedule];
  }

  Future<void> _normalizeCurrentScheduleCourseColors() async {
    if (_courses.isEmpty) {
      return;
    }

    final assignments = assignScheduledCourseColorTokens(
      _courses.map(
        (course) => CourseColorIdentityEntry(
          identity: buildCourseColorSeed(course.courseName, course.teacher),
          colorValue: course.color,
        ),
      ),
      swatches: _courseColorPalette.colors(Brightness.light),
    );

    if (assignments.isEmpty) {
      return;
    }

    final updatedCourses = <Course>[];
    var hasChanges = false;

    for (final course in _courses) {
      final identity = buildCourseColorSeed(course.courseName, course.teacher);
      final assignedColor = assignments[identity] ?? course.color;
      final updatedCourse = assignedColor == course.color
          ? course
          : course.copyWith(color: assignedColor);

      if (updatedCourse.color != course.color) {
        hasChanges = true;
        if (updatedCourse.id != null) {
          await DatabaseHelper.instance.updateCourse(updatedCourse);
        }
      }

      updatedCourses.add(updatedCourse);
    }

    if (hasChanges) {
      _courses = updatedCourses;
    }
  }

  Future<int> syncCurrentSchedule() async {
    final schedule = _currentSchedule;
    if (schedule == null) return 0;
    return syncCourses(schedule.year, schedule.term);
  }

  Future<int> syncCourses(String year, String term) async {
    _isLoading = true;
    notifyListeners();

    try {
      var fetchedCourses = await _courseService.fetchUndergraduateCourses(
        year,
        term,
        courseColorPalette: _courseColorPalette,
      );

      if (fetchedCourses.isEmpty) {
        fetchedCourses = await _courseService.fetchGraduateCourses(
          year,
          term,
          courseColorPalette: _courseColorPalette,
        );
      }

      if (fetchedCourses.isEmpty) {
        return 0;
      }

      Schedule? targetSchedule;

      if (_currentSchedule == null) {
        final now = DateTime.now();
        final today = normalizeDate(now);
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

        final newSchedule = Schedule(
          name: '$year-$term 学期',
          year: year,
          term: term,
          startDate: startOfWeek, // Set to this week Monday as default
          isCurrent: true,
        );
        final id = await DatabaseHelper.instance.insertSchedule(newSchedule);
        targetSchedule = newSchedule.copyWith(id: id);
        _currentSchedule = targetSchedule;
        _upsertScheduleCache(targetSchedule);
        await _loadCurrentScheduleSettings(notify: false);
        _recalculateWeekFromCurrentSchedule();
      } else {
        targetSchedule = _currentSchedule!;
        if (targetSchedule.year != year || targetSchedule.term != term) {
          targetSchedule = targetSchedule.copyWith(
            year: year,
            term: term,
            name: _usesGeneratedScheduleName(targetSchedule)
                ? _buildScheduleName(year, term)
                : targetSchedule.name,
          );
          await DatabaseHelper.instance.updateSchedule(targetSchedule);
          _currentSchedule = targetSchedule;
          _upsertScheduleCache(targetSchedule);
        }
      }

      if (fetchedCourses.isNotEmpty && targetSchedule.id != null) {
        await DatabaseHelper.instance.deleteCoursesBySchedule(
          targetSchedule.id!,
        );

        final uniqueCourses = <String, Course>{};
        for (var course in fetchedCourses) {
          final key =
              '${course.courseName}_${course.teacher}_${course.dayOfWeek}_${course.startNode}_${course.startWeek}_${course.endWeek}';
          if (!uniqueCourses.containsKey(key)) {
            uniqueCourses[key] = course;
          }
        }

        for (var course in uniqueCourses.values) {
          /*
             We need to add `scheduleId` to the fetched course.
             Since `Course` is immutable, we can assume `Course.fromMap` was used in `_courseService`.
             We can just use `copy` mechanism if available, or just use naming arguments.
             Wait, `Course` doesn't have `copyWith`. I should have added it.
             I'll construct a new Course.
           */
          final newCourse = Course(
            scheduleId: targetSchedule.id,
            courseId: course.courseId,
            courseName: course.courseName,
            teacher: course.teacher,
            classRoom: course.classRoom,
            startWeek: course.startWeek,
            endWeek: course.endWeek,
            dayOfWeek: course.dayOfWeek,
            startNode: course.startNode,
            step: course.step,
            isOddWeek: course.isOddWeek,
            isEvenWeek: course.isEvenWeek,
            weekCode: course.weekCode,
            color: course.color,
          );

          await DatabaseHelper.instance.insertCourse(newCourse);
        }
        _courses = await DatabaseHelper.instance.getCoursesBySchedule(
          targetSchedule.id!,
        );
        await _normalizeCurrentScheduleCourseColors();
      }
      final count = fetchedCourses.length;
      return count;
    } catch (e) {
      debugPrint('Error syncing courses: $e');
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidgetsSafe();
    }
  }

  void setCurrentWeek(int week) {
    if (week < 1) {
      week = 1;
    }
    if (week > _totalWeeks) {
      week = _totalWeeks;
    }
    _currentWeek = week;
    notifyListeners();
  }

  Future<void> switchSchedule(int scheduleId) async {
    await DatabaseHelper.instance.setCurrentSchedule(scheduleId);
    await loadCourses(); // Reloads current schedule and courses
  }

  Future<void> addSchedule(
    String name,
    String year,
    String term, {
    DateTime? startDate,
  }) async {
    final today = normalizeDate(DateTime.now());
    final startOfWeek = startDate != null
        ? normalizeDate(startDate)
        : today.subtract(Duration(days: today.weekday - 1));
    final schedule = Schedule(
      name: name,
      year: year,
      term: term,
      startDate: startOfWeek,
      isCurrent: true, // Switch to it immediately
    );
    final newScheduleId = await DatabaseHelper.instance.insertSchedule(
      schedule,
    );
    if (_currentSchedule?.id != null) {
      await _seedCurrentScheduleSettings(newScheduleId);
    }
    await loadCourses();
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await DatabaseHelper.instance.deleteCoursesBySchedule(scheduleId);
    await DatabaseHelper.instance.deleteSchedule(scheduleId);
    await _deleteScheduleSettings(scheduleId);
    await loadCourses();
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await DatabaseHelper.instance.updateSchedule(schedule);
    await loadCourses();
  }

  Future<void> setBackgroundImage(String path) async {
    await updateCurrentScheduleSetting(_backgroundImagePathKey, path);
  }

  Future<String> exportCoursesJson([String? targetPath]) async {
    final list = _courses.map((c) => c.toMap()).toList();
    if (targetPath != null && targetPath.isNotEmpty) {
      final file = File(targetPath);
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(list));
      return file.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/course_export.json');
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(list));
    return file.path;
  }

  Future<String> exportCoursesIcs([String? targetPath]) async {
    if (_currentSchedule == null) return '';
    final ics = _generateIcs(_courses, _currentSchedule!.startDate);
    if (targetPath != null && targetPath.isNotEmpty) {
      final file = File(targetPath);
      await file.writeAsString(ics);
      return file.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/course_export.ics');
    await file.writeAsString(ics);
    return file.path;
  }

  Future<Uint8List> exportCoursesJsonBytes() async {
    final list = _courses.map((c) => c.toMap()).toList();
    final str = JsonEncoder.withIndent('  ').convert(list);
    return Uint8List.fromList(utf8.encode(str));
  }

  Future<Uint8List> exportCoursesIcsBytes() async {
    if (_currentSchedule == null) return Uint8List(0);
    final ics = _generateIcs(_courses, _currentSchedule!.startDate);
    return Uint8List.fromList(utf8.encode(ics));
  }

  Future<int> importToSystemCalendar() async {
    if (_currentSchedule == null) return 0;
    return _calendarService.importCourses(
      _courses,
      _currentSchedule!.startDate,
    );
  }

  Future<bool> shareCoursesIcs() async {
    if (_currentSchedule == null) return false;
    final bytes = await exportCoursesIcsBytes();
    if (bytes.isEmpty) return false;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/course_export.ics');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      text: '课程表 ICS 文件，可在 ICSx5 等日历中订阅',
      subject: 'CourseBlock 课表',
    );
    return true;
  }

  Future<int> importCoursesJson(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final list = json.decode(content) as List;
      int inserted = 0;
      if (_currentSchedule == null || _currentSchedule!.id == null) {
        return 0;
      }
      final scheduleId = _currentSchedule!.id!;

      for (var item in list) {
        try {
          final course = Course.fromMap(item as Map<String, dynamic>);
          final newCourse = course.copyWith(scheduleId: scheduleId);
          await DatabaseHelper.instance.insertCourse(newCourse);
          inserted++;
        } catch (e) {}
      }
      await loadCourses();
      return inserted;
    } catch (e) {
      debugPrint('Error importing JSON: $e');
      return 0;
    }
  }

  Future<int> importCoursesIcs(String path) async {
    if (_currentSchedule == null) return 0;
    try {
      final file = File(path);
      final content = await file.readAsString();
      final parsed = _parseIcs(content, _currentSchedule!.startDate);
      int count = 0;
      final scheduleId = _currentSchedule!.id!;
      for (var course in parsed) {
        final newCourse = course.copyWith(scheduleId: scheduleId);
        await DatabaseHelper.instance.insertCourse(newCourse);
        count++;
      }
      await loadCourses();
      return count;
    } catch (e) {
      debugPrint('Error importing ICS: $e');
      return 0;
    }
  }

  List<Course> _parseIcs(String content, DateTime startDate) {
    final events = content.split('BEGIN:VEVENT').skip(1);
    final List<Course> list = [];
    final normalizedStart = normalizeDate(startDate);
    for (var ev in events) {
      String? _field(String name) {
        final reg = RegExp('$name[^:]*:(.+)');
        final m = reg.firstMatch(ev);
        return m?.group(1)?.trim();
      }

      final summary = _field('SUMMARY');
      final location = _field('LOCATION');
      final dtstart = _field('DTSTART');
      final dtend = _field('DTEND');
      final duration = _field('DURATION');
      final rrule = _field('RRULE');
      if (summary == null || dtstart == null) continue;

      DateTime? start;
      try {
        start = _parseIcsDateTime(dtstart);
      } catch (_) {
        start = null;
      }
      if (start == null) continue;

      DateTime? end;
      if (dtend != null) {
        end = _parseIcsDateTime(dtend);
      }

      final diff = start.difference(normalizedStart).inDays;
      int week = (diff / 7).floor() + 1;
      if (week < 1) week = 1;
      final day = start.weekday; // 1=Mon

      final startNode = resolveStartNode(start);
      int step = 1;
      if (end != null) {
        final endNode = resolveEndNode(end);
        step = (endNode - startNode + 1).clamp(1, kClassEndTimes.length);
      } else if (duration != null) {
        final m = RegExp(r'PT(\d+)M').firstMatch(duration);
        if (m != null) {
          final mins = int.tryParse(m.group(1)!) ?? 0;
          step = (mins / 45).ceil();
        }
      }

      int endWeek = week;
      if (rrule != null) {
        final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
        if (countMatch != null) {
          final cnt = int.tryParse(countMatch.group(1)!) ?? 1;
          endWeek = week + cnt - 1;
        }
      }

      list.add(
        Course(
          scheduleId: null,
          courseId: '',
          courseName: summary,
          teacher: '',
          classRoom: location ?? '',
          startWeek: week,
          endWeek: endWeek,
          dayOfWeek: day,
          startNode: startNode,
          step: step,
          isOddWeek: false,
          isEvenWeek: false,
          weekCode: null,
          color: _courseColorPalette.autoColorToken(
            buildCourseColorSeed(summary, ''),
          ),
        ),
      );
    }
    return list;
  }

  String _generateIcs(List<Course> courses, DateTime startDate) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//CourseBlock//EN');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');

    final normalizedStart = normalizeDate(startDate);

    for (var course in courses) {
      final baseDate = normalizedStart.add(
        Duration(days: (course.startWeek - 1) * 7 + (course.dayOfWeek - 1)),
      );

      final start = classStartDateTime(baseDate, course.startNode);
      final end = classEndDateTime(baseDate, course.startNode, course.step);

      int interval = 1;
      int count = course.endWeek - course.startWeek + 1;
      if (course.isOddWeek ^ course.isEvenWeek) {
        interval = 2;
        count = ((course.endWeek - course.startWeek) / 2).floor() + 1;
      }

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${course.courseName}');
      buffer.writeln('LOCATION:${course.classRoom}');
      buffer.writeln('DTSTART;TZID=Asia/Shanghai:${_formatIcsDateTime(start)}');
      buffer.writeln('DTEND;TZID=Asia/Shanghai:${_formatIcsDateTime(end)}');
      buffer.writeln('RRULE:FREQ=WEEKLY;INTERVAL=$interval;COUNT=$count');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  DateTime? _parseIcsDateTime(String value) {
    try {
      if (value.endsWith('Z')) {
        return DateFormat("yyyyMMdd'T'HHmmss'Z'").parseUtc(value).toLocal();
      }
      return DateFormat("yyyyMMdd'T'HHmmss").parseStrict(value);
    } catch (_) {
      try {
        return DateFormat('yyyyMMdd').parseStrict(value);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatIcsDateTime(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss").format(dt);
  }

  Future<void> _updateWidgetsSafe() async {
    try {
      await WidgetSyncService.instance.updateTodayWidget(
        _courses,
        _currentSchedule,
        totalWeeks: _totalWeeks,
        themeScheme: _themeScheme,
        themeMode: _themeMode,
        courseColorPalette: _courseColorPalette,
      );
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }
}
