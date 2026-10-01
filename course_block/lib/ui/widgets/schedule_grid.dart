import 'package:flutter/material.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/course_occurrences.dart';
import '../../core/utils/time_slots.dart';
import '../course/add_course_screen.dart';

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.currentWeek,
    required this.totalWeeks,
    required this.maxDailyClasses,
    required this.showGridLines,
    required this.showNonCurrentWeek,
    required this.showSaturday,
    required this.showSunday,
    required this.outlineText,
    required this.gridHeight,
    required this.cornerRadius,
    required this.courseColorPalette,
    this.startDate,
    this.now,
    required this.onRefreshRequested,
  });

  final List<Course> courses;
  final int currentWeek;
  final int totalWeeks;
  final int maxDailyClasses;
  final bool showGridLines;
  final bool showNonCurrentWeek;
  final bool showSaturday;
  final bool showSunday;
  final bool outlineText;
  final double gridHeight;
  final double cornerRadius;
  final AppCourseColorPalette courseColorPalette;
  final DateTime? startDate;
  final DateTime? now;
  final Future<void> Function() onRefreshRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final brightness = theme.brightness;

    final showWeekend = showSaturday || showSunday;
    final daysToShow = showWeekend ? 7 : 5;

    // Capture "now" once per build instead of calling DateTime.now() for every
    // header cell, and precompute whether each course meets in the current week
    // so the (course, week) check isn't recomputed across filtering, layout and
    // rendering.
    final DateTime now = this.now ?? DateTime.now();
    bool isToday(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;

    final Map<Course, bool> inWeek = {
      for (final course in courses)
        course: _isCourseInWeek(course, currentWeek),
    };

    final DateTime anchorDate = startDate ?? now;
    // Without a term start, the selected week has no calendar anchor.
    final int displayWeek = startDate == null ? 1 : currentWeek;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double timeColumnWidth = 30.0;
        const double headerHeight = 60.0;
        final double rowHeight = gridHeight;
        final int classCount = maxDailyClasses;

        final double availableWidth = constraints.maxWidth - timeColumnWidth;
        final double dayColumnWidth = availableWidth / daysToShow;
        final double weekendColumnWidth = dayColumnWidth;

        final double bodyHeight = classCount * rowHeight;

        final List<Course> candidates = courses.where((course) {
          if (!(inWeek[course] ?? false) && !showNonCurrentWeek) {
            return false;
          }
          if (course.dayOfWeek > 5 && !showWeekend) return false;
          if (course.dayOfWeek == 6 && !showSaturday) return false;
          if (course.dayOfWeek == 7 && !showSunday) return false;
          if (course.dayOfWeek - 1 >= daysToShow) return false;
          return true;
        }).toList();

        final List<Course> displayCourses = [];
        bool overlaps(Course a, Course b) {
          return a.dayOfWeek == b.dayOfWeek &&
              !(a.startNode + a.step <= b.startNode ||
                  b.startNode + b.step <= a.startNode);
        }

        for (final course in candidates) {
          if ((inWeek[course] ?? false) && !course.isVirtual) {
            displayCourses.add(course);
          }
        }
        for (final course in candidates) {
          if ((inWeek[course] ?? false) && course.isVirtual) {
            final conflict = displayCourses.any(
              (other) => overlaps(course, other),
            );
            if (!conflict) {
              displayCourses.add(course);
            }
          }
        }
        for (final course in candidates) {
          if (!(inWeek[course] ?? false)) {
            final conflictWithCurrent = displayCourses.any(
              (other) => (inWeek[other] ?? false) && overlaps(course, other),
            );
            if (!conflictWithCurrent) {
              displayCourses.add(course);
            }
          }
        }

        final Map<Course, int> courseIndex = {};
        final Map<Course, int> courseTotal = {};
        for (int day = 1; day <= daysToShow; day++) {
          final daily = displayCourses
              .where((course) => course.dayOfWeek == day)
              .toList();
          if (daily.isEmpty) continue;
          daily.sort((a, b) => a.startNode.compareTo(b.startNode));
          final groups = <List<Course>>[];
          for (final course in daily) {
            var placed = false;
            for (final group in groups) {
              final overlap = group.any(
                (other) =>
                    !(course.startNode + course.step <= other.startNode ||
                        other.startNode + other.step <= course.startNode),
              );
              if (overlap) {
                group.add(course);
                placed = true;
                break;
              }
            }
            if (!placed) {
              groups.add([course]);
            }
          }
          for (final group in groups) {
            final count = group.length;
            for (int index = 0; index < count; index++) {
              courseIndex[group[index]] = index;
              courseTotal[group[index]] = count;
            }
          }
        }

        // Precompute each card's geometry + color once per build. The cards are
        // then drawn by a single CustomPainter instead of one widget subtree per
        // course, so a course-heavy week no longer builds/lays-out/rasterizes N
        // card widgets on the frame it first materializes (the paging jank).
        final List<_CardPlacement> placements = [
          for (final course in displayCourses)
            _CardPlacement(
              course: course,
              inWeek: inWeek[course] ?? false,
              color: _getCourseColor(
                course,
                inWeek[course] ?? false,
                palette,
                courseColorPalette,
                brightness,
              ),
              rect: Rect.fromLTWH(
                timeColumnWidth +
                    (course.dayOfWeek - 1) * dayColumnWidth +
                    1 +
                    ((courseIndex[course] ?? 0) *
                        ((dayColumnWidth - 2) / (courseTotal[course] ?? 1))),
                ((course.startNode - 1) * rowHeight) + 1,
                ((dayColumnWidth - 2) / (courseTotal[course] ?? 1)) - 2,
                course.step * rowHeight - 2,
              ),
            ),
        ];

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
                                final date = courseDateForWeek(
                                  anchorDate,
                                  displayWeek,
                                  i + 1,
                                );
                                var status = '';
                                final termStartDate = startDate;
                                if (termStartDate != null) {
                                  final termWeek = courseWeekForDate(
                                    termStartDate,
                                    date,
                                  );
                                  if (termWeek < 1) {
                                    status = '(学期未开始)';
                                  } else if (termWeek > totalWeeks) {
                                    status = '(学期已结束)';
                                  }
                                }
                                return Column(
                                  children: [
                                    Text(
                                      '${date.month}/${date.day}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isToday(date)
                                            ? palette.gridTodayText
                                            : palette.gridMinorText,
                                        fontWeight: isToday(date)
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
                // Cache the scrolling body as its own layer so dragging only
                // re-composites a rasterized layer instead of repainting every
                // course card (with its blur shadows / outlined text) per frame.
                child: RepaintBoundary(
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
                        Positioned.fill(
                          child: _CourseCardLayer(
                            placements: placements,
                            cornerRadius: cornerRadius,
                            outlineText: outlineText,
                            outlineColor: palette.courseOutline,
                            textShadowColor: palette.courseTextShadow,
                            nonCurrentLabelColor: palette.nonCurrentCourseLabel,
                            onTapCourse: (course) =>
                                _showCourseDetail(context, course),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCourseDetail(BuildContext context, Course course) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final accentColor = _getCourseColor(
      course,
      _isCourseInWeek(course, currentWeek),
      palette,
      courseColorPalette,
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
                                ).then((_) => onRefreshRequested());
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
                                      await onRefreshRequested();
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

  bool _isCourseInWeek(Course course, int currentWeek) =>
      courseOccursInWeek(course, currentWeek);

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

/// Geometry + resolved color for one course card, computed once per build so
/// the painter does no per-frame layout work.
class _CardPlacement {
  const _CardPlacement({
    required this.course,
    required this.inWeek,
    required this.color,
    required this.rect,
  });

  final Course course;
  final bool inWeek;
  final Color color;
  final Rect rect;
}

/// Draws every course card for a week in a single CustomPaint and hit-tests
/// taps against the precomputed rects. Replaces the former one-widget-subtree-
/// per-course layout, whose build/layout/first-raster cost scaled with course
/// count and produced the paging jank on course-heavy weeks.
class _CourseCardLayer extends StatelessWidget {
  const _CourseCardLayer({
    required this.placements,
    required this.cornerRadius,
    required this.outlineText,
    required this.outlineColor,
    required this.textShadowColor,
    required this.nonCurrentLabelColor,
    required this.onTapCourse,
  });

  final List<_CardPlacement> placements;
  final double cornerRadius;
  final bool outlineText;
  final Color outlineColor;
  final Color textShadowColor;
  final Color nonCurrentLabelColor;
  final ValueChanged<Course> onTapCourse;

  void _handleTapUp(TapUpDetails details) {
    final Offset local = details.localPosition;
    // Topmost (last-painted) card wins, matching the old Stack paint order.
    for (int i = placements.length - 1; i >= 0; i--) {
      if (placements[i].rect.contains(local)) {
        onTapCourse(placements[i].course);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _handleTapUp,
      child: CustomPaint(
        painter: _CourseCardPainter(
          placements: placements,
          cornerRadius: cornerRadius,
          outlineText: outlineText,
          outlineColor: outlineColor,
          textShadowColor: textShadowColor,
          nonCurrentLabelColor: nonCurrentLabelColor,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _CourseCardPainter extends CustomPainter {
  _CourseCardPainter({
    required this.placements,
    required this.cornerRadius,
    required this.outlineText,
    required this.outlineColor,
    required this.textShadowColor,
    required this.nonCurrentLabelColor,
    required this.textDirection,
  });

  final List<_CardPlacement> placements;
  final double cornerRadius;
  final bool outlineText;
  final Color outlineColor;
  final Color textShadowColor;
  final Color nonCurrentLabelColor;
  final TextDirection textDirection;

  static const double _padding = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..isAntiAlias = true;

    for (final placement in placements) {
      final Rect rect = placement.rect;
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(cornerRadius),
      );
      fill.color = placement.color;
      canvas.drawRRect(rrect, fill);

      final double innerWidth = rect.width - _padding * 2;
      if (innerWidth <= 0) continue;

      // Clip to the card so long names/rooms don't bleed past the rounded edge.
      canvas.save();
      canvas.clipRRect(rrect);

      final List<_CardLine> lines = [
        _CardLine(
          text: placement.course.courseName,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          maxLines: 4,
        ),
        _CardLine(
          text: '@${placement.course.classRoom}',
          fontSize: 9,
          fontWeight: FontWeight.normal,
          maxLines: 3,
        ),
        if (!placement.inWeek)
          _CardLine(
            text: '(非本周)',
            fontSize: 9,
            fontWeight: FontWeight.normal,
            maxLines: 1,
            color: nonCurrentLabelColor,
            italic: true,
          ),
      ];

      final List<TextPainter> painters = [
        for (final line in lines) _layoutLine(line, innerWidth),
      ];

      double totalHeight = 0;
      for (final tp in painters) {
        totalHeight += tp.height;
      }

      // Vertically center the text block within the card, like the old
      // Column(mainAxisAlignment: center).
      double dy = rect.top + (rect.height - totalHeight) / 2;
      if (dy < rect.top + _padding) dy = rect.top + _padding;
      final double left = rect.left + _padding;
      for (int i = 0; i < painters.length; i++) {
        final TextPainter tp = painters[i];
        final double dx = left + (innerWidth - tp.width) / 2;
        final Offset offset = Offset(dx, dy);
        // outlineText mode: draw a thin stroke underneath the fill, matching
        // the old _outlinedText two-pass Stack.
        if (outlineText) {
          final TextPainter stroke = _layoutLine(lines[i], innerWidth, stroke: true);
          stroke.paint(canvas, offset);
        }
        tp.paint(canvas, offset);
        dy += tp.height;
      }

      canvas.restore();
    }
  }

  TextPainter _layoutLine(_CardLine line, double maxWidth, {bool stroke = false}) {
    final Color textColor = line.color ?? Colors.white;
    final TextStyle style = stroke
        ? TextStyle(
            fontSize: line.fontSize,
            fontWeight: line.fontWeight,
            fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5
              ..color = outlineColor,
          )
        : outlineText
        ? TextStyle(
            color: textColor,
            fontSize: line.fontSize,
            fontWeight: line.fontWeight,
            fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
          )
        : TextStyle(
            color: textColor,
            fontSize: line.fontSize,
            fontWeight: line.fontWeight,
            fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                // blurRadius 0：纯偏移投影，避免文字模糊带来的离屏 pass
                // （Impeller/Vulkan 在本机型上模糊光栅化开销过高）。
                blurRadius: 0,
                color: textShadowColor,
              ),
            ],
          );

    final TextPainter tp = TextPainter(
      text: TextSpan(text: line.text, style: style),
      textAlign: TextAlign.center,
      textDirection: textDirection,
      maxLines: line.maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  @override
  bool shouldRepaint(covariant _CourseCardPainter oldDelegate) {
    return oldDelegate.placements != placements ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.outlineText != outlineText ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.textShadowColor != textShadowColor ||
        oldDelegate.nonCurrentLabelColor != nonCurrentLabelColor ||
        oldDelegate.textDirection != textDirection;
  }
}

class _CardLine {
  const _CardLine({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.maxLines,
    this.color,
    this.italic = false,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final int maxLines;
  final Color? color;
  final bool italic;
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
