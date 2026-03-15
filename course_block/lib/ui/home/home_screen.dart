import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/course.dart';
import '../../core/providers/course_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../main.dart';
import '../course/add_course_screen.dart';
import '../settings/more_functions_sheet.dart';
import '../widgets/schedule_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, WidgetsBindingObserver {
  PageController? _pageController;
  bool _controllerReady = false;
  bool _routeSubscribed = false;
  String? _backgroundImagePath;
  ImageProvider<Object>? _backgroundImageProvider;
  int _backgroundImageRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CourseProvider>();
      await provider.loadCourses();
      if (!mounted) return;

      await _syncBackgroundImage(waitForDecode: true);
      if (!mounted) return;

      setState(() {
        _pageController = PageController(initialPage: provider.currentWeek - 1);
        _controllerReady = true;
      });
    });

    context.read<CourseProvider>().addListener(_providerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CourseProvider>().removeListener(_providerListener);
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
    }
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _syncBackgroundImage({bool waitForDecode = false}) async {
    if (!mounted) return;

    final rawPath = context.read<CourseProvider>().backgroundImagePath?.trim();
    final nextPath = (rawPath == null || rawPath.isEmpty) ? null : rawPath;

    if (nextPath == _backgroundImagePath &&
        (nextPath == null || _backgroundImageProvider != null)) {
      return;
    }

    _backgroundImagePath = nextPath;
    final requestId = ++_backgroundImageRequestId;

    if (nextPath == null) {
      if (mounted) {
        setState(() {
          _backgroundImageProvider = null;
        });
      }
      return;
    }

    final imageProvider = FileImage(File(nextPath));

    Future<void> loadImage() async {
      try {
        await precacheImage(imageProvider, context);
      } catch (e) {
        debugPrint('Failed to precache schedule background: $e');
      }

      if (!mounted || requestId != _backgroundImageRequestId) {
        return;
      }

      setState(() {
        _backgroundImageProvider = imageProvider;
      });
    }

    if (waitForDecode) {
      await loadImage();
    } else {
      unawaited(loadImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<CourseProvider, bool>(
      (provider) => provider.isLoading,
    );

    if (isLoading || !_controllerReady || _pageController == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HomeHeaderSection(
              onAddCourse: _openAddCourseScreen,
              onImportSelected: (action) =>
                  handleImportMenuAction(context, action),
              onExportSelected: (action) =>
                  handleExportMenuAction(context, action),
              onOpenMore: () => showMoreFunctionsSheet(context),
            ),
            Expanded(
              child: _HomeScheduleViewport(
                controller: _pageController!,
                backgroundImageProvider: _backgroundImageProvider,
                onPageChanged: (index) {
                  final provider = context.read<CourseProvider>();
                  if (provider.currentWeek != index + 1) {
                    provider.setCurrentWeek(index + 1);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddCourseScreen() async {
    final provider = context.read<CourseProvider>();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCourseScreen()));
    if (!mounted) return;
    await provider.loadCourses(recalcWeek: false);
  }

  void _providerListener() {
    if (!mounted || _pageController == null) return;

    unawaited(_syncBackgroundImage());

    final provider = context.read<CourseProvider>();
    final target = provider.currentWeek - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController == null || !_pageController!.hasClients) {
        return;
      }

      final page =
          _pageController!.page ?? _pageController!.initialPage.toDouble();
      if (page.round() != target) {
        _pageController!.jumpToPage(target);
      }
    });
  }

  void _ensureCorrectPage() {
    if (_pageController?.hasClients != true) return;
    final provider = context.read<CourseProvider>();
    final maxPage = provider.totalWeeks - 1;
    final currentPage = _pageController!.page ?? _pageController!.initialPage;
    if (currentPage < 0 || currentPage > maxPage) {
      _pageController!.jumpToPage(provider.currentWeek - 1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CourseProvider>().loadCourses().then((_) {
        if (!mounted) return;
        unawaited(_syncBackgroundImage());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureCorrectPage();
        });
      });
    }
  }

  @override
  void didPopNext() {
    unawaited(_syncBackgroundImage());
    _ensureCorrectPage();
  }
}

class _HomeHeaderSection extends StatelessWidget {
  const _HomeHeaderSection({
    required this.onAddCourse,
    required this.onImportSelected,
    required this.onExportSelected,
    required this.onOpenMore,
  });

  final VoidCallback onAddCourse;
  final ValueChanged<ImportMenuAction> onImportSelected;
  final ValueChanged<ExportMenuAction> onExportSelected;
  final VoidCallback onOpenMore;

  String _weekDayToString(int weekDay) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekDays[weekDay - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Selector<CourseProvider, ({int currentWeek, String scheduleName})>(
      selector: (_, provider) => (
        currentWeek: provider.currentWeek,
        scheduleName: provider.currentSchedule?.name ?? '未命名课表',
      ),
      builder: (context, data, _) {
        final now = DateTime.now();
        final subtitle =
            '第${data.currentWeek}周  ${_weekDayToString(now.weekday)} · ${data.scheduleName}';

        return _HomeHeader(
          dateText: '${now.year}/${now.month}/${now.day}',
          subtitle: subtitle,
          onAddCourse: onAddCourse,
          onImportSelected: onImportSelected,
          onExportSelected: onExportSelected,
          onOpenMore: onOpenMore,
        );
      },
    );
  }
}

class _HomeScheduleViewport extends StatelessWidget {
  const _HomeScheduleViewport({
    required this.controller,
    required this.backgroundImageProvider,
    required this.onPageChanged,
  });

  final PageController controller;
  final ImageProvider<Object>? backgroundImageProvider;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Selector<CourseProvider, _ScheduleViewportData>(
      selector: (_, provider) => _ScheduleViewportData(
        courses: provider.courses,
        totalWeeks: provider.totalWeeks,
        startDate: provider.currentSchedule?.startDate,
        showGridLines: provider.showGridLines,
        showNonCurrentWeek: provider.showNonCurrentWeek,
        showSaturday: provider.showSaturday,
        showSunday: provider.showSunday,
        outlineText: provider.outlineText,
        maxDailyClasses: provider.maxDailyClasses,
        gridHeight: provider.gridHeight,
        cornerRadius: provider.cornerRadius,
        courseColorPalette: provider.courseColorPalette,
        backgroundColorLight: provider.backgroundColorLight,
        backgroundColorDark: provider.backgroundColorDark,
        backgroundImageOpacity: provider.backgroundImageOpacity,
      ),
      builder: (context, data, _) {
        final theme = Theme.of(context);
        final palette = context.appTheme;
        final brightness = theme.brightness;
        final backgroundColor =
            (brightness == Brightness.dark
                ? data.backgroundColorDark
                : data.backgroundColorLight) ??
            theme.scaffoldBackgroundColor;

        return DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundImageProvider != null)
                RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: backgroundImageProvider!,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          palette.backgroundImageOverlay.withValues(
                            alpha: data.backgroundImageOpacity,
                          ),
                          BlendMode.dstATop,
                        ),
                      ),
                    ),
                  ),
                ),
              RepaintBoundary(
                child: PageView.builder(
                  controller: controller,
                  allowImplicitScrolling: true,
                  onPageChanged: onPageChanged,
                  itemCount: data.totalWeeks,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: ScheduleGrid(
                        courses: data.courses,
                        currentWeek: index + 1,
                        totalWeeks: data.totalWeeks,
                        maxDailyClasses: data.maxDailyClasses,
                        showGridLines: data.showGridLines,
                        showNonCurrentWeek: data.showNonCurrentWeek,
                        showSaturday: data.showSaturday,
                        showSunday: data.showSunday,
                        outlineText: data.outlineText,
                        gridHeight: data.gridHeight,
                        cornerRadius: data.cornerRadius,
                        courseColorPalette: data.courseColorPalette,
                        startDate: data.startDate,
                        onRefreshRequested: () => context
                            .read<CourseProvider>()
                            .loadCourses(recalcWeek: false),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.dateText,
    required this.subtitle,
    required this.onAddCourse,
    required this.onImportSelected,
    required this.onExportSelected,
    required this.onOpenMore,
  });

  final String dateText;
  final String subtitle;
  final VoidCallback onAddCourse;
  final ValueChanged<ImportMenuAction> onImportSelected;
  final ValueChanged<ExportMenuAction> onExportSelected;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HeaderIconButton(
            tooltip: '添加课程',
            icon: Icons.add_rounded,
            color: palette.headerAddContainer,
            iconColor: palette.headerAddForeground,
            onPressed: onAddCourse,
          ),
          const SizedBox(width: 6),
          PopupMenuButton<ImportMenuAction>(
            tooltip: '导入 / 同步',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: theme.colorScheme.surface,
            onSelected: onImportSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ImportMenuAction.syncCurrent,
                child: _PopupActionRow(
                  icon: Icons.school_rounded,
                  label: '从教务导入',
                  iconColor: palette.headerImportForeground,
                  containerColor: palette.headerImportContainer,
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.importJson,
                child: _PopupActionRow(
                  icon: Icons.file_present_rounded,
                  label: '从 JSON 导入',
                  iconColor: palette.headerAddForeground,
                  containerColor: palette.headerAddContainer,
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.importIcs,
                child: _PopupActionRow(
                  icon: Icons.calendar_month_rounded,
                  label: '从 ICS 导入',
                  iconColor: palette.headerExportForeground,
                  containerColor: palette.headerExportContainer,
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.syncOtherTerm,
                child: _PopupActionRow(
                  icon: Icons.event_repeat_rounded,
                  label: '同步其他学期',
                  iconColor: palette.headerMoreForeground,
                  containerColor: palette.headerMoreContainer,
                ),
              ),
            ],
            child: _HeaderIconButton(
              tooltip: '导入 / 同步',
              icon: Icons.download_rounded,
              color: palette.headerImportContainer,
              iconColor: palette.headerImportForeground,
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<ExportMenuAction>(
            tooltip: '导出 / 分享',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: theme.colorScheme.surface,
            onSelected: onExportSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ExportMenuAction.exportJson,
                child: _PopupActionRow(
                  icon: Icons.save_alt_rounded,
                  label: '导出为备份',
                  iconColor: palette.headerExportForeground,
                  containerColor: palette.headerExportContainer,
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.exportIcs,
                child: _PopupActionRow(
                  icon: Icons.event_note_rounded,
                  label: '导出为日历文件',
                  iconColor: theme.colorScheme.secondary,
                  containerColor: theme.colorScheme.secondaryContainer,
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.shareIcs,
                child: _PopupActionRow(
                  icon: Icons.share_rounded,
                  label: '分享课程文件',
                  iconColor: theme.colorScheme.primary,
                  containerColor: theme.colorScheme.primaryContainer,
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.importSystemCalendar,
                child: _PopupActionRow(
                  icon: Icons.event_available_rounded,
                  label: '写入系统日历',
                  iconColor: palette.headerAddForeground,
                  containerColor: palette.headerAddContainer,
                ),
              ),
            ],
            child: _HeaderIconButton(
              tooltip: '导出 / 分享',
              icon: Icons.ios_share_rounded,
              color: palette.headerExportContainer,
              iconColor: palette.headerExportForeground,
            ),
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            tooltip: '更多',
            icon: Icons.more_horiz_rounded,
            color: palette.headerMoreContainer,
            iconColor: palette.headerMoreForeground,
            onPressed: onOpenMore,
          ),
        ],
      ),
    );
  }
}

