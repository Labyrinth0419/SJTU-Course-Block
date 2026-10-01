import 'dart:async';
import 'dart:collection';

import 'package:course_block/core/models/course.dart';
import 'package:course_block/core/models/course_operation_report.dart';
import 'package:course_block/core/models/schedule.dart';
import 'package:course_block/core/providers/course_provider.dart';
import 'package:course_block/core/services/course_schedule_manager.dart';
import 'package:course_block/core/services/course_settings_store.dart';
import 'package:course_block/core/services/course_sync_manager.dart';
import 'package:course_block/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Schedule _schedule(int id) => Schedule(
  id: id,
  name: 'Schedule $id',
  year: '2025',
  term: '1',
  startDate: DateTime(2025, 9, 1),
  isCurrent: true,
);

CourseScheduleState _state(int id) => CourseScheduleState(
  schedules: [_schedule(id)],
  currentSchedule: _schedule(id),
  courses: <Course>[],
);

CourseSyncExecutionResult _syncResult(int id) => CourseSyncExecutionResult(
  report: const CourseSyncReport(
    termLabel: 'term',
    sourceLabel: 'test',
    added: 0,
    updated: 0,
    skipped: 0,
    failed: 0,
  ),
  currentSchedule: _schedule(id),
  schedules: [_schedule(id)],
  courses: <Course>[],
);

class _SettingsStore extends CourseSettingsStore {
  final appWriteGates = Queue<Completer<void>>();
  final scheduleWriteGates = Queue<Completer<void>>();
  final scheduleReads = <int, Queue<Completer<ScheduleSettingsSnapshot>>>{};
  final scheduleReadStarted = StreamController<int>.broadcast(sync: true);
  Completer<void>? initialAppRead;
  Completer<void>? initialAppReadReturned;
  final appWriteStarted = StreamController<String>.broadcast(sync: true);
  final scheduleWriteStarted = StreamController<int>.broadcast(sync: true);

  @override
  Future<AppSettingsSnapshot> loadAppSettings() async {
    if (initialAppRead case final gate?) await gate.future;
    final snapshot = await super.loadAppSettings();
    initialAppReadReturned?.complete();
    initialAppReadReturned = null;
    return snapshot;
  }

  @override
  Future<ScheduleSettingsSnapshot> loadScheduleSettings(int? scheduleId) async {
    final reads = scheduleReads[scheduleId];
    if (reads != null && reads.isNotEmpty) {
      scheduleReadStarted.add(scheduleId!);
      return reads.removeFirst().future;
    }
    return super.loadScheduleSettings(scheduleId);
  }

  @override
  Future<AppSettingsUpdateResult> updateAppSetting({
    required String key,
    required dynamic value,
    required AppSettingsSnapshot current,
  }) async {
    appWriteStarted.add(key);
    if (appWriteGates.isNotEmpty) await appWriteGates.removeFirst().future;
    return super.updateAppSetting(key: key, value: value, current: current);
  }

  @override
  Future<ScheduleSettingsSnapshot> updateScheduleSetting({
    required int scheduleId,
    required String key,
    required dynamic value,
    required ScheduleSettingsSnapshot current,
  }) async {
    scheduleWriteStarted.add(scheduleId);
    if (scheduleWriteGates.isNotEmpty) {
      await scheduleWriteGates.removeFirst().future;
    }
    return super.updateScheduleSetting(
      scheduleId: scheduleId,
      key: key,
      value: value,
      current: current,
    );
  }

  Future<void> close() async {
    await appWriteStarted.close();
    await scheduleWriteStarted.close();
    await scheduleReadStarted.close();
  }
}

class _WidgetSettingsStore extends CourseSettingsStore {
  @override
  Future<AppSettingsSnapshot> loadAppSettings() async =>
      const AppSettingsSnapshot();

  @override
  Future<AppSettingsUpdateResult> updateAppSetting({
    required String key,
    required dynamic value,
    required AppSettingsSnapshot current,
  }) async => AppSettingsUpdateResult(
    snapshot: key == CourseSettingsStore.themeModeKey
        ? current.copyWith(themeMode: ThemeMode.dark)
        : current.copyWith(themeScheme: AppThemeScheme.apricotGlow),
    shouldRefreshWidgets: true,
  );
}

class _ScheduleManager extends CourseScheduleManager {
  final loads = Queue<Completer<CourseScheduleState>>();
  int selectedId = 1;

