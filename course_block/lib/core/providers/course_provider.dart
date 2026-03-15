import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/models/course.dart';
import '../../core/models/course_operation_report.dart';
import '../../core/models/schedule.dart';
import '../../core/theme/app_theme.dart';
import '../services/course_service.dart';
import '../services/course_schedule_manager.dart';
import '../services/course_settings_store.dart';
import '../services/course_sync_manager.dart';
import '../services/course_transfer_manager.dart';
import '../services/widget_sync_service.dart';
import '../utils/time_slots.dart';

class CourseProvider extends ChangeNotifier {
  static const String defaultScheduleName = '默认课表';

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

  final CourseScheduleManager _courseScheduleManager = CourseScheduleManager();
  final CourseSettingsStore _courseSettingsStore = CourseSettingsStore();
  final CourseSyncManager _courseSyncManager = CourseSyncManager();
  final CourseTransferManager _courseTransferManager = CourseTransferManager();

  CourseProvider() {
    _loadAppSettings();
  }

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

  AppSettingsSnapshot _currentAppSettingsSnapshot() {
    return AppSettingsSnapshot(
      themeMode: _themeMode,
      themeScheme: _themeScheme,
      courseColorPalette: _courseColorPalette,
      launcherIcon: _launcherIcon,
    );
  }

  ScheduleSettingsSnapshot _currentScheduleSettingsSnapshot() {
    return ScheduleSettingsSnapshot(
      showGridLines: _showGridLines,
      showNonCurrentWeek: _showNonCurrentWeek,
      showSaturday: _showSaturday,
      showSunday: _showSunday,
      outlineText: _outlineText,
      maxDailyClasses: _maxDailyClasses,
      totalWeeks: _totalWeeks,
      gridHeight: _gridHeight,
      cornerRadius: _cornerRadius,
      backgroundColorLight: _backgroundColorLight,
      backgroundColorDark: _backgroundColorDark,
      backgroundImagePath: _backgroundImagePath,
      backgroundImageOpacity: _backgroundImageOpacity,
    );
  }

  void _applyAppSettingsSnapshot(AppSettingsSnapshot snapshot) {
    _themeMode = snapshot.themeMode;
    _themeScheme = snapshot.themeScheme;
    _courseColorPalette = snapshot.courseColorPalette;
    _launcherIcon = snapshot.launcherIcon;
  }

  void _applyScheduleSettingsSnapshot(ScheduleSettingsSnapshot snapshot) {
    _showGridLines = snapshot.showGridLines;
    _showNonCurrentWeek = snapshot.showNonCurrentWeek;
    _showSaturday = snapshot.showSaturday;
    _showSunday = snapshot.showSunday;
    _outlineText = snapshot.outlineText;
    _maxDailyClasses = snapshot.maxDailyClasses;
    _totalWeeks = snapshot.totalWeeks;
    _gridHeight = snapshot.gridHeight;
    _cornerRadius = snapshot.cornerRadius;
    _backgroundColorLight = snapshot.backgroundColorLight;
    _backgroundColorDark = snapshot.backgroundColorDark;
    _backgroundImagePath = snapshot.backgroundImagePath;
    _backgroundImageOpacity = snapshot.backgroundImageOpacity;
  }

  Future<List<String>> getAvailableLauncherIcons() {
    return _courseSettingsStore.getAvailableLauncherIcons();
  }

  Future<void> _seedCurrentScheduleSettings(int targetScheduleId) {
    return _courseSettingsStore.seedScheduleSettings(
      targetScheduleId,
      _currentScheduleSettingsSnapshot(),
    );
  }

  Future<void> _deleteScheduleSettings(int scheduleId) {
    return _courseSettingsStore.deleteScheduleSettings(scheduleId);
  }

  Future<void> _loadAppSettings() async {
    final snapshot = await _courseSettingsStore.loadAppSettings();
    _applyAppSettingsSnapshot(snapshot);
    notifyListeners();
  }

