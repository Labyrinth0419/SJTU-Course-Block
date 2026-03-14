import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';

class ScheduleAppearanceScreen extends StatelessWidget {
  const ScheduleAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('背景与外观')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SectionCard(
                title: '预览',
                subtitle: '先看当前背景效果，再决定是否调整。',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: _buildBackgroundPreview(context, provider),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '颜色与图片',
                subtitle: '为当前课表单独设置背景。',
                children: [
                  _SettingTile(
                    title: '背景颜色（浅色）',
                    subtitle: '调整浅色主题下的课表底色',
                    icon: Icons.light_mode_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    trailing: _buildColorPreview(
                      context,
                      provider.backgroundColorLight ??
                          Theme.of(context).colorScheme.surface,
                    ),
                    onTap: () => _showColorPicker(
                      context,
                      provider,
                      'background_color_light',
                    ),
                  ),
                  _SettingTile(
                    title: '背景颜色（深色）',
                    subtitle: '调整深色主题下的课表底色',
                    icon: Icons.dark_mode_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    trailing: _buildColorPreview(
                      context,
                      provider.backgroundColorDark ??
                          Theme.of(context).colorScheme.surface,
                    ),
                    onTap: () => _showColorPicker(
                      context,
                      provider,
                      'background_color_dark',
                    ),
                  ),
                  _SettingTile(
                    title: '背景图片',
                    subtitle:
                        provider.backgroundImagePath == null ||
                            provider.backgroundImagePath!.isEmpty
                        ? '未设置'
                        : '点击查看或更换当前背景图片',
                    icon: Icons.image_rounded,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    trailing:
                        provider.backgroundImagePath == null ||
                            provider.backgroundImagePath!.isEmpty
                        ? null
                        : SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(provider.backgroundImagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                    onTap: () => _pickBackgroundImage(context, provider),
                  ),
                  if (provider.backgroundImagePath != null &&
                      provider.backgroundImagePath!.isNotEmpty) ...[
                    _SettingTile(
                      title: '背景透明度',
                      subtitle:
                          '${(provider.backgroundImageOpacity * 100).toInt()}%',
                      icon: Icons.opacity_rounded,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      onTap: () => _showOpacityDialog(context, provider),
                    ),
                    _SettingTile(
                      title: '清除背景图片',
                      subtitle: '恢复为纯色背景',
                      icon: Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.errorContainer,
                      onTap: () => provider.updateCurrentScheduleSetting(
                        'background_image_path',
                        null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackgroundPreview(
    BuildContext context,
    CourseProvider provider,
  ) {
    final light =
        provider.backgroundColorLight ?? Theme.of(context).colorScheme.surface;
    final dark =
        provider.backgroundColorDark ?? Theme.of(context).colorScheme.surface;
    final imagePath = provider.backgroundImagePath;
    final opacity = provider.backgroundImageOpacity;

    BoxDecoration buildDecoration(Color color) {
      if (imagePath == null || imagePath.isEmpty) {
        return BoxDecoration(color: color);
      }
      return BoxDecoration(
        color: color,
        image: DecorationImage(
          image: FileImage(File(imagePath)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: opacity),
            BlendMode.dstATop,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 110,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: buildDecoration(light),
                child: const Center(child: Text('浅色')),
              ),
            ),
            Expanded(
              child: Container(
                decoration: buildDecoration(dark),
                child: const Center(child: Text('深色')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPreview(BuildContext context, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }

  Future<void> _pickBackgroundImage(
    BuildContext context,
    CourseProvider provider,
  ) async {
    final picker = ImagePicker();
    if (provider.backgroundImagePath != null &&
        provider.backgroundImagePath!.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('背景图片'),
          content: Image.file(
            File(provider.backgroundImagePath!),
            fit: BoxFit.contain,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  await provider.setBackgroundImage(image.path);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('更换'),
            ),
          ],
        ),
      );
      return;
    }

    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await provider.setBackgroundImage(image.path);
    }
  }

  void _showOpacityDialog(BuildContext context, CourseProvider provider) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('背景透明度'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            height: 50,
            child: Slider(
              value: provider.backgroundImageOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(provider.backgroundImageOpacity * 100).toInt()}%',
              onChanged: (value) {
                provider.updateCurrentScheduleSetting(
                  'background_image_opacity',
                  value,
                );
                setDialogState(() {});
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    CourseProvider provider,
    String settingKey,
  ) {
    final isLight = settingKey == 'background_color_light';
    final colors = isLight
        ? <Color>[
            Colors.white,
            Colors.pink.shade50,
            Colors.blue.shade50,
            Colors.green.shade50,
            Colors.yellow.shade50,
            Colors.grey.shade200,
            Theme.of(context).colorScheme.surface,
          ]
        : <Color>[
            Colors.black,
            Colors.pink.shade900,
            Colors.blue.shade900,
            Colors.green.shade900,
            Colors.grey.shade800,
            Colors.brown.shade800,
            Theme.of(context).colorScheme.surface,
          ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isLight ? '选择浅色背景颜色' : '选择深色背景颜色'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors
              .map(
                (color) => InkWell(
                  onTap: () {
                    provider.updateCurrentScheduleSetting(
                      settingKey,
                      color.toARGB32(),
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        ((isLight
                                    ? provider.backgroundColorLight
                                    : provider.backgroundColorDark)
                                ?.toARGB32() ==
                            color.toARGB32())
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          backgroundColor: color,
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
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