  @override
  Future<CourseScheduleState> loadScheduleState({
    required String defaultScheduleName,
  }) => loads.isEmpty
      ? Future.value(_state(selectedId))
      : loads.removeFirst().future;

  @override
  Future<void> switchSchedule(int scheduleId) async {
    selectedId = scheduleId;
  }

  @override
  Future<int> addSchedule(
    String name,
    String year,
    String term, {
    DateTime? startDate,
  }) async {
    selectedId = 2;
    return 2;
  }

  @override
  Future<List<Course>> normalizeCourseColors({
    required List<Course> courses,
    required AppCourseColorPalette courseColorPalette,
  }) async => courses;
}

class _SyncManager extends CourseSyncManager {
  final syncs = Queue<Completer<CourseSyncExecutionResult>>();

  @override
  Future<CourseSyncExecutionResult> syncCourses({
    required String year,
    required String term,
    required Schedule? currentSchedule,
    required List<Schedule> schedules,
    required List<Course> courses,
    required AppCourseColorPalette courseColorPalette,
    required String defaultScheduleName,
    DateTime? startDate,
  }) => syncs.removeFirst().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SettingsStore store;
  late _ScheduleManager schedules;
  late _SyncManager sync;
  late CourseProvider provider;
  var disposedInTest = false;

  setUp(() {
    disposedInTest = false;
    SharedPreferences.setMockInitialValues({});
    store = _SettingsStore();
    schedules = _ScheduleManager();
    sync = _SyncManager();
    provider = CourseProvider(
      courseSettingsStore: store,
      courseScheduleManager: schedules,
      courseSyncManager: sync,
    );
  });

  tearDown(() async {
    if (!disposedInTest) provider.dispose();
    await store.close();
  });

  test('concurrent app edits keep both fields in memory and storage', () async {
    final gate = Completer<void>();
    store.appWriteGates.add(gate);
    final started = store.appWriteStarted.stream.first;
    final first = provider.updateAppSetting(
      CourseSettingsStore.themeModeKey,
      'dark',
    );
    await started;
    final second = provider.updateAppSetting(
      CourseSettingsStore.themeSchemeKey,
      'apricot_glow',
    );
    gate.complete();
    await Future.wait([first, second]);
    final prefs = await SharedPreferences.getInstance();
    expect(provider.themeMode, ThemeMode.dark);
    expect(prefs.getString(CourseSettingsStore.themeModeKey), 'dark');
    expect(
      provider.themeScheme.storageKey,
      prefs.getString(CourseSettingsStore.themeSchemeKey),
    );
    expect(provider.themeScheme, AppThemeScheme.apricotGlow);
  });

