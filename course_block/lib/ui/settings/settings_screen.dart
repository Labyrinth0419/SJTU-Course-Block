import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';
import '../../core/services/login_session.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/login/login_selection_screen.dart';

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

  Future<void> _generatePerformanceTestData() async {
    final provider = context.read<CourseProvider>();
    try {
      final result = await provider.generatePerformanceTestData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已生成并导入 ${result.scheduleCount} 个测试课表、'
            '${result.courseCount} 门课程',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成测试数据失败：$error')));
    }
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
          _buildSectionCard(
            context,
            title: '主题与个性化',
            children: [
              _buildThemePicker(context, provider),
              _buildThemeSchemePicker(context, provider),
              _buildCourseColorPalettePicker(context, provider),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            context,
            title: '账号与连接',
            children: [
              _buildActionTile(
                context,
                icon: Icons.login,
                title: _userInfo == null ? '教务系统登录' : '教务系统账号',
                subtitle: _userInfo ?? '未登录',
                onTap: () => _handleLoginAction(context),
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            _buildSectionCard(
              context,
              title: '开发与性能测试',
              children: [
                _buildActionTile(
                  context,
                  icon: Icons.speed,
                  title: '生成大课表测试数据',
                  subtitle: '生成 10 个课表、约 1500 门课程并导入当前数据库',
                  onTap: _generatePerformanceTestData,
                ),
              ],
            ),
          ],
        ],
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
            '只影响课程卡片，不改页面主题。',
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
    String? subtitle,
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
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
