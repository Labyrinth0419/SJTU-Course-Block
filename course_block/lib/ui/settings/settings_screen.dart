import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';
import '../../core/services/login_session.dart';
import '../../core/theme/app_theme.dart';
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
    final summary = await LoginSessionStorage.loadSummary();
    if (!mounted) return;
    setState(() {
      _userInfo = summary.displayText;
    });
  }

  Future<void> _showLauncherIconDialog() async {
    final provider = context.read<CourseProvider>();
    final current = provider.launcherIcon;
    List<String> icons;
    try {
      icons = await provider.getAvailableLauncherIcons();
    } catch (e) {
      debugPrint('failed to load icon list: $e');
      icons = [];
    }

    if (!mounted) return;

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
    final nextIcon = choice.isEmpty ? null : choice;
    if (nextIcon == current) return;
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final targetLabel = nextIcon ?? '默认图标';
        return AlertDialog(
          title: const Text('确认更换启动器图标'),
          content: Text(
            '将图标切换为“$targetLabel”后，系统桌面可能不会立即刷新。'
            '退出并重新打开应用后会完整生效。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('继续更换'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await provider.updateAppSetting('app_icon_choice', nextIcon);
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('启动器图标已更新，退出并重新打开应用后会完整生效')),
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

    await LoginSessionStorage.clearAll();
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
              _buildThemeSchemePicker(context, provider),
              _buildCourseColorPalettePicker(context, provider),
              _buildActionTile(
                context,
                icon: Icons.android,
                title: '启动器图标',
                subtitle: provider.launcherIcon == null
                    ? '当前使用默认图标'
                    : '当前使用 ${provider.launcherIcon}',
                onTap: _showLauncherIconDialog,
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
              '课表相关的周数、切换、常用显示和低频工具都已经移到首页右上角的“更多”面板，这里只保留全局能力。主题现在拆成“界面模式 + 页面配色 + 课程色板”三层。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSchemePicker(
    BuildContext context,
    CourseProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '配色方案',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '每套主题都自带浅色和深色版本，Tokyo Night 会在深色下切到夜色版。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemeScheme.values
                    .map(
                      (scheme) => SizedBox(
                        width: itemWidth,
                        child: _ThemeSchemeTile(
                          scheme: scheme,
                          selected: provider.themeScheme == scheme,
                          onTap: () =>
                              context.read<CourseProvider>().updateAppSetting(
                                'theme_scheme',
                                scheme.storageKey,
                              ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
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

  Widget _buildCourseColorPalettePicker(
    BuildContext context,
    CourseProvider provider,
  ) {
    const orderedPalettes = [
      AppCourseColorPalette.candyBox,
      AppCourseColorPalette.mildlinerNotes,
      AppCourseColorPalette.jellySoda,
      AppCourseColorPalette.tokyoNeon,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '课程色板',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '只影响课程卡片，不改页面主题。默认是糖果盒。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: orderedPalettes
                    .map(
                      (palette) => SizedBox(
                        width: itemWidth,
                        child: _CourseColorPaletteTile(
                          palette: palette,
                          selected: provider.courseColorPalette == palette,
                          onTap: () =>
                              context.read<CourseProvider>().updateAppSetting(
                                'course_color_palette',
                                palette.storageKey,
                              ),
                        ),
                      ),
                    )
                    .toList(),
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

class _ThemeSchemeTile extends StatelessWidget {
  const _ThemeSchemeTile({
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.72)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThemeSchemePreview(scheme: scheme),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scheme.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                scheme.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSchemePreview extends StatelessWidget {
  const _ThemeSchemePreview({required this.scheme});

  final AppThemeScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            Expanded(
              child: _PreviewPanel(
                scheme: scheme,
                brightness: Brightness.light,
                label: '浅',
              ),
            ),
            Expanded(
              child: _PreviewPanel(
                scheme: scheme,
                brightness: Brightness.dark,
                label: '深',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseColorPaletteTile extends StatelessWidget {
  const _CourseColorPaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppCourseColorPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.72)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourseColorPalettePreview(palette: palette),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                palette.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseColorPalettePreview extends StatelessWidget {
  const _CourseColorPalettePreview({required this.palette});

  final AppCourseColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = palette.preview(theme.brightness);

    return Container(
      height: 76,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _CoursePreviewCard(color: colors[i])),
          ],
        ],
      ),
    );
  }
}

class _CoursePreviewCard extends StatelessWidget {
  const _CoursePreviewCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 5,
              width: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 4,
              width: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.scheme,
    required this.brightness,
    required this.label,
  });

  final AppThemeScheme scheme;
  final Brightness brightness;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = scheme.resolve(brightness);
    final palette = AppThemePalette.fromTone(scheme, tone, brightness);
    final labelBackground = brightness == Brightness.light
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.2);

    return DecoratedBox(
      decoration: BoxDecoration(color: tone.scaffoldBackground),
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: labelBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: tone.onSurface,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: tone.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _PreviewDot(color: palette.headerImportContainer),
                    const SizedBox(width: 4),
                    _PreviewDot(color: palette.headerMoreContainer),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: palette.floatingSheetSurface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: palette.floatingSheetShadow,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.weekStripBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 10,
                                margin: const EdgeInsets.only(left: 2),
                                decoration: BoxDecoration(
                                  color: palette.weekStripAccent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.currentScheduleGradientStart,
                                palette.currentScheduleGradientEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: tone.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PreviewDot(color: palette.toolSettingColor, size: 4),
                      _PreviewDot(color: palette.toolHelpColor, size: 4),
                      _PreviewDot(color: palette.toolAboutColor, size: 4),
                      _PreviewDot(color: palette.toolGlobalColor, size: 4),
                    ],
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

class _PreviewDot extends StatelessWidget {
  const _PreviewDot({required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
