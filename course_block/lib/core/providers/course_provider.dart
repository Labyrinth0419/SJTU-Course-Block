import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/models/schedule.dart';
import '../../core/services/course_service.dart';
import '../../core/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  List<Schedule> _schedules = [];
  Schedule? _currentSchedule;
  bool _isLoading = false;
  int _currentWeek = 1; // Displayed week

  bool _showGridLines = true;
  bool _showNonCurrentWeek = false;
  bool _showSaturday = true;
  bool _showSunday = true;
  bool _outlineText = false; // new setting
  ThemeMode _themeMode = ThemeMode.system; // new theme mode setting
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

  bool get showGridLines => _showGridLines;
  bool get showNonCurrentWeek => _showNonCurrentWeek;
  bool get showSaturday => _showSaturday;
  bool get showSunday => _showSunday;
  bool get outlineText => _outlineText; // new getter
  ThemeMode get themeMode => _themeMode; // new getter
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

  CourseProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showGridLines = prefs.getBool('show_grid_lines') ?? true;
    _showNonCurrentWeek = prefs.getBool('show_non_current_week') ?? false;
    _showSaturday = prefs.getBool('show_saturday') ?? true;
    _showSunday = prefs.getBool('show_sunday') ?? true;
    _maxDailyClasses = prefs.getInt('max_daily_classes') ?? 14;
    _totalWeeks = prefs.getInt('total_weeks') ?? 20;
    _gridHeight = prefs.getDouble('grid_height') ?? 64.0;
    _cornerRadius = prefs.getDouble('corner_radius') ?? 4.0;
    _backgroundImagePath = prefs.getString('background_image_path');
    _backgroundImageOpacity =
        prefs.getDouble('background_image_opacity') ?? 0.3;
    _backgroundColorLight = prefs.getInt('background_color_light');
    _backgroundColorDark = prefs.getInt('background_color_dark');
    _outlineText = prefs.getBool('outline_text') ?? false;
    _launcherIcon = prefs.getString('app_icon_choice');
    if (_launcherIcon != null) {
      _applyLauncherIcon(_launcherIcon);
    }
    final mode = prefs.getString('theme_mode');
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

  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'show_grid_lines') _showGridLines = value;
      if (key == 'show_non_current_week') _showNonCurrentWeek = value;
      if (key == 'show_saturday') _showSaturday = value;
      if (key == 'show_sunday') _showSunday = value;
      if (key == 'outline_text') _outlineText = value;
    } else if (value is int) {
      await prefs.setInt(key, value);
      if (key == 'max_daily_classes') _maxDailyClasses = value;
      if (key == 'total_weeks') {
        _totalWeeks = value;
        if (_currentWeek > _totalWeeks) {
          _currentWeek = _totalWeeks;
        }
      }
      if (key == 'background_color_light') _backgroundColorLight = value;
      if (key == 'background_color_dark') _backgroundColorDark = value;
    } else if (value is double) {
      await prefs.setDouble(key, value);
      if (key == 'grid_height') _gridHeight = value;
      if (key == 'corner_radius') _cornerRadius = value;
      if (key == 'background_image_opacity') _backgroundImageOpacity = value;
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'background_image_path') _backgroundImagePath = value;
      if (key == 'theme_mode') {
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
      if (key == 'app_icon_choice') {
        _launcherIcon = value;
        _applyLauncherIcon(value);
      }
    }
    notifyListeners();
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
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

          final defaultSchedule = Schedule(
            name: '默认课表',
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
      } else {
        if (recalcWeek || _currentSchedule?.id != oldScheduleId) {
          final diff = DateTime.now()
              .difference(_currentSchedule!.startDate)
              .inDays;
          _currentWeek = (diff / 7).floor() + 1;
          if (_currentWeek < 1) _currentWeek = 1;
          if (_currentWeek > _totalWeeks) _currentWeek = _totalWeeks;
        }
      }

      if (_currentSchedule != null && _currentSchedule!.id != null) {
        _courses = await DatabaseHelper.instance.getCoursesBySchedule(
          _currentSchedule!.id!,
        );
      } else {
        _courses = [];
      }
      // sync widget after courses have been loaded successfully
      debugPrint('CourseProvider calling WidgetService.syncTodayCourses');
      await WidgetService.syncTodayCourses();
    } catch (e) {
      debugPrint('Error loading courses/schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> syncCourses(String year, String term) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetchedCourses = await _courseService.fetchUndergraduateCourses(
        year,
        term,
      );

      if (fetchedCourses.isEmpty) {
        return 0;
      }

      Schedule? targetSchedule;

      if (_currentSchedule == null) {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

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
      } else {
        targetSchedule = _currentSchedule!;
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
      }
      final count = fetchedCourses.length;
      // update widget after sync operation
      await WidgetService.syncTodayCourses();
      return count;
    } catch (e) {
      debugPrint('Error syncing courses: $e');
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Future<void> addSchedule(String name, String year, String term) async {
    final schedule = Schedule(
      name: name,
      year: year,
      term: term,
      startDate: DateTime.now(),
      isCurrent: true, // Switch to it immediately
    );
    await DatabaseHelper.instance.insertSchedule(schedule);
    await loadCourses();
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await DatabaseHelper.instance.deleteCoursesBySchedule(scheduleId);
    await DatabaseHelper.instance.deleteSchedule(scheduleId);
    await loadCourses();
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await DatabaseHelper.instance.updateSchedule(schedule);
    await loadCourses();
  }

  Future<void> setBackgroundImage(String path) async {
    await updateSetting('background_image_path', path);
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
    for (var ev in events) {
      String? _field(String name) {
        final reg = RegExp('$name:(.+)');
        final m = reg.firstMatch(ev);
        return m?.group(1)?.trim();
      }

      final summary = _field('SUMMARY');
      final location = _field('LOCATION');
      final dtstart = _field('DTSTART');
      final duration = _field('DURATION');
      if (summary == null || dtstart == null) continue;
      DateTime dt;
      try {
        dt = DateFormat("yyyyMMdd'T'HHmmss").parse(dtstart);
      } catch (_) {
        try {
          dt = DateFormat("yyyyMMdd").parse(dtstart);
        } catch (__) {
          continue;
        }
      }
      final diff = dt.difference(startDate).inDays;
      final week = (diff / 7).floor() + 1;
      final day = dt.weekday; // 1=Mon
      int step = 1;
      if (duration != null) {
        final m = RegExp(r'PT(\d+)M').firstMatch(duration);
        if (m != null) {
          final mins = int.tryParse(m.group(1)!) ?? 0;
          step = (mins / 45).ceil();
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
          endWeek: week,
          dayOfWeek: day,
          startNode: 1,
          step: step,
          isOddWeek: false,
          isEvenWeek: false,
          weekCode: null,
          color: '#FF5722',
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
    for (var course in courses) {
      final firstDate = startDate.add(
        Duration(days: (course.startWeek - 1) * 7 + (course.dayOfWeek - 1)),
      );
      final dt = DateFormat("yyyyMMdd'T'HHmmss").format(firstDate);
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('SUMMARY:${course.courseName}');
      buffer.writeln('LOCATION:${course.classRoom}');
      buffer.writeln('DTSTART:$dt');
      final durationMinutes = 45 * course.step;
      buffer.writeln('DURATION:PT${durationMinutes}M');
      final weeks = course.endWeek - course.startWeek + 1;
      buffer.writeln('RRULE:FREQ=WEEKLY;COUNT=$weeks');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }
}
