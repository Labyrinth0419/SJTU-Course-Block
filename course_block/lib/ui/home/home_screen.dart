import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/course_provider.dart';
import '../widgets/schedule_grid.dart';
import '../course/add_course_screen.dart';
import 'dart:io';
import '../settings/schedule_management_screen.dart';
import '../settings/schedule_settings_screen.dart';
import '../../main.dart';

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
        if (mounted) {
          final currentWeek = context.read<CourseProvider>().currentWeek;
          setState(() {
            _pageController = PageController(initialPage: currentWeek - 1);
            _controllerReady = true;
          });
        }
      });
    });

    context.read<CourseProvider>().addListener(_providerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
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
      appBar: AppBar(
        title: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            final schedule = provider.currentSchedule;
            final week = provider.currentWeek;
            final now = DateTime.now();
            final termText = schedule != null ? schedule.name : '未设置课表';
            final dateText =
                "${now.month}月${now.day}日 ${_weekDayToString(now.weekday)}";

            String statusText = '';
            final start = schedule?.startDate;
            if (start != null) {
              final end = start.add(
                Duration(days: provider.totalWeeks * 7 - 1),
              );
              if (now.isBefore(start)) {
                statusText = '(学期未开始)';
              } else if (now.isAfter(end)) {
                statusText = '(学期已结束)';
              }
            } else {
              if (week < 1) {
                statusText = '(学期未开始)';
              } else if (week > provider.totalWeeks) {
                statusText = '(学期已结束)';
              }
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
                context.read<CourseProvider>().loadCourses(recalcWeek: false);
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Consumer<CourseProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading || !_controllerReady) {
              return const Center(child: CircularProgressIndicator());
            }

            return PageView.builder(
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
            );
          },
        ),
      ),
    );
  }

  void _providerListener() {
    if (!mounted || _pageController == null) return;
    final provider = context.read<CourseProvider>();
    final target = provider.currentWeek - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController == null) return;
      if (_pageController!.page?.round() != target) {
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

  void _showSyncDialog(BuildContext context) {
    final now = DateTime.now();
    int currentYear = now.year;
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