  Future<void> _loadCurrentScheduleSettings({bool notify = true}) async {
    final snapshot = await _courseSettingsStore.loadScheduleSettings(
      _currentSchedule?.id,
    );
    _applyScheduleSettingsSnapshot(snapshot);
    _clampCurrentWeek();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> updateAppSetting(String key, dynamic value) async {
    final result = await _courseSettingsStore.updateAppSetting(
      key: key,
      value: value,
      current: _currentAppSettingsSnapshot(),
    );
    _applyAppSettingsSnapshot(result.snapshot);
    notifyListeners();
    if (result.shouldRefreshWidgets) {
      await _updateWidgetsSafe();
    }
  }

  Future<void> updateCurrentScheduleSetting(String key, dynamic value) async {
    final scheduleId = _currentSchedule?.id;
    if (scheduleId == null) return;

    final snapshot = await _courseSettingsStore.updateScheduleSetting(
      scheduleId: scheduleId,
      key: key,
      value: value,
      current: _currentScheduleSettingsSnapshot(),
    );
    _applyScheduleSettingsSnapshot(snapshot);
    _clampCurrentWeek();

    notifyListeners();
    await _updateWidgetsSafe();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    if (_courseSettingsStore.isAppSettingKey(key)) {
      await updateAppSetting(key, value);
      return;
    }
    await updateCurrentScheduleSetting(key, value);
  }

  Future<void> loadCourses({bool recalcWeek = true}) async {
    debugPrint('CourseProvider.loadCourses called');
    _isLoading = true;
    notifyListeners();

    try {
      final oldScheduleId = _currentSchedule?.id;
      final scheduleState = await _courseScheduleManager.loadScheduleState(
        defaultScheduleName: defaultScheduleName,
      );
      _schedules = scheduleState.schedules;
      _currentSchedule = scheduleState.currentSchedule;
      _courses = scheduleState.courses;

      await _loadCurrentScheduleSettings(notify: false);

      if (recalcWeek || _currentSchedule?.id != oldScheduleId) {
        _recalculateWeekFromCurrentSchedule();
      }

      _courses = await _courseScheduleManager.normalizeCourseColors(
        courses: _courses,
        courseColorPalette: _courseColorPalette,
      );
    } catch (e) {
      debugPrint('Error loading courses/schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateWidgetsSafe();
    }
  }

  String _buildTermLabel(String year, String term) {
    final nextYear = (int.tryParse(year) ?? 0) + 1;
    final termLabel = switch (term) {
      '2' => '第2学期（春季）',
      '3' => '第3学期（夏季）',
      _ => '第1学期（秋季）',
    };
    return '$year~$nextYear $termLabel';
  }

  String _formatOperationError(Object error, {required String fallback}) {
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
    return raw.isEmpty ? fallback : raw;
  }

  Future<CourseSyncReport> syncCurrentSchedule() async {
    final schedule = _currentSchedule;
    if (schedule == null) {
      return const CourseSyncReport(
        termLabel: '',
        sourceLabel: '教务系统',
        added: 0,
        updated: 0,
        skipped: 0,
        failed: 0,
        notes: ['当前没有可同步的课表。'],
      );
    }
    return syncCourses(schedule.year, schedule.term);
  }

  Future<CourseSyncReport> syncCourses(String year, String term) async {
    _isLoading = true;
    notifyListeners();

    final oldScheduleId = _currentSchedule?.id;
    try {
      final result = await _courseSyncManager.syncCourses(
        year: year,
        term: term,
        currentSchedule: _currentSchedule,
        schedules: _schedules,
        courses: _courses,
        courseColorPalette: _courseColorPalette,
        defaultScheduleName: defaultScheduleName,
      );

      _currentSchedule = result.currentSchedule;
      _schedules = result.schedules;
      _courses = result.courses;

      if (_currentSchedule?.id != oldScheduleId) {
        await _loadCurrentScheduleSettings(notify: false);
        _recalculateWeekFromCurrentSchedule();
      }

      _courses = await _courseScheduleManager.normalizeCourseColors(
        courses: _courses,
        courseColorPalette: _courseColorPalette,
      );

      return result.report;
    } catch (e) {
      if (e is CourseSyncException) {
        rethrow;
      }
      debugPrint('Error syncing courses: $e');
      return CourseSyncReport(
        termLabel: _buildTermLabel(year, term),
        sourceLabel: '教务系统',
        added: 0,
        updated: 0,
        skipped: 0,
        failed: 1,
        notes: const ['同步时发生了未预期错误。'],
        failures: [
          CourseOperationFailure(
            label: '同步请求',
            reason: _formatOperationError(e, fallback: '同步失败'),
          ),
        ],
      );
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
    await _courseScheduleManager.switchSchedule(scheduleId);
    await loadCourses();
  }

  Future<void> addSchedule(
    String name,
    String year,
    String term, {
    DateTime? startDate,
  }) async {
    final newScheduleId = await _courseScheduleManager.addSchedule(
      name,
      year,
      term,
      startDate: startDate,
    );
    if (_currentSchedule?.id != null) {
      await _seedCurrentScheduleSettings(newScheduleId);
    }
    await loadCourses();
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _courseScheduleManager.deleteSchedule(scheduleId);
    await _deleteScheduleSettings(scheduleId);
    await loadCourses();
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await _courseScheduleManager.updateSchedule(schedule);
    await loadCourses();
  }

  Future<void> setBackgroundImage(String path) async {
    await updateCurrentScheduleSetting(
      CourseSettingsStore.backgroundImagePathKey,
      path,
    );
  }

  Future<String> exportCoursesJson([String? targetPath]) {
    return _courseTransferManager.exportCoursesJson(_courses, targetPath);
  }

  Future<String> exportCoursesIcs([String? targetPath]) {
    return _courseTransferManager.exportCoursesIcs(
      _courses,
      _currentSchedule?.startDate,
      targetPath,
    );
  }

  Future<Uint8List> exportCoursesJsonBytes() {
    return _courseTransferManager.exportCoursesJsonBytes(_courses);
  }

  Future<Uint8List> exportCoursesIcsBytes() {
    return _courseTransferManager.exportCoursesIcsBytes(
      _courses,
      _currentSchedule?.startDate,
    );
  }

  Future<int> importToSystemCalendar() {
    return _courseTransferManager.importToSystemCalendar(
      _courses,
      _currentSchedule?.startDate,
    );
  }

  Future<bool> shareCoursesIcs() {
    return _courseTransferManager.shareCoursesIcs(
      _courses,
      _currentSchedule?.startDate,
    );
  }

  Future<CourseImportReport> importCoursesJson(String path) async {
    final report = await _courseTransferManager.importCoursesJson(
      path: path,
      scheduleId: _currentSchedule?.id,
    );
    if (report.added > 0) {
      await loadCourses();
    }
    return report;
  }

  Future<CourseImportReport> importCoursesIcs(String path) async {
    final report = await _courseTransferManager.importCoursesIcs(
      path: path,
      scheduleId: _currentSchedule?.id,
      startDate: _currentSchedule?.startDate,
      courseColorPalette: _courseColorPalette,
    );
    if (report.added > 0) {
      await loadCourses();
    }
    return report;
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
