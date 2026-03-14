import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';

import '../../core/providers/course_provider.dart';

class ScheduleStructureScreen extends StatelessWidget {
  const ScheduleStructureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('时间轴与版式')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SectionCard(
                title: '时间轴',
                subtitle: '低频但重要的课表结构参数放在这一页。',
                children: [
                  _SettingTile(
                    title: '学期周数',
                    subtitle: '${provider.totalWeeks} 周',
                    icon: Icons.view_week_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    onTap: () => _showNumberPickerDialog(
                      context,
                      title: '学期周数',
                      currentValue: provider.totalWeeks,
                      min: 10,
                      max: 30,
                      onChanged: (value) => provider
                          .updateCurrentScheduleSetting('total_weeks', value),
                    ),
                  ),
                  _SettingTile(
                    title: '一天课程节数',
                    subtitle: '${provider.maxDailyClasses} 节',
                    icon: Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    onTap: () => _showNumberPickerDialog(
                      context,
                      title: '一天课程节数',
                      currentValue: provider.maxDailyClasses,
                      min: 8,
                      max: 20,
                      onChanged: (value) =>
                          provider.updateCurrentScheduleSetting(
                            'max_daily_classes',
                            value,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '版式',
                subtitle: '用于控制网格密度和课程文字表现。',
                children: [
                  _SettingTile(
                    title: '课程格子高度',
                    subtitle: '${provider.gridHeight.toInt()} dp',
                    icon: Icons.height_rounded,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    onTap: () => _showDoubleInputDialog(
                      context,
                      title: '课程格子高度',
                      currentValue: provider.gridHeight,
                      onChanged: (value) => provider
                          .updateCurrentScheduleSetting('grid_height', value),
                    ),
                  ),
                  _SettingTile(
                    title: '格子圆角半径',
                    subtitle: '${provider.cornerRadius.toInt()} dp',
                    icon: Icons.rounded_corner_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    onTap: () => _showDoubleInputDialog(
                      context,
                      title: '格子圆角半径',
                      currentValue: provider.cornerRadius,
                      onChanged: (value) => provider
                          .updateCurrentScheduleSetting('corner_radius', value),
                    ),
                  ),
                  _SwitchTile(
                    title: '显示网格线',
                    subtitle: '增强行列边界感',
                    value: provider.showGridLines,
                    icon: Icons.grid_on_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'show_grid_lines',
                      value,
                    ),
                  ),
                  _SwitchTile(
                    title: '课程字体描边',
                    subtitle: '背景复杂时提升可读性',
                    value: provider.outlineText,
                    icon: Icons.text_fields_rounded,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'outline_text',
                      value,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNumberPickerDialog(
    BuildContext context, {
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        int selectedValue = currentValue;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: NumberPicker(
              value: selectedValue,
              minValue: min,
              maxValue: max,
              onChanged: (value) {
                setState(() {
                  selectedValue = value;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  onChanged(selectedValue);
                  Navigator.pop(dialogContext);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDoubleInputDialog(
    BuildContext context, {
    required String title,
    required double currentValue,
    required ValueChanged<double> onChanged,
    String suffix = 'dp',
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                onChanged(value);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('确定'),
          ),
        ],
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
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
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
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: CircleAvatar(
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
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
