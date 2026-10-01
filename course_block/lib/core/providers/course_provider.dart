import 'dart:async';
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
import '../services/performance_test_data_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/course_occurrences.dart';

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

  final CourseScheduleManager _courseScheduleManager;
  final CourseSettingsStore _courseSettingsStore;
  final DateTime Function() _now;
  final CourseSyncManager _courseSyncManager;
  final CourseTransferManager _courseTransferManager;
  final PerformanceTestDataService _performanceTestDataService =
      PerformanceTestDataService();
  Timer? _widgetUpdateTimer;
  int _widgetUpdateGeneration = 0;
  bool _widgetUpdateInFlight = false;
  bool _disposed = false;
  int _stateRequestGeneration = 0;
  AppSettingsSnapshot _appSettingsSnapshot = const AppSettingsSnapshot();
  late Future<void> _appSettingsTail;
  final Map<int, Future<void>> _scheduleSettingsTails = {};
  final Map<int, int> _scheduleSettingsRevisions = {};
  final Map<int, ScheduleSettingsSnapshot> _scheduleSettingsSnapshots = {};

  CourseProvider({
    CourseScheduleManager? courseScheduleManager,
    CourseSettingsStore? courseSettingsStore,
    CourseSyncManager? courseSyncManager,
    CourseTransferManager? courseTransferManager,
    DateTime Function()? now,
  }) : _courseScheduleManager =
           courseScheduleManager ?? CourseScheduleManager(),
       _courseSettingsStore = courseSettingsStore ?? CourseSettingsStore(),
       _courseSyncManager = courseSyncManager ?? CourseSyncManager(),
       _courseTransferManager =
           courseTransferManager ?? CourseTransferManager(),
       _now = now ?? DateTime.now {
    _appSettingsTail = _loadAppSettings().catchError((Object error) {
      debugPrint('Error loading app settings: $error');
    });
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

    _currentWeek = courseWeekForDate(schedule.startDate, _now());
    _clampCurrentWeek();
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

  Future<void> _seedCurrentScheduleSettings(
    int targetScheduleId, {
    int? sourceScheduleId,
  }) async {
    final sourceId = sourceScheduleId ?? _currentSchedule?.id;
    if (sourceId == null) return;
    final pending = _scheduleSettingsTails[sourceId];
    if (pending != null) await pending;
    final sourceSettings =
        _scheduleSettingsSnapshots[sourceId] ??
        await _courseSettingsStore.loadScheduleSettings(sourceId);
    await _courseSettingsStore.seedScheduleSettings(
      targetScheduleId,
      sourceSettings,
    );
  }

  Future<void> _deleteScheduleSettings(int scheduleId) {
    return _courseSettingsStore.deleteScheduleSettings(scheduleId);
  }

  Future<void> _loadAppSettings() async {
    final snapshot = await _courseSettingsStore.loadAppSettings();
    _appSettingsSnapshot = snapshot;
    if (_disposed) return;
    _applyAppSettingsSnapshot(snapshot);
    notifyListeners();
  }

  bool _isCurrentStateRequest(int generation) =>
      !_disposed && generation == _stateRequestGeneration;

  int _settingsRevision(int? scheduleId) =>
      _scheduleSettingsRevisions[scheduleId] ?? 0;

  Future<({ScheduleSettingsSnapshot snapshot, int revision})?>
  _loadCurrentScheduleSettings(int? scheduleId, int generation) async {
    while (_isCurrentStateRequest(generation)) {
      final revision = _settingsRevision(scheduleId);
      final pending = _scheduleSettingsTails[scheduleId];
      if (pending != null) await pending;
      if (!_isCurrentStateRequest(generation)) return null;
      if (revision != _settingsRevision(scheduleId)) continue;

      final snapshot = await _courseSettingsStore.loadScheduleSettings(
        scheduleId,
      );
      if (!_isCurrentStateRequest(generation)) return null;
      if (revision == _settingsRevision(scheduleId)) {
        if (scheduleId != null) {
          _scheduleSettingsSnapshots[scheduleId] = snapshot;
        }
        return (snapshot: snapshot, revision: revision);
      }
    }
    return null;
  }

  Future<void> _applyLoadedState({
    required int generation,
    required List<Schedule> schedules,
    required Schedule? currentSchedule,
    required List<Course> courses,
    required bool recalcWeek,
  }) async {
    if (!_isCurrentStateRequest(generation)) return;
    final normalizedCourses = await _courseScheduleManager
        .normalizeCourseColors(
          courses: courses,
          courseColorPalette: _courseColorPalette,
        );

    while (_isCurrentStateRequest(generation)) {
      final settings = await _loadCurrentScheduleSettings(
        currentSchedule?.id,
        generation,
      );
      if (settings == null || !_isCurrentStateRequest(generation)) return;
      if (settings.revision != _settingsRevision(currentSchedule?.id)) {
        continue;
      }

      final oldScheduleId = _currentSchedule?.id;
      final oldStartDate = _currentSchedule?.startDate;
      _schedules = schedules;
      _currentSchedule = currentSchedule;
      _courses = normalizedCourses;
      _applyScheduleSettingsSnapshot(settings.snapshot);
      _clampCurrentWeek();
      if (recalcWeek ||
          currentSchedule?.id != oldScheduleId ||
          currentSchedule?.startDate != oldStartDate) {
        _recalculateWeekFromCurrentSchedule();
      }
      return;
    }
  }

  Future<void> updateAppSetting(String key, dynamic value) {
    if (_disposed) return Future.value();
    final operation = _appSettingsTail.then((_) async {
      final result = await _courseSettingsStore.updateAppSetting(
        key: key,
        value: value,
        current: _appSettingsSnapshot,
      );
      _appSettingsSnapshot = result.snapshot;
      if (_disposed) return;
      _applyAppSettingsSnapshot(result.snapshot);
      notifyListeners();
      if (result.shouldRefreshWidgets) await _updateWidgetsSafe();
    });
    // Only the queue tail handles errors; the caller still receives the failure.
    _appSettingsTail = operation.then(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> updateCurrentScheduleSetting(String key, dynamic value) {
    final scheduleId = _currentSchedule?.id;
    if (_disposed || scheduleId == null) return Future.value();

    _scheduleSettingsRevisions[scheduleId] = _settingsRevision(scheduleId) + 1;
    final previous = _scheduleSettingsTails[scheduleId] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final current =
          _scheduleSettingsSnapshots[scheduleId] ??
          await _courseSettingsStore.loadScheduleSettings(scheduleId);
      final snapshot = await _courseSettingsStore.updateScheduleSetting(
        scheduleId: scheduleId,
        key: key,
        value: value,
        current: current,
      );
      _scheduleSettingsSnapshots[scheduleId] = snapshot;
      if (_disposed || _currentSchedule?.id != scheduleId) return;
      _applyScheduleSettingsSnapshot(snapshot);
      _clampCurrentWeek();
      notifyListeners();
      await _updateWidgetsSafe();
    });
    _scheduleSettingsTails[scheduleId] = operation.then(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> updateSetting(String key, dynamic value) async {
    if (_courseSettingsStore.isAppSettingKey(key)) {
      await updateAppSetting(key, value);
      return;
    }
    await updateCurrentScheduleSetting(key, value);
  }

  Future<void> loadCourses({bool recalcWeek = true}) async {
    if (_disposed) return;
    debugPrint('CourseProvider.loadCourses called');
    final generation = ++_stateRequestGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      final scheduleState = await _courseScheduleManager.loadScheduleState(
        defaultScheduleName: defaultScheduleName,
      );
      await _applyLoadedState(
        generation: generation,
        schedules: scheduleState.schedules,
        currentSchedule: scheduleState.currentSchedule,
        courses: scheduleState.courses,
        recalcWeek: recalcWeek,
      );
    } catch (e) {
      debugPrint('Error loading courses/schedules: $e');
    } finally {
      if (_isCurrentStateRequest(generation)) {
        _isLoading = false;
        notifyListeners();
        _updateWidgetsSafe();
      }
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

  Future<CourseSyncReport> syncCourses(
    String year,
    String term, {
    DateTime? startDate,
  }) async {
    final sourceScheduleId = _currentSchedule?.id;
    final generation = ++_stateRequestGeneration;
    if (!_disposed) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final result = await _courseSyncManager.syncCourses(
        year: year,
        term: term,
        currentSchedule: _currentSchedule,
        schedules: _schedules,
        courses: _courses,
        courseColorPalette: _courseColorPalette,
        defaultScheduleName: defaultScheduleName,
        startDate: startDate,
      );
      if (result.createdSchedule &&
          result.currentSchedule?.id != null &&
          sourceScheduleId != null) {
        await _seedCurrentScheduleSettings(
          result.currentSchedule!.id!,
          sourceScheduleId: sourceScheduleId,
        );
      }

      await _applyLoadedState(
        generation: generation,
        schedules: result.schedules,
        currentSchedule: result.currentSchedule,
        courses: result.courses,
        recalcWeek: false,
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
      if (_isCurrentStateRequest(generation)) {
        _isLoading = false;
        notifyListeners();
        _updateWidgetsSafe();
      }
    }
  }

  void setCurrentWeek(int week) {
    if (_disposed) return;
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
    final generation = ++_stateRequestGeneration;
    try {
      await _courseScheduleManager.switchSchedule(scheduleId);
    } catch (_) {
      if (_isCurrentStateRequest(generation) && _isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      rethrow;
    }
    if (_isCurrentStateRequest(generation)) await loadCourses();
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

  Future<PerformanceTestDataResult> generatePerformanceTestData() async {
    final result = await _performanceTestDataService.replaceWithLargeDataset();
    await loadCourses();
    return result;
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
      scheduleId: _currentSchedule?.id,
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
    if (_disposed) return;
    _widgetUpdateGeneration++;
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer(
      const Duration(milliseconds: 180),
      _flushWidgetUpdate,
    );
  }

  Future<void> _flushWidgetUpdate() async {
    if (_disposed || _widgetUpdateInFlight) {
      return;
    }

    _widgetUpdateInFlight = true;
    final generation = _widgetUpdateGeneration;
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
    } finally {
      _widgetUpdateInFlight = false;
      if (!_disposed && generation != _widgetUpdateGeneration) {
        _widgetUpdateTimer?.cancel();
        _widgetUpdateTimer = Timer(
          const Duration(milliseconds: 180),
          _flushWidgetUpdate,
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_stateRequestGeneration;
    _widgetUpdateTimer?.cancel();
    super.dispose();
  }
}
