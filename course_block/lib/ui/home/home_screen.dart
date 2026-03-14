import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';
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

  String _weekDayToString(int weekDay) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekDays[weekDay - 1];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourses().then((_) {
        if (!mounted) return;
        final currentWeek = context.read<CourseProvider>().currentWeek;
        setState(() {
          _pageController = PageController(initialPage: currentWeek - 1);
          _controllerReady = true;
        });
      });
    });

    context.read<CourseProvider>().addListener(_providerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as PageRoute);
    }

    final currentWeek = context.watch<CourseProvider>().currentWeek;
    if (_pageController?.hasClients == true &&
        _pageController!.page?.round() != currentWeek - 1) {
      _pageController!.jumpToPage(currentWeek - 1);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CourseProvider>().removeListener(_providerListener);
    routeObserver.unsubscribe(this);
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading || !_controllerReady) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final subtitle =
                '第${provider.currentWeek}周  ${_weekDayToString(now.weekday)} · ${provider.currentSchedule?.name ?? '未命名课表'}';

            return Column(
              children: [
                _HomeHeader(
                  dateText: '${now.year}/${now.month}/${now.day}',
                  subtitle: subtitle,
                  onAddCourse: _openAddCourseScreen,
                  onImportSelected: (action) =>
                      handleImportMenuAction(context, action),
                  onExportSelected: (action) =>
                      handleExportMenuAction(context, action),
                  onOpenMore: () => showMoreFunctionsSheet(context),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController!,
                    onPageChanged: (index) {
                      if (provider.currentWeek != index + 1) {
                        provider.setCurrentWeek(index + 1);
                      }
                    },
                    itemCount: provider.totalWeeks,
                    itemBuilder: (context, index) {
                      return ScheduleGrid(
                        courses: provider.courses,
                        currentWeek: index + 1,
                        startDate: provider.currentSchedule?.startDate,
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
    final provider = context.read<CourseProvider>();
    final target = provider.currentWeek - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController == null) return;
      if (_pageController!.hasClients) {
        final page =
            _pageController!.page ?? _pageController!.initialPage.toDouble();
        if (page.round() != target) {
          _pageController!.jumpToPage(target);
        }
      }
    });
  }

  void _ensureCorrectPage() {
    if (_pageController?.hasClients != true) return;
    final provider = context.read<CourseProvider>();
    final maxPage = provider.totalWeeks - 1;
    final currentPage = _pageController!.page ?? _pageController!.initialPage;
    if (currentPage < 0 || currentPage > maxPage) {
      final target = provider.currentWeek - 1;
      _pageController!.jumpToPage(target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CourseProvider>().loadCourses().then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureCorrectPage();
        });
      });
    }
  }

  @override
  void didPopNext() {
    _ensureCorrectPage();
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
            color: const Color(0xFFDDEFCF),
            iconColor: const Color(0xFF447A1F),
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ImportMenuAction.syncCurrent,
                child: _PopupActionRow(
                  icon: Icons.school_rounded,
                  label: '从教务导入',
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.login,
                child: _PopupActionRow(
                  icon: Icons.link_rounded,
                  label: '登录教务系统',
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.importJson,
                child: _PopupActionRow(
                  icon: Icons.file_present_rounded,
                  label: '从 JSON 导入',
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.importIcs,
                child: _PopupActionRow(
                  icon: Icons.calendar_month_rounded,
                  label: '从 ICS 导入',
                ),
              ),
              PopupMenuItem(
                value: ImportMenuAction.syncOtherTerm,
                child: _PopupActionRow(
                  icon: Icons.event_repeat_rounded,
                  label: '同步其他学期',
                ),
              ),
            ],
            child: const _HeaderIconButton(
              tooltip: '导入 / 同步',
              icon: Icons.download_rounded,
              color: Color(0xFFD7E8FF),
              iconColor: Color(0xFF2E5EA8),
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ExportMenuAction.exportJson,
                child: _PopupActionRow(
                  icon: Icons.save_alt_rounded,
                  label: '导出为备份',
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.exportIcs,
                child: _PopupActionRow(
                  icon: Icons.event_note_rounded,
                  label: '导出为日历文件',
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.shareIcs,
                child: _PopupActionRow(
                  icon: Icons.share_rounded,
                  label: '分享课程文件',
                ),
              ),
              PopupMenuItem(
                value: ExportMenuAction.importSystemCalendar,
                child: _PopupActionRow(
                  icon: Icons.event_available_rounded,
                  label: '写入系统日历',
                ),
              ),
            ],
            child: const _HeaderIconButton(
              tooltip: '导出 / 分享',
              icon: Icons.ios_share_rounded,
              color: Color(0xFFFFE8C9),
              iconColor: Color(0xFFA86B17),
            ),
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            tooltip: '更多',
            icon: Icons.more_horiz_rounded,
            color: const Color(0xFFE9E5F3),
            iconColor: const Color(0xFF5E5870),
            onPressed: onOpenMore,
          ),
        ],
      ),
    );
  }
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
  const _PopupActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
