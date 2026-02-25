import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/course_provider.dart';
import '../widgets/schedule_grid.dart';
import '../course/add_course_screen.dart';
import '../settings/schedule_management_screen.dart';
import '../settings/schedule_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  final bool _isInit = true; // Unused, can remove later, but keeping for now

  String _weekDayToString(int weekDay) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekDays[weekDay - 1];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Load courses on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourses().then((_) {
        // Initialize page controller after load
        if (mounted) {
          final currentWeek = context.read<CourseProvider>().currentWeek;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(currentWeek - 1);
          }
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for week changes that might come from other widgets (like Settings)
    final currentWeek = context.watch<CourseProvider>().currentWeek;
    if (_pageController.hasClients &&
        _pageController.page?.round() != currentWeek - 1) {
      // Avoid animation loop if the change came from the page view itself
      // But provider doesn't tell us source.
      // However, onPageChanged updates provider. So provider matches page.
      // If provider mismatches page, it means external change.
      _pageController.jumpToPage(currentWeek - 1);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            final schedule = provider.currentSchedule;
            final week = provider.currentWeek;
            final now = DateTime.now();
            final termText = schedule != null ? schedule.name : '未设置课表';
            // Simple date format: 2月25日 星期二
            final dateText =
                "${now.month}月${now.day}日 ${_weekDayToString(now.weekday)}";

            String statusText = '';
            if (week < 1) {
              statusText = '(学期未开始)';
            } else if (week > provider.totalWeeks) {
              statusText = '(学期已结束)';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$termText 第$week周 $statusText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(dateText, style: const TextStyle(fontSize: 12)),
              ],
            );
          },
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCourseScreen()),
              ).then((_) {
                context.read<CourseProvider>().loadCourses();
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'schedule_settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScheduleSettingsScreen(),
                  ),
                );
              } else if (value == 'schedule_switch') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScheduleManagementScreen(),
                  ),
                );
              } else if (value == 'sync') {
                _showSyncDialog(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'schedule_settings',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('课表设置'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'schedule_switch',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_view_day, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('课表切换'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(Icons.import_export, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('同步课表'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('全局设置'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: false, // Prevent keyboard from resizing the UI
      body: SafeArea(
        child: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                if (provider.currentWeek != index + 1) {
                  provider.setCurrentWeek(index + 1);
                }
              },
              itemCount: 24, // Typically semesters are ~20-24 weeks
              itemBuilder: (context, index) {
                return ScheduleGrid(
                  courses: provider.courses,
                  currentWeek: index + 1,
                  startDate: provider.currentSchedule?.startDate,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    final now = DateTime.now();
    int currentYear = now.year;
    // Default logic:
    // If Month >= 8 (Aug) -> Autumn (1st term) -> use current year
    // If Month < 8 (e.g. Feb) -> Spring (2nd term) -> use prev year
    // e.g. Feb 2026 is usually 2025-2026 term 2.
    if (now.month < 8) {
      currentYear = currentYear - 1;
    }

    String year = currentYear.toString();
    String term = '1';
    final formKey = GlobalKey<FormState>();
    final years = List.generate(
      2050 - 1996 + 1,
      (index) => 1996 + index,
    ).reversed.toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('同步课表'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: year, // use calculated default
                  decoration: const InputDecoration(labelText: '学年'),
                  menuMaxHeight: 300,
                  items: years.map((y) {
                    return DropdownMenuItem(
                      value: y.toString(),
                      child: Text('$y~${y + 1}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) year = val;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: term,
                  decoration: const InputDecoration(labelText: '学期'),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('第1学期 (秋季)')),
                    DropdownMenuItem(value: '2', child: Text('第2学期 (春季)')),
                    DropdownMenuItem(value: '3', child: Text('第3学期 (夏季)')),
                  ],
                  onChanged: (val) => term = val!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(dialogContext);
                  context.read<CourseProvider>().syncCourses(year, term);
                }
              },
              child: const Text('同步'),
            ),
          ],
        );
      },
    );
  }
}
