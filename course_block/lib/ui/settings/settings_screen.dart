import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/login/login_selection_screen.dart';
import '../../core/providers/course_provider.dart';
import 'schedule_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showNonCurrentWeek = false;
  bool _showGridLines = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNonCurrentWeek = prefs.getBool('show_non_current_week') ?? false;
      _showGridLines = prefs.getBool('show_grid_lines') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('显示非本周课程'),
                subtitle: const Text('开启后将显示非本周的课程（颜色变浅）'),
                value: _showNonCurrentWeek,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_non_current_week', value);
                  setState(() {
                    _showNonCurrentWeek = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('显示网格线'),
                subtitle: const Text('开启后显示课表网格'),
                value: _showGridLines,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('show_grid_lines', value);
                  setState(() {
                    _showGridLines = value;
                  });
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('课表管理'),
                subtitle: Text(provider.currentSchedule?.name ?? '默认课表'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScheduleManagementScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('教务系统登录'),
                subtitle: const Text('点击登录以获取课表'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginSelectionScreen(),
                    ),
                  ).then((success) async {
                    if (success == true) {
                      // Calculate default year and term
                      final now = DateTime.now();
                      int year = now.year;
                      String term = '1';

                      if (now.month < 9) {
                        year -= 1;
                      }

                      if (now.month >= 8 || now.month < 2) {
                        term = '1';
                      } else if (now.month < 7) {
                        term = '2';
                      } else {
                        term = '3';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('正在同步 $year-$term 学期课表...')),
                      );

                      final count = await provider.syncCourses(
                        year.toString(),
                        term,
                      );

                      if (context.mounted) {
                        if (count > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('同步成功，共获取到 $count 门课程')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('同步完成，但未获取到课程，请检查学期或登录状态'),
                            ),
                          );
                        }
                      }
                    }
                  });
                },
              ),
              const Divider(),
              // ... SwitchListTiles omitted for brevity if no logic change needed yet ...
              ListTile(
                title: const Text('当前周'),
                subtitle: Text('第${provider.currentWeek}周'),
                onTap: () async {
                  final int? selectedWeek = await showDialog<int>(
                    context: context,
                    builder: (BuildContext context) {
                      return SimpleDialog(
                        title: const Text('选择当前周'),
                        children: List.generate(24, (index) {
                          return SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context, index + 1);
                            },
                            child: Text('第${index + 1}周'),
                          );
                        }),
                      );
                    },
                  );

                  if (selectedWeek != null) {
                    provider.setCurrentWeek(selectedWeek);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
