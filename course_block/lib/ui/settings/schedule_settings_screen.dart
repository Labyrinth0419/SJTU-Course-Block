import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/schedule.dart';
import '../../core/providers/course_provider.dart';
import 'schedule_appearance_screen.dart';
import 'schedule_editor_dialog.dart';
import 'schedule_structure_screen.dart';

class ScheduleSettingsScreen extends StatelessWidget {
  const ScheduleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课表设置')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final schedule = provider.currentSchedule;
          if (schedule == null) {
            return const Center(child: Text('暂无当前课表'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SectionCard(
                title: '当前课表',
                children: [
                  _ActionTile(
                    icon: Icons.edit_note_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    title: '课表信息',
                    subtitle:
                        '${schedule.name} · ${_formatAcademicYear(schedule.year)} · ${_formatTerm(schedule.term)} · ${DateFormat('yyyy-MM-dd').format(schedule.startDate)}',
                    onTap: () =>
                        showCurrentScheduleEditorDialog(context, schedule),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '显示',
                children: [
                  _SwitchTile(
                    icon: Icons.visibility_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    title: '显示非本周课程',
                    subtitle: '用弱化态查看全学期安排',
                    value: provider.showNonCurrentWeek,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'show_non_current_week',
                      value,
                    ),
                  ),
                  _SwitchTile(
                    icon: Icons.today_rounded,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    title: '显示周六',
                    subtitle: '关闭后默认只显示工作日',
                    value: provider.showSaturday,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'show_saturday',
                      value,
                    ),
                  ),
                  _SwitchTile(
                    icon: Icons.event_repeat_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    title: '显示周日',
                    subtitle: '关闭后默认只显示工作日',
                    value: provider.showSunday,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'show_sunday',
                      value,
                    ),
                  ),
                  _SwitchTile(
                    icon: Icons.text_fields_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    title: '课程字体描边',
                    subtitle: '背景复杂时提升可读性',
                    value: provider.outlineText,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'outline_text',
                      value,
                    ),
                  ),
                  _SwitchTile(
                    icon: Icons.grid_on_rounded,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    title: '显示网格线',
                    subtitle: '增强时间轴和列边界感',
                    value: provider.showGridLines,
                    onChanged: (value) => provider.updateCurrentScheduleSetting(
                      'show_grid_lines',
                      value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '结构与外观',
                children: [
                  _ActionTile(
                    icon: Icons.view_timeline_rounded,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    title: '时间轴与版式',
                    subtitle: '周数、节数、格子高度和文字表现',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScheduleStructureScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.wallpaper_rounded,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    title: '背景与外观',
                    subtitle: '为当前课表设置背景颜色或图片',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScheduleAppearanceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (provider.schedules.length > 1 && schedule.id != null) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: '危险操作',
                  children: [
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.errorContainer,
                      title: '删除当前课表',
                      subtitle: '删除后会自动切换到其他课表',
                      destructive: true,
                      onTap: () => _confirmDeleteCurrentSchedule(
                        context,
                        provider,
                        schedule,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
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
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = destructive ? theme.colorScheme.error : null;
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
            color: titleColor,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
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

String _formatAcademicYear(String year) {
  final baseYear = int.tryParse(year);
  if (baseYear == null) return year;
  return '$baseYear~${baseYear + 1}';
}

String _formatTerm(String term) {
  switch (term) {
    case '1':
      return '第1学期';
    case '2':
      return '第2学期';
    case '3':
      return '第3学期';
    default:
      return '$term 学期';
  }
}

Future<void> _confirmDeleteCurrentSchedule(
  BuildContext context,
  CourseProvider provider,
  Schedule schedule,
) async {
  if (schedule.id == null) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除当前课表'),
      content: Text('确定要删除“${schedule.name}”吗？此操作不可恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );

  if (confirm != true) return;
  await provider.deleteSchedule(schedule.id!);
  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('已删除当前课表')));
  Navigator.of(context).pop();
}
