import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';
import '../../core/services/course_settings_store.dart';

Future<void> showLauncherIconDialog(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  final current = provider.launcherIcon;
  final icons = await provider.getAvailableLauncherIcons();
  if (!context.mounted) return;

  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('选择启动器图标'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconOption(name: '', current: current),
              for (final name in icons)
                _IconOption(name: name, current: current),
              if (icons.isEmpty) const Text('未找到可用的自定义图标'),
            ],
          ),
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final nextIcon = choice.isEmpty ? null : choice;
  if (nextIcon == current) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('确认更换启动器图标'),
      content: Text('将图标切换为“${nextIcon ?? '默认图标'}”。系统桌面可能需要稍等或返回桌面后刷新，是否继续？'),
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
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await provider.updateAppSetting(
      CourseSettingsStore.launcherIconKey,
      nextIcon,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('启动器图标已更新，系统桌面可能稍后刷新')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('切换启动器图标失败，请重试')));
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({required this.name, required this.current});

  final String name;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final selected = name.isEmpty ? current == null : current == name;
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
        leading: name.isEmpty
            ? const Icon(Icons.apps)
            : Image.asset(
                'assets/icons/$name.png',
                width: 24,
                height: 24,
                errorBuilder: (_, _, _) => const Icon(Icons.apps),
              ),
        title: Text(name.isEmpty ? '默认' : name),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: () => Navigator.pop(context, name),
      ),
    );
  }
}