  test(
    'different schedule edits keep both fields in memory and storage',
    () async {
      await provider.loadCourses();
      final gate = Completer<void>();
      store.scheduleWriteGates.add(gate);
      final started = store.scheduleWriteStarted.stream.first;
      final first = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showGridLinesKey,
        false,
      );
      expect(await started, 1);
      final second = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showSundayKey,
        false,
      );
      gate.complete();
      await Future.wait([first, second]);
      final prefs = await SharedPreferences.getInstance();
      expect(provider.showGridLines, false);
      expect(provider.showSunday, false);
      expect(
        prefs.getBool(
          store.schedulePrefKey(1, CourseSettingsStore.showGridLinesKey),
        ),
        false,
      );
      expect(
        prefs.getBool(
          store.schedulePrefKey(1, CourseSettingsStore.showSundayKey),
        ),
        false,
      );
    },
  );

  test(
    'app edit queued during initialization keeps persisted app fields',
    () async {
      provider.dispose();
      await store.close();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CourseSettingsStore.themeSchemeKey, 'apricot_glow');
      store = _SettingsStore();
      final gate = Completer<void>();
      store.initialAppRead = gate;
      provider = CourseProvider(
        courseSettingsStore: store,
        courseScheduleManager: schedules,
      );
      final pending = provider.updateAppSetting(
        CourseSettingsStore.themeModeKey,
        'dark',
      );
      gate.complete();
      await pending;
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.themeScheme, AppThemeScheme.apricotGlow);
      expect(prefs.getString(CourseSettingsStore.themeModeKey), 'dark');
      expect(
        prefs.getString(CourseSettingsStore.themeSchemeKey),
        'apricot_glow',
      );
    },
  );

  test(
    'same-key app edits finish in call order in memory and storage',
    () async {
      final gate = Completer<void>();
      store.appWriteGates.add(gate);
      final started = store.appWriteStarted.stream.first;
      final first = provider.updateAppSetting(
        CourseSettingsStore.themeModeKey,
        'dark',
      );
      expect(await started, CourseSettingsStore.themeModeKey);
      final second = provider.updateAppSetting(
        CourseSettingsStore.themeModeKey,
        'light',
      );
      gate.complete();
      await Future.wait([first, second]);
      final prefs = await SharedPreferences.getInstance();
      expect(provider.themeMode, ThemeMode.light);
      expect(prefs.getString(CourseSettingsStore.themeModeKey), 'light');
    },
  );

  test(
    'same-key schedule edits finish in call order in memory and storage',
    () async {
      await provider.loadCourses();
      final gate = Completer<void>();
      store.scheduleWriteGates.add(gate);
      final started = store.scheduleWriteStarted.stream.first;
      final first = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.totalWeeksKey,
        8,
      );
      expect(await started, 1);
      final second = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.totalWeeksKey,
        16,
      );
      gate.complete();
      await Future.wait([first, second]);
      final prefs = await SharedPreferences.getInstance();
      expect(provider.totalWeeks, 16);
      expect(
        prefs.getInt(
          store.schedulePrefKey(1, CourseSettingsStore.totalWeeksKey),
        ),
        16,
      );
    },
  );

  test(
    'adding a schedule seeds completed edits, not a pending snapshot',
    () async {
      await provider.loadCourses();
      final gate = Completer<void>();
      store.scheduleWriteGates.add(gate);
      final started = store.scheduleWriteStarted.stream.first;
      final pending = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showGridLinesKey,
        false,
      );
      expect(await started, 1);
      final add = provider.addSchedule('second', '2025', '2');
      gate.complete();
      await Future.wait([pending, add]);
      final prefs = await SharedPreferences.getInstance();
      expect(provider.currentSchedule?.id, 2);
      expect(provider.showGridLines, false);
      expect(
        prefs.getBool(
          store.schedulePrefKey(2, CourseSettingsStore.showGridLinesKey),
        ),
        false,
      );
    },
  );

  test('nullable setting remains cleared through later queued edits', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CourseSettingsStore.backgroundImagePathKey,
      'legacy.png',
    );
    await provider.loadCourses();
    expect(provider.backgroundImagePath, 'legacy.png');
    final first = provider.updateCurrentScheduleSetting(
      CourseSettingsStore.backgroundImagePathKey,
      null,
    );
    final second = provider.updateCurrentScheduleSetting(
      CourseSettingsStore.showGridLinesKey,
      false,
    );
    await Future.wait([first, second]);
    expect(provider.backgroundImagePath, isNull);
    expect(provider.showGridLines, false);
    expect(
      prefs.getString(CourseSettingsStore.backgroundImagePathKey),
      'legacy.png',
    );
    expect(
      prefs.getBool(
        store.schedulePrefKey(1, CourseSettingsStore.showGridLinesKey),
      ),
      false,
    );
  });

  test(
    'late update for old schedule never applies to selected schedule',
    () async {
      await provider.loadCourses();
      final gate = Completer<void>();
      store.scheduleWriteGates.add(gate);
      final started = store.scheduleWriteStarted.stream.first;
      final oldUpdate = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.showGridLinesKey,
        false,
      );
      expect(await started, 1);
      await provider.switchSchedule(2);
      expect(provider.currentSchedule?.id, 2);
      gate.complete();
      await oldUpdate;
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          store.schedulePrefKey(1, CourseSettingsStore.showGridLinesKey),
        ),
        false,
      );
      expect(provider.showGridLines, true);
    },
  );

  test('newer load wins when older schedule state finishes last', () async {
    final old = Completer<CourseScheduleState>();
    final fresh = Completer<CourseScheduleState>();
    schedules.loads.addAll([old, fresh]);
    final first = provider.loadCourses();
    final second = provider.loadCourses();
    fresh.complete(_state(2));
    await second;
    old.complete(_state(1));
    await first;
    expect(provider.currentSchedule?.id, 2);
    expect(provider.isLoading, false);
  });

  test('older schedule settings read cannot cross a schedule switch', () async {
    final oldRead = Completer<ScheduleSettingsSnapshot>();
    store.scheduleReads[1] = Queue.of([oldRead]);
    final readStarted = store.scheduleReadStarted.stream.first;
    final loadOld = provider.loadCourses();
    expect(await readStarted, 1);
    await provider.switchSchedule(2);
    oldRead.complete(const ScheduleSettingsSnapshot(showGridLines: false));
    await loadOld;
    expect(provider.currentSchedule?.id, 2);
    expect(provider.showGridLines, true);
  });

  test('a delayed settings read retries after a newer write', () async {
    await provider.loadCourses();
    final stale = Completer<ScheduleSettingsSnapshot>();
    store.scheduleReads[1] = Queue.of([stale]);
    final readStarted = store.scheduleReadStarted.stream.first;
    final load = provider.loadCourses();
    expect(await readStarted, 1);
    await provider.updateCurrentScheduleSetting(
      CourseSettingsStore.showGridLinesKey,
      false,
    );
    stale.complete(const ScheduleSettingsSnapshot(showGridLines: true));
    await load;
    expect(provider.showGridLines, false);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(
        store.schedulePrefKey(1, CourseSettingsStore.showGridLinesKey),
      ),
      false,
    );
  });

  test('stale completion does not clear the newer loading indicator', () async {
    final old = Completer<CourseScheduleState>();
    final fresh = Completer<CourseScheduleState>();
    schedules.loads.addAll([old, fresh]);
    final first = provider.loadCourses();
    final second = provider.loadCourses();
    old.complete(_state(1));
    await first;
    expect(provider.isLoading, true);
    fresh.complete(_state(2));
    await second;
    expect(provider.isLoading, false);
    expect(provider.currentSchedule?.id, 2);
  });

  test('late sync result cannot replace a newer load', () async {
    await provider.loadCourses();
    final oldSync = Completer<CourseSyncExecutionResult>();
    sync.syncs.add(oldSync);
    final first = provider.syncCourses('2025', '1');
    schedules.selectedId = 2;
    await provider.loadCourses();
    oldSync.complete(_syncResult(1));
    await first;
    expect(provider.currentSchedule?.id, 2);
    expect(provider.isLoading, false);
  });

  test(
    'late sync schedule settings read cannot replace a newer load',
    () async {
      await provider.loadCourses();
      final delayedSettings = Completer<ScheduleSettingsSnapshot>();
      store.scheduleReads[2] = Queue.of([delayedSettings]);
      final readStarted = store.scheduleReadStarted.stream.first;
      final result = Completer<CourseSyncExecutionResult>();
      sync.syncs.add(result);
      final pendingSync = provider.syncCourses('2025', '2');
      result.complete(_syncResult(2));
      expect(await readStarted, 2);
      schedules.selectedId = 3;
      await provider.loadCourses();
      delayedSettings.complete(
        const ScheduleSettingsSnapshot(showGridLines: false),
      );
      await pendingSync;
      expect(provider.currentSchedule?.id, 3);
      expect(provider.showGridLines, true);
    },
  );

  test('two sync requests apply only the newest result', () async {
    await provider.loadCourses();
    final old = Completer<CourseSyncExecutionResult>();
    final fresh = Completer<CourseSyncExecutionResult>();
    sync.syncs.addAll([old, fresh]);
    final first = provider.syncCourses('2025', '1');
    final second = provider.syncCourses('2025', '2');
    fresh.complete(_syncResult(2));
    await second;
    old.complete(_syncResult(1));
    await first;
    expect(provider.currentSchedule?.id, 2);
  });

  test(
    'failed queued settings write rethrows without poisoning the queue',
    () async {
      await provider.loadCourses();
      final gate = Completer<void>();
      store.scheduleWriteGates.add(gate);
      final started = store.scheduleWriteStarted.stream.first;
      final failing = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.totalWeeksKey,
        8,
      );
      final failure = expectLater(failing, throwsStateError);
      expect(await started, 1);
      final retry = provider.updateCurrentScheduleSetting(
        CourseSettingsStore.totalWeeksKey,
        16,
      );
      gate.completeError(StateError('fake storage failure'));
      await failure;
      await retry;
      expect(provider.totalWeeks, 16);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          store.schedulePrefKey(1, CourseSettingsStore.totalWeeksKey),
        ),
        16,
      );
    },
  );

  test('failed app write rethrows without losing the next app edit', () async {
    final gate = Completer<void>();
    store.appWriteGates.add(gate);
    final started = store.appWriteStarted.stream.first;
    final failing = provider.updateAppSetting(
      CourseSettingsStore.themeModeKey,
      'dark',
    );
    final failure = expectLater(failing, throwsStateError);
    await started;
    final retry = provider.updateAppSetting(
      CourseSettingsStore.themeSchemeKey,
      'apricot_glow',
    );
    gate.completeError(StateError('fake app storage failure'));
    await failure;
    await retry;
    expect(provider.themeMode, ThemeMode.system);
    expect(provider.themeScheme, AppThemeScheme.apricotGlow);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CourseSettingsStore.themeSchemeKey), 'apricot_glow');
  });

  test('in-flight write persists without notifying after disposal', () async {
    await provider.loadCourses();
    final gate = Completer<void>();
    store.scheduleWriteGates.add(gate);
    final started = store.scheduleWriteStarted.stream.first;
    final pending = provider.updateCurrentScheduleSetting(
      CourseSettingsStore.totalWeeksKey,
      8,
    );
    expect(await started, 1);
    provider.dispose();
    disposedInTest = true;
    gate.complete();
    await pending;
    expect(provider.totalWeeks, 20);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(store.schedulePrefKey(1, CourseSettingsStore.totalWeeksKey)),
      8,
    );
  });

  test('in-flight state load cannot notify or apply after disposal', () async {
    final delayed = Completer<CourseScheduleState>();
    schedules.loads.add(delayed);
    final pending = provider.loadCourses();
    provider.dispose();
    disposedInTest = true;
    delayed.complete(_state(2));
    await pending;
    expect(provider.currentSchedule, isNull);
  });

  testWidgets(
    'disposed provider does not reschedule an in-flight widget update',
    (tester) async {
      provider.dispose();
      provider = CourseProvider(courseSettingsStore: _WidgetSettingsStore());
      final firstCall = Completer<bool>();
      var widgetStarts = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('home_widget');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveWidgetData' &&
            (call.arguments as Map)['id'] == 'theme_scheme') {
          widgetStarts++;
          if (widgetStarts == 1) return firstCall.future;
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final firstUpdate = provider.updateAppSetting(
        CourseSettingsStore.themeModeKey,
        'dark',
      );
      await tester.pump();
      await firstUpdate;
      await tester.pump(const Duration(milliseconds: 181));
      expect(widgetStarts, 1);
      final secondUpdate = provider.updateAppSetting(
        CourseSettingsStore.themeSchemeKey,
        'apricot_glow',
      );
      await tester.pump();
      await secondUpdate;
      provider.dispose();
      disposedInTest = true;
      firstCall.complete(true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(widgetStarts, 1);
    },
  );

  testWidgets('widget debounce still flushes a newer generation', (
    tester,
  ) async {
    provider.dispose();
    provider = CourseProvider(courseSettingsStore: _WidgetSettingsStore());
    final firstCall = Completer<bool>();
    var widgetStarts = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('home_widget');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveWidgetData' &&
          (call.arguments as Map)['id'] == 'theme_scheme') {
        widgetStarts++;
        if (widgetStarts == 1) return firstCall.future;
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final first = provider.updateAppSetting(
      CourseSettingsStore.themeModeKey,
      'dark',
    );
    await tester.pump();
    await first;
    await tester.pump(const Duration(milliseconds: 181));
    expect(widgetStarts, 1);
    final second = provider.updateAppSetting(
      CourseSettingsStore.themeSchemeKey,
      'apricot_glow',
    );
    await tester.pump();
    await second;
    firstCall.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    expect(widgetStarts, 2);
  });

  test(
    'initial settings load does not notify or mutate after disposal',
    () async {
      provider.dispose();
      await store.close();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CourseSettingsStore.themeModeKey, 'dark');
      store = _SettingsStore();
      final gate = Completer<void>();
      store.initialAppRead = gate;
      store.initialAppReadReturned = Completer<void>();
      provider = CourseProvider(
        courseSettingsStore: store,
        courseScheduleManager: schedules,
      );
      provider.dispose();
      disposedInTest = true;
      gate.complete();
      await store.initialAppReadReturned!.future;
      expect(provider.themeMode, ThemeMode.system);
    },
  );
}
