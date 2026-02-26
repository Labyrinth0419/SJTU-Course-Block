import 'package:flutter/material.dart';
import '../../core/models/course.dart';
import '../course/add_course_screen.dart';
import 'package:provider/provider.dart';
import '../../core/providers/course_provider.dart';
import '../../core/db/database_helper.dart';
import 'dart:io';

class ScheduleGrid extends StatelessWidget {
  final List<Course> courses;
  final int currentWeek;
  final DateTime? startDate;

  static const List<String> startTimes = [
    "8:00",
    "8:55",
    "10:00",
    "10:55",
    "12:00",
    "12:55",
    "14:00",
    "14:55",
    "16:00",
    "16:55",
    "18:00",
    "18:55",
    "20:00",
    "20:55",
  ];

  static const List<String> endTimes = [
    "8:45",
    "9:40",
    "10:45",
    "11:40",
    "12:45",
    "13:40",
    "14:45",
    "15:40",
    "16:45",
    "17:40",
    "18:45",
    "19:40",
    "20:45",
    "21:40",
  ];

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.currentWeek,
    this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseProvider>();
    final showGridLines = provider.showGridLines;
    final showNonCurrentWeek = provider.showNonCurrentWeek;
    final brightness = Theme.of(context).brightness;
    final backgroundColor =
        (brightness == Brightness.dark
            ? provider.backgroundColorDark
            : provider.backgroundColorLight) ??
        Theme.of(context).colorScheme.background;
    final backgroundImagePath = provider.backgroundImagePath;
    final backgroundImageOpacity = provider.backgroundImageOpacity;
    final gridHeight = provider.gridHeight;
    final cornerRadius = provider.cornerRadius;

    final showWeekend = provider.showSaturday || provider.showSunday;
    final daysToShow = showWeekend ? 7 : 5;

