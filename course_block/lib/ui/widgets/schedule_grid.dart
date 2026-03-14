import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/providers/course_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_slots.dart';
import '../course/add_course_screen.dart';

class ScheduleGrid extends StatelessWidget {
  final List<Course> courses;
  final int currentWeek;
  final DateTime? startDate;

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.currentWeek,
    this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseProvider>();
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final showGridLines = provider.showGridLines;
    final showNonCurrentWeek = provider.showNonCurrentWeek;
    final brightness = theme.brightness;
    final backgroundColor =
        (brightness == Brightness.dark
            ? provider.backgroundColorDark
            : provider.backgroundColorLight) ??
        theme.scaffoldBackgroundColor;
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
                    palette.backgroundImageOverlay.withValues(
                      alpha: backgroundImageOpacity,
                    ),
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

            final double bodyHeight = classCount * rowHeight;

            final List<Course> candidates = courses.where((course) {
              if (!_isCourseInWeek(course, currentWeek) &&
                  !showNonCurrentWeek) {
                return false;
              }
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

            return Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(constraints.maxWidth, headerHeight),
                        painter: GridPainter(
                          timeColumnWidth: timeColumnWidth,
                          dayColumnWidth: dayColumnWidth,
                          weekendColumnWidth: weekendColumnWidth,
                          rowHeight: rowHeight,
                          daysToShow: daysToShow,
                          showGridLines: showGridLines,
                          classCount: 0,
                          lineColor: palette.gridLineColor,
                          drawRows: false,
                          drawBottomBorder: true,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
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
                                            color: _isToday(date)
                                                ? palette.gridTodayText
                                                : palette.gridMinorText,
                                            fontWeight: _isToday(date)
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (status.isNotEmpty)
                                          Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: palette.gridOutOfTermText,
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
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: bodyHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, bodyHeight),
                            painter: GridPainter(
                              timeColumnWidth: timeColumnWidth,
                              dayColumnWidth: dayColumnWidth,
                              weekendColumnWidth: weekendColumnWidth,
                              rowHeight: rowHeight,
                              daysToShow: daysToShow,
                              showGridLines: showGridLines,
                              classCount: classCount,
                              lineColor: palette.gridLineColor,
                              drawRows: true,
                              drawBottomBorder: false,
                            ),
                          ),
                          for (int i = 0; i < classCount; i++)
                            Positioned(
                              top: i * rowHeight,
                              left: 0,
                              width: timeColumnWidth,
                              height: rowHeight,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      kClassStartTimes[i],
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: palette.gridMinorText,
                                      ),
                                    ),
                                    Text(
                                      kClassEndTimes[i],
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: palette.gridMinorText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          for (var course in displayCourses)
                            Positioned(
                              top: ((course.startNode - 1) * rowHeight) + 1,
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
                                onTap: () => _showCourseDetail(
                                  context,
                                  course,
                                  provider,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getCourseColor(
                                      course,
                                      _isCourseInWeek(course, currentWeek),
                                      palette,
                                      provider.courseColorPalette,
                                      brightness,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      cornerRadius,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(2.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      provider.outlineText
                                          ? _outlinedText(
                                              course.courseName,
                                              baseStyle: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 4,
                                              outlineColor:
                                                  palette.courseOutline,
                                            )
                                          : Text(
                                              course.courseName,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(0, 1),
                                                    blurRadius: 2,
                                                    color: palette
                                                        .courseTextShadow,
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
                                              baseStyle: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                              ),
                                              maxLines: 3,
                                              outlineColor:
                                                  palette.courseOutline,
                                            )
                                          : Text(
                                              '@${course.classRoom}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(0, 1),
                                                    blurRadius: 2,
                                                    color: palette
                                                        .courseTextShadow,
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      if (!_isCourseInWeek(course, currentWeek))
                                        Text(
                                          '(非本周)',
                                          style: TextStyle(
                                            color:
                                                palette.nonCurrentCourseLabel,
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
                  ),
                ),
              ],
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
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final accentColor = _getCourseColor(
      course,
      _isCourseInWeek(course, currentWeek),
      palette,
      provider.courseColorPalette,
      theme.brightness,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final sheetTheme = Theme.of(dialogContext);
        final isCurrent = _isCourseInWeek(course, currentWeek);
        final statusTexts = <String>[
          if (course.isVirtual) '虚拟排课',
          isCurrent ? '本周上课' : '本周不上课',
        ];

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 380,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.66,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.floatingSheetSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sheetTheme.dividerColor.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.floatingSheetShadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.courseName,
                                  style: sheetTheme.textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                        fontSize: 18,
                                      ),
                                ),
                                if (statusTexts.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 14,
                                        color: sheetTheme
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          statusTexts.join(' · '),
                                          style: sheetTheme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: sheetTheme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: '关闭',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: sheetTheme.dividerColor.withValues(alpha: 0.18),
                        height: 1,
                      ),
                      const SizedBox(height: 10),
                      _CourseDetailRow(
                        icon: Icons.schedule_rounded,
                        label: '时间',
                        value: _formatCourseTime(course),
                        iconColor: accentColor,
                      ),
                      _CourseDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: '周次',
                        value: _formatCourseWeekText(course),
                        iconColor: sheetTheme.colorScheme.primary,
                      ),
                      _CourseDetailRow(
                        icon: Icons.location_on_outlined,
                        label: '地点',
                        value: course.classRoom.isEmpty
                            ? '未填写'
                            : course.classRoom,
                        iconColor: sheetTheme.colorScheme.tertiary,
                      ),
                      _CourseDetailRow(
                        icon: Icons.person_outline_rounded,
                        label: '教师',
                        value: course.teacher.isEmpty ? '未填写' : course.teacher,
                        iconColor: sheetTheme.colorScheme.secondary,
                      ),
                      if (course.courseId.isNotEmpty)
                        _CourseDetailRow(
                          icon: Icons.tag_rounded,
                          label: '课号',
                          value: course.courseId,
                          iconColor: sheetTheme.colorScheme.primary,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AddCourseScreen(course: course),
                                  ),
                                ).then((value) {
                                  provider.loadCourses(recalcWeek: false);
                                });
                              },
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('编辑'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                textStyle: sheetTheme.textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: course.id == null
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: dialogContext,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('删除课程'),
                                          content: const Text('确定要删除这门课程吗？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('取消'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('删除'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm != true ||
                                          course.id == null) {
                                        return;
                                      }

                                      await DatabaseHelper.instance
                                          .deleteCourse(course.id!);
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      provider.loadCourses(recalcWeek: false);
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: sheetTheme.colorScheme.error,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                textStyle: sheetTheme.textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('删除'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  Color _getCourseColor(
    Course course,
    bool isCurrentWeek,
    AppThemePalette palette,
    AppCourseColorPalette courseColorPalette,
    Brightness brightness,
  ) {
    if (course.isVirtual) return palette.virtualCourseFill;

    final seed = buildCourseColorSeed(course.courseName, course.teacher);
    Color color = resolveCourseCardColor(
      colorValue: course.color,
      palette: courseColorPalette,
      brightness: brightness,
      seed: seed,
    );
    if (!isCurrentWeek) {
      return color.withValues(alpha: palette.nonCurrentCourseAlpha);
    }
    return color;
  }

  String _getDayName(int index) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[index % 7];
  }

  String _formatCourseTime(Course course) {
    final endNode = course.startNode + course.step - 1;
    return '周${_getDayName(course.dayOfWeek - 1)} ${course.startNode}-$endNode节';
  }

  String _formatCourseWeekText(Course course) {
    final base = course.startWeek == course.endWeek
        ? '第${course.startWeek}周'
        : '${course.startWeek}-${course.endWeek}周';

    if (course.isOddWeek) {
      return '$base · 单周';
    }
    if (course.isEvenWeek) {
      return '$base · 双周';
    }
    return base;
  }

  /// Render a piece of text with a very thin black stroke (outline) beneath
  /// the normal filled white text.
  Widget _outlinedText(
    String text, {
    required TextStyle baseStyle,
    int maxLines = 1,
    required Color outlineColor,
  }) {
    return Stack(
      children: [
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5
              ..color = outlineColor,
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _CourseDetailRow extends StatelessWidget {
  const _CourseDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.26,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final double timeColumnWidth;
  final double dayColumnWidth;
  final double weekendColumnWidth;
  final double rowHeight;
  final int daysToShow;
  final bool showGridLines;
  final int classCount;
  final Color lineColor;
  final bool drawRows;
  final bool drawBottomBorder;

  GridPainter({
    required this.timeColumnWidth,
    required this.dayColumnWidth,
    required this.weekendColumnWidth,
    required this.rowHeight,
    this.daysToShow = 7,
    this.showGridLines = true,
    required this.classCount,
    required this.lineColor,
    this.drawRows = true,
    this.drawBottomBorder = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGridLines) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double x = timeColumnWidth;
    for (int i = 0; i <= daysToShow; i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      if (i < daysToShow) {
        x += dayColumnWidth;
      }
    }

    if (drawRows) {
      for (int i = 0; i <= classCount; i++) {
        double y = i * rowHeight;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (drawBottomBorder) {
      paint.strokeWidth = 2.0;
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.showGridLines != showGridLines ||
        oldDelegate.timeColumnWidth != timeColumnWidth ||
        oldDelegate.dayColumnWidth != dayColumnWidth ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.classCount != classCount ||
        oldDelegate.drawRows != drawRows ||
        oldDelegate.drawBottomBorder != drawBottomBorder;
  }
}
