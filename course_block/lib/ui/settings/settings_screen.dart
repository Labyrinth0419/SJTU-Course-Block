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
  bool _outlineText = false; // new global toggle
  ThemeMode _themeMode = ThemeMode.system;
  String? _userInfo;

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
      _outlineText = prefs.getBool('outline_text') ?? false;
      _userInfo = prefs.getString('user_info');
      if (_userInfo == null) {
        final cookies = prefs.getString('cookies');
        if (cookies != null && cookies.isNotEmpty) {
          _userInfo = '已登录';
        }
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
    });
  }

  Future<void> _showLauncherIconDialog(BuildContext context) async {
    final provider = context.read<CourseProvider>();
    final current = provider.launcherIcon;
    List<String> icons;
    try {
      icons = await provider.getAvailableLauncherIcons();
    } catch (e) {
      debugPrint('failed to load icon list: $e');
      icons = [];
    }
    final choice = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        String? temp = current;
        return AlertDialog(
          title: const Text('选择启动器图标'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(
                  title: const Text('默认'),
                  value: null,
                  groupValue: temp,
                  onChanged: (v) {
                    temp = v;
                    Navigator.of(ctx).pop(v);
                  },
                ),
                ...icons.map((name) {
                  Widget iconPreview;
                  try {
                    iconPreview = Image.asset(
                      'assets/icons/$name.png',
                      width: 24,
                      height: 24,
                    );
                  } catch (_) {
                    try {
                      iconPreview = Image.asset(
                        'assets/icon/$name.png',
                        width: 24,
                        height: 24,
                      );
                    } catch (_) {
                      iconPreview = const SizedBox(width: 24, height: 24);
                    }
                  }
                  return RadioListTile<String?>(
                    title: Row(
                      children: [
                        iconPreview,
                        const SizedBox(width: 8),
                        Text(name),
                      ],
                    ),
                    value: name,
                    groupValue: temp,
                    onChanged: (v) {
                      temp = v;
                      Navigator.of(ctx).pop(v);
                    },
                  );
                }),
                if (icons.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('未找到可用的自定义图标'),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null) {
      final prefs = await SharedPreferences.getInstance();
      if (choice.isEmpty) {
        await prefs.remove('app_icon_choice');
      } else {
        await prefs.setString('app_icon_choice', choice);
      }
      provider.updateSetting('app_icon_choice', choice == '' ? null : choice);
    }
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
                  context.read<CourseProvider>().updateSetting(
                    'show_grid_lines',
                    value,
                  );
                  setState(() {
                    _showGridLines = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('课程字体描边'),
                subtitle: const Text('开启后课程名与教室会有黑色细描边'),
                value: _outlineText,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('outline_text', value);
                  context.read<CourseProvider>().updateSetting(
                    'outline_text',
                    value,
                  );
                  setState(() {
                    _outlineText = value;
                  });
                },
              ),
              const Divider(),
              const ListTile(title: Text('界面模式'), subtitle: Text('选择应用的色彩主题')),
              RadioListTile<ThemeMode>(
                title: const Text('跟随系统'),
                value: ThemeMode.system,
                groupValue: _themeMode,
                onChanged: (mode) async {
                  if (mode == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('theme_mode', 'system');
                  context.read<CourseProvider>().updateSetting(
                    'theme_mode',
                    'system',
                  );
                  setState(() {
                    _themeMode = mode;
                  });
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('浅色模式'),
                value: ThemeMode.light,
                groupValue: _themeMode,
                onChanged: (mode) async {
                  if (mode == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('theme_mode', 'light');
                  context.read<CourseProvider>().updateSetting(
                    'theme_mode',
                    'light',
                  );
                  setState(() {
                    _themeMode = mode;
                  });
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('深色模式'),
                value: ThemeMode.dark,
                groupValue: _themeMode,
                onChanged: (mode) async {
                  if (mode == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('theme_mode', 'dark');
                  context.read<CourseProvider>().updateSetting(
                    'theme_mode',
                    'dark',
                  );
                  setState(() {
                    _themeMode = mode;
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
                subtitle: Text(_userInfo ?? '点击登录以获取课表'),
                onTap: () {
                  if (_userInfo == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginSelectionScreen(),
                      ),
                    ).then((success) async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        _userInfo = prefs.getString('user_info');
                      });
                    });
                  } else {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('注销登录'),
                          content: const Text('确定要清除登录信息吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('cookies');
                                await prefs.remove('user_info');
                                setState(() {
                                  _userInfo = null;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已注销')),
                                  );
                                }
                                Navigator.pop(ctx);
                              },
                              child: const Text('注销'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.android),
                title: const Text('启动器图标'),
                subtitle: Consumer<CourseProvider>(
                  builder: (context, prov, child) {
                    if (prov.launcherIcon == null) {
                      return const Text('默认图标');
                    }
                    return Text('自定义：${prov.launcherIcon}');
                  },
                ),
                onTap: () => _showLauncherIconDialog(context),
              ),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}