    final DateTime viewStartDate = (startDate ?? DateTime.now()).add(
      Duration(days: (currentWeek - 1) * 7),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration:
            backgroundImagePath != null && backgroundImagePath.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(backgroundImagePath)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(backgroundImageOpacity),
                    BlendMode.dstATop,
                  ),
                ),
              )
            : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double timeColumnWidth = 30.0;
            const double headerHeight = 60.0;
            final double rowHeight = gridHeight;
            final int classCount = provider.maxDailyClasses;

            final double availableWidth =
                constraints.maxWidth - timeColumnWidth;
            final double dayColumnWidth = availableWidth / daysToShow;
            final double weekendColumnWidth = dayColumnWidth;

            final double totalHeight = headerHeight + (classCount * rowHeight);

            final List<Course> candidates = courses.where((course) {
              if (!_isCourseInWeek(course, currentWeek) && !showNonCurrentWeek)
                return false;
              if (course.dayOfWeek > 5 && !showWeekend) return false;
              if (course.dayOfWeek == 6 && !provider.showSaturday) return false;
              if (course.dayOfWeek == 7 && !provider.showSunday) return false;
              if (course.dayOfWeek - 1 >= daysToShow) return false;
              return true;
            }).toList();

            final List<Course> displayCourses = [];
            bool overlaps(Course a, Course b) {
              return a.dayOfWeek == b.dayOfWeek &&
                  !(a.startNode + a.step <= b.startNode ||
                      b.startNode + b.step <= a.startNode);
            }

            for (var c in candidates) {
              if (_isCourseInWeek(c, currentWeek) && !c.isVirtual) {
                displayCourses.add(c);
              }
            }
            for (var c in candidates) {
              if (_isCourseInWeek(c, currentWeek) && c.isVirtual) {
                bool conflict = displayCourses.any(
                  (other) => overlaps(c, other),
                );
                if (!conflict) displayCourses.add(c);
              }
            }
            for (var c in candidates) {
              if (!_isCourseInWeek(c, currentWeek)) {
                bool conflictWithCurrent = displayCourses.any(
                  (other) =>
                      _isCourseInWeek(other, currentWeek) && overlaps(c, other),
                );
                if (!conflictWithCurrent) displayCourses.add(c);
              }
            }

            final Map<Course, int> courseIndex = {};
            final Map<Course, int> courseTotal = {};
            for (int day = 1; day <= daysToShow; day++) {
              final daily = displayCourses
                  .where((c) => c.dayOfWeek == day)
                  .toList();
              if (daily.isEmpty) continue;
              daily.sort((a, b) => a.startNode.compareTo(b.startNode));
              List<List<Course>> groups = [];
              for (var course in daily) {
                bool placed = false;
                for (var group in groups) {
                  bool ov = group.any(
                    (c) =>
                        !(course.startNode + course.step <= c.startNode ||
                            c.startNode + c.step <= course.startNode),
                  );
                  if (ov) {
                    group.add(course);
                    placed = true;
                    break;
                  }
                }
                if (!placed) groups.add([course]);
              }
              for (var group in groups) {
                int cnt = group.length;
                for (int i = 0; i < cnt; i++) {
                  courseIndex[group[i]] = i;
                  courseTotal[group[i]] = cnt;
                }
              }
            }

            return SingleChildScrollView(
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(constraints.maxWidth, totalHeight),
                      painter: GridPainter(
                        timeColumnWidth: timeColumnWidth,
                        dayColumnWidth: dayColumnWidth,
                        weekendColumnWidth: weekendColumnWidth,
                        headerHeight: headerHeight,
                        rowHeight: rowHeight,
                        daysToShow: daysToShow,
                        showGridLines: showGridLines,
                        classCount: classCount,
                      ),
                    ),

                    for (int i = 0; i < classCount; i++)
                      Positioned(
                        top: headerHeight + (i * rowHeight),
                        left: 0,
                        width: timeColumnWidth,
                        height: rowHeight,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                startTimes[i],
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                endTimes[i],
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    for (int i = 0; i < daysToShow; i++)
                      Positioned(
                        top: 0,
                        left: timeColumnWidth + (i * dayColumnWidth),
                        width: dayColumnWidth,
                        height: headerHeight,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getDayName(i),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Builder(
                                builder: (ctx) {
                                  final date = viewStartDate.add(
                                    Duration(days: i),
                                  );
                                  String status = '';
                                  final start =
                                      startDate ??
                                      provider.currentSchedule?.startDate;
                                  final len = provider.totalWeeks;
                                  if (start != null) {
                                    if (date.isBefore(start)) {
                                      status = '(学期未开始)';
                                    } else if (date.isAfter(
                                      start.add(Duration(days: len * 7 - 1)),
                                    )) {
                                      status = '(学期已结束)';
                                    }
                                  }
                                  return Column(
                                    children: [
                                      Text(
                                        "${date.month}/${date.day}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              (date.year ==
                                                      DateTime.now().year &&
                                                  date.month ==
                                                      DateTime.now().month &&
                                                  date.day ==
                                                      DateTime.now().day)
                                              ? Colors.blue
                                              : Colors.grey,
                                          fontWeight:
                                              (date.year ==
                                                      DateTime.now().year &&
                                                  date.month ==
                                                      DateTime.now().month &&
                                                  date.day ==
                                                      DateTime.now().day)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (status.isNotEmpty)
                                        Text(
                                          status,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    for (var course in displayCourses)
                      Positioned(
                        top:
                            headerHeight +
                            ((course.startNode - 1) * rowHeight) +
                            1,
                        left:
                            timeColumnWidth +
                            (course.dayOfWeek - 1) * dayColumnWidth +
                            1 +
                            ((courseIndex[course] ?? 0) *
                                ((dayColumnWidth - 2) /
                                    (courseTotal[course] ?? 1))),
                        width:
                            ((dayColumnWidth - 2) /
                                (courseTotal[course] ?? 1)) -
                            2,
                        height: course.step * rowHeight - 2,
                        child: GestureDetector(
                          onTap: () =>
                              _showCourseDetail(context, course, provider),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getCourseColor(
                                course,
                                _isCourseInWeek(course, currentWeek),
                              ),
                              borderRadius: BorderRadius.circular(cornerRadius),
                            ),
                            padding: const EdgeInsets.all(2.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                provider.outlineText
                                    ? _outlinedText(
                                        course.courseName,
                                        baseStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 4,
                                      )
                                    : Text(
                                        course.courseName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                              color: Colors.black26,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                provider.outlineText
                                    ? _outlinedText(
                                        '@${course.classRoom}',
                                        baseStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                        ),
                                        maxLines: 3,
                                      )
                                    : Text(
                                        '@${course.classRoom}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                              color: Colors.black26,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                if (!_isCourseInWeek(course, currentWeek))
                                  const Text(
                                    '(非本周)',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCourseDetail(
    BuildContext context,
    Course course,
    CourseProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(course.courseName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('教师: ${course.teacher}'),
              Text('教室: ${course.classRoom}'),
              Text('周次: ${course.startWeek}-${course.endWeek}周'),
              Text(
                '时间: ${_getDayName(course.dayOfWeek - 1)} ${course.startNode}-${course.startNode + course.step - 1}节',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除课程'),
                    content: const Text('确定要删除这门课程吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await DatabaseHelper.instance.deleteCourse(course.id!);
                  if (context.mounted) Navigator.pop(context);
                  provider.loadCourses(recalcWeek: false);
                }
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddCourseScreen(course: course),
                  ),
                ).then((value) {
                  provider.loadCourses(recalcWeek: false);
                });
              },
              child: const Text('编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  bool _isCourseInWeek(Course course, int currentWeek) {
    if (course.weekCode != null && course.weekCode!.isNotEmpty) {
      if (currentWeek > 0 && currentWeek <= course.weekCode!.length) {
        return course.weekCode![currentWeek - 1] == '1';
      }
      return false;
    }
    if (currentWeek < course.startWeek || currentWeek > course.endWeek) {
      return false;
    }
    if (course.isOddWeek && currentWeek % 2 == 0) return false;
    if (course.isEvenWeek && currentWeek % 2 != 0) return false;
    return true;
  }

  Color _getCourseColor(Course course, bool isCurrentWeek) {
    if (course.isVirtual) return Colors.grey.shade300;

    final seed = '${course.courseName}_${course.teacher}_${course.classRoom}';
    Color color = _parseColor(course.color, seed);
    if (!isCurrentWeek) {
      return color.withOpacity(0.3);
    }
    return color;
  }

  Color _parseColor(String? colorStr, String seed) {
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (e) {
      }
    }
    final hash = seed.hashCode;
    final index = hash.abs() % Colors.primaries.length;
    return Colors.primaries[index];
  }

  String _getDayName(int index) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[index % 7];
  }

  /// Render a piece of text with a very thin black stroke (outline) beneath
  /// the normal filled white text.
  Widget _outlinedText(
    String text, {
    required TextStyle baseStyle,
    int maxLines = 1,
  }) {
    return Stack(
      children: [
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5
              ..color = Colors.black,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          text,
          style: baseStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final double timeColumnWidth;
  final double dayColumnWidth;
  final double weekendColumnWidth;
  final double headerHeight;
  final double rowHeight;
  final int daysToShow;
  final bool showGridLines;
  final int classCount;

  GridPainter({
    required this.timeColumnWidth,
    required this.dayColumnWidth,
    required this.weekendColumnWidth,
    required this.headerHeight,
    required this.rowHeight,
    this.daysToShow = 7,
    this.showGridLines = true,
    required this.classCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGridLines) return;

    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double x = timeColumnWidth;
    for (int i = 0; i <= daysToShow; i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      if (i < daysToShow) {
        x += dayColumnWidth;
      }
    }

    for (int i = 0; i <= classCount; i++) {
      double y = headerHeight + (i * rowHeight);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    paint.strokeWidth = 2.0;
    canvas.drawLine(
      Offset(0, headerHeight),
      Offset(size.width, headerHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.showGridLines != showGridLines ||
        oldDelegate.timeColumnWidth != timeColumnWidth ||
        oldDelegate.dayColumnWidth != dayColumnWidth ||
        oldDelegate.rowHeight != rowHeight;
  }
}
