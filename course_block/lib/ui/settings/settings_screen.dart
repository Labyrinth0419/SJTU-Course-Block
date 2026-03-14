import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/course_provider.dart';
import '../../ui/login/login_selection_screen.dart';
import '../screens/faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userInfo = prefs.getString('user_info');
      if (_userInfo == null) {
        final cookies = prefs.getString('cookies');
        if (cookies != null && cookies.isNotEmpty) {
          _userInfo = '已登录';
        }
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

    if (!context.mounted) return;

    final choice = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('选择启动器图标'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconOptionTile(
                    dialogContext,
                    title: '默认',
                    selected: current == null,
                    value: '',
                  ),
                  ...icons.map(
                    (name) => _buildIconOptionTile(
                      dialogContext,
                      title: name,
                      selected: current == name,
                      value: name,
                      preview: _buildLauncherPreview(name),
                    ),
                  ),
                  if (icons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('未找到可用的自定义图标'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (choice == null) return;
    await provider.updateAppSetting(
      'app_icon_choice',
      choice.isEmpty ? null : choice,
    );
  }

  Future<void> _handleLoginAction(BuildContext context) async {
    if (_userInfo == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginSelectionScreen()),
      );
      await _loadSettings();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('注销登录'),
          content: const Text('确定要清除登录信息吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('注销'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookies');
    await prefs.remove('user_info');
    if (!mounted || !context.mounted) return;

    setState(() {
      _userInfo = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已注销')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildIntroCard(context),
          const SizedBox(height: 12),
          _buildSectionCard(
            context,
            title: '主题与个性化',
            subtitle: '这里只保留真正属于应用层的视觉和启动入口。',
            children: [
              _buildThemePicker(context, provider),
              _buildActionTile(
                context,
                icon: Icons.android,
                title: '启动器图标',
                subtitle: provider.launcherIcon == null
                    ? '当前使用默认图标'
                    : '当前使用 ${provider.launcherIcon}',
                onTap: () => _showLauncherIconDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            context,
            title: '账号与连接',
            subtitle: '教务登录是跨课表共享能力，所以放在应用设置。',
            children: [
              _buildActionTile(
                context,
                icon: Icons.login,
                title: _userInfo == null ? '教务系统登录' : '管理教务登录',
                subtitle: _userInfo ?? '未登录',
                onTap: () => _handleLoginAction(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            context,
            title: '帮助与支持',
            subtitle: '更新检查、常见问题和反馈入口集中在这里。',
            children: [
              _buildActionTile(
                context,
                icon: Icons.help_outline,
                title: '帮助与反馈',
                subtitle: 'FAQ、更新检查、反馈入口',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaqScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用设置只处理全局能力',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '课表相关的周数、切换、常用显示和低频工具都已经移到首页右上角的“更多”面板，这里只保留全局能力。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePicker(BuildContext context, CourseProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '界面模式',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
            ],
            selected: {provider.themeMode},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              final modeValue = switch (mode) {
                ThemeMode.light => 'light',
                ThemeMode.dark => 'dark',
                ThemeMode.system => 'system',
              };
              context.read<CourseProvider>().updateAppSetting(
                'theme_mode',
                modeValue,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildIconOptionTile(
    BuildContext context, {
    required String title,
    required bool selected,
    required String value,
    Widget? preview,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: preview ?? const Icon(Icons.apps),
        title: Text(title),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: () => Navigator.of(context).pop(value),
      ),
    );
  }

  Widget _buildLauncherPreview(String name) {
    try {
      return Image.asset('assets/icons/$name.png', width: 24, height: 24);
    } catch (_) {
      try {
        return Image.asset('assets/icon/$name.png', width: 24, height: 24);
      } catch (_) {
        return const SizedBox(width: 24, height: 24);
      }
    }
  }
}