class _ScheduleViewportData {
  const _ScheduleViewportData({
    required this.courses,
    required this.totalWeeks,
    required this.startDate,
    required this.showGridLines,
    required this.showNonCurrentWeek,
    required this.showSaturday,
    required this.showSunday,
    required this.outlineText,
    required this.maxDailyClasses,
    required this.gridHeight,
    required this.cornerRadius,
    required this.courseColorPalette,
    required this.backgroundColorLight,
    required this.backgroundColorDark,
    required this.backgroundImageOpacity,
  });

  final List<Course> courses;
  final int totalWeeks;
  final DateTime? startDate;
  final bool showGridLines;
  final bool showNonCurrentWeek;
  final bool showSaturday;
  final bool showSunday;
  final bool outlineText;
  final int maxDailyClasses;
  final double gridHeight;
  final double cornerRadius;
  final AppCourseColorPalette courseColorPalette;
  final Color? backgroundColorLight;
  final Color? backgroundColorDark;
  final double backgroundImageOpacity;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ScheduleViewportData &&
            identical(courses, other.courses) &&
            totalWeeks == other.totalWeeks &&
            startDate == other.startDate &&
            showGridLines == other.showGridLines &&
            showNonCurrentWeek == other.showNonCurrentWeek &&
            showSaturday == other.showSaturday &&
            showSunday == other.showSunday &&
            outlineText == other.outlineText &&
            maxDailyClasses == other.maxDailyClasses &&
            gridHeight == other.gridHeight &&
            cornerRadius == other.cornerRadius &&
            courseColorPalette == other.courseColorPalette &&
            backgroundColorLight == other.backgroundColorLight &&
            backgroundColorDark == other.backgroundColorDark &&
            backgroundImageOpacity == other.backgroundImageOpacity;
  }

  @override
  int get hashCode => Object.hash(
    courses,
    totalWeeks,
    startDate,
    showGridLines,
    showNonCurrentWeek,
    showSaturday,
    showSunday,
    outlineText,
    maxDailyClasses,
    gridHeight,
    cornerRadius,
    courseColorPalette,
    backgroundColorLight,
    backgroundColorDark,
    backgroundImageOpacity,
  );
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: iconColor, size: 21),
          ),
        ),
      ),
    );
  }
}

class _PopupActionRow extends StatelessWidget {
  const _PopupActionRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.containerColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
