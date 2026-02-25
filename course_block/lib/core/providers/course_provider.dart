import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/models/schedule.dart';
import '../../core/services/course_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  List<Schedule> _schedules = [];
  Schedule? _currentSchedule;
  bool _isLoading = false;
  int _currentWeek = 1; // Displayed week

  // Settings
  bool _showGridLines = true;
  bool _showNonCurrentWeek = false;
  bool _showSaturday = true;
  bool _showSunday = true;
  int _maxDailyClasses = 14;
  int _totalWeeks = 20;
  double _gridHeight = 64.0;
  double _cornerRadius = 4.0;
  int? _backgroundColorValue;
  String? _backgroundImagePath;
  double _backgroundImageOpacity = 0.3;

  List<Course> get courses => _courses;
  List<Schedule> get schedules => _schedules;
  Schedule? get currentSchedule => _currentSchedule;
  bool get isLoading => _isLoading;
  int get currentWeek => _currentWeek;

  // Settings getters
  bool get showGridLines => _showGridLines;
  bool get showNonCurrentWeek => _showNonCurrentWeek;
  bool get showSaturday => _showSaturday;
  bool get showSunday => _showSunday;
  int get maxDailyClasses => _maxDailyClasses;
  int get totalWeeks => _totalWeeks;
  double get gridHeight => _gridHeight;
  double get cornerRadius => _cornerRadius;
  Color? get backgroundColor =>
      _backgroundColorValue != null ? Color(_backgroundColorValue!) : null;
  String? get backgroundImagePath => _backgroundImagePath;
  double get backgroundImageOpacity => _backgroundImageOpacity;

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
    _backgroundColorValue = prefs.getInt('background_color');
    _backgroundImagePath = prefs.getString('background_image_path');
    _backgroundImageOpacity =
        prefs.getDouble('background_image_opacity') ?? 0.3;
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
    } else if (value is int) {
      await prefs.setInt(key, value);
      if (key == 'max_daily_classes') _maxDailyClasses = value;
      if (key == 'total_weeks') _totalWeeks = value;
      if (key == 'background_color') _backgroundColorValue = value;
    } else if (value is double) {
      await prefs.setDouble(key, value);
      if (key == 'grid_height') _gridHeight = value;
      if (key == 'corner_radius') _cornerRadius = value;
      if (key == 'background_image_opacity') _backgroundImageOpacity = value;
    } else if (value is String) {
      await prefs.setString(key, value);
      if (key == 'background_image_path') _backgroundImagePath = value;
    }
    notifyListeners();
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load schedules
      _schedules = await DatabaseHelper.instance.getAllSchedules();

      // Load current schedule
      _currentSchedule = await DatabaseHelper.instance.getCurrentSchedule();

      if (_currentSchedule == null) {
        if (_schedules.isNotEmpty) {
          _currentSchedule = _schedules.first;
          await DatabaseHelper.instance.setCurrentSchedule(
            _currentSchedule!.id!,
          );
        } else {
          // No schedules, creating default? Or wait for sync?
          // Let's create a default one if none exist
          final now = DateTime.now();
          // Start of this week (Monday)
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
        // Calculate current week based on start date
        final diff = DateTime.now()
            .difference(_currentSchedule!.startDate)
            .inDays;
        _currentWeek = (diff / 7).floor() + 1;
        if (_currentWeek < 1) _currentWeek = 1;
        // if (_currentWeek > 20) _currentWeek = 20; // Optional cap
      }

      if (_currentSchedule != null && _currentSchedule!.id != null) {
        _courses = await DatabaseHelper.instance.getCoursesBySchedule(
          _currentSchedule!.id!,
        );
      } else {
        _courses = [];
      }
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

      // Create or update schedule for this sync
      Schedule? targetSchedule;

      // Check if we already have a schedule for this year/term
      // Logic: If current schedule matches, update it. If not, create new?
      // For simplicity, let's assume we are updating the current active schedule or creating a new one if requested.
      // But typically "Sync" implies pulling data for the *current context*.

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
        // Update year/term if different? Or just trust the user synced into the right bucket.
        // Let's keep it simple: Syncing updates the CURRENT schedule's courses.
      }

      if (fetchedCourses.isNotEmpty && targetSchedule.id != null) {
        await DatabaseHelper.instance.deleteCoursesBySchedule(
          targetSchedule.id!,
        );

        // Deduplicate courses based on key properties
        final uniqueCourses = <String, Course>{};
        for (var course in fetchedCourses) {
          // Generate a unique key for the course
          final key =
              '${course.courseName}_${course.teacher}_${course.dayOfWeek}_${course.startNode}_${course.startWeek}_${course.endWeek}';
          if (!uniqueCourses.containsKey(key)) {
            uniqueCourses[key] = course;
          }
        }

        for (var course in uniqueCourses.values) {
          // Inject scheduleId
          // Since course model is immutable and we fetch it from service without scheduleId,
          // we need to recreate it or map it.
          // Course.fromMap won't work because it expects a map.
          // Best way: Create a copyWith or new instance.

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
      return fetchedCourses.length;
    } catch (e) {
      debugPrint('Error syncing courses: $e');
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentWeek(int week) {
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
    // Delete courses first (manual cascade)
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
}
