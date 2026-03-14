import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/schedule.dart';
import '../../core/providers/course_provider.dart';
import '../../core/services/course_service.dart';
import '../../core/theme/app_theme.dart';
import '../login/login_selection_screen.dart';
import '../screens/about_screen.dart';
import '../screens/faq_screen.dart';
import 'schedule_settings_screen.dart';
import 'schedule_editor_dialog.dart';
import 'settings_screen.dart';

const MethodChannel _fileChannel = MethodChannel('course_block/file');

enum ImportMenuAction {
  syncCurrent,
  syncOtherTerm,
  login,
  importJson,
  importIcs,
}

enum ExportMenuAction { exportJson, exportIcs, shareIcs, importSystemCalendar }

Future<void> handleImportMenuAction(
  BuildContext context,
  ImportMenuAction action,
) async {
  switch (action) {
    case ImportMenuAction.syncCurrent:
      await _syncCurrentSchedule(context);
      break;
    case ImportMenuAction.syncOtherTerm:
      await _showManualSyncDialog(context);
      break;
    case ImportMenuAction.login:
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginSelectionScreen()));
      break;
    case ImportMenuAction.importJson:
      await _pickAndImport(
        context,
        label: 'JSON',
        extensions: ['json'],
        importer: context.read<CourseProvider>().importCoursesJson,
      );
      break;
    case ImportMenuAction.importIcs:
      await _pickAndImport(
        context,
        label: 'ICS',
        extensions: ['ics'],
        importer: context.read<CourseProvider>().importCoursesIcs,
      );
      break;
  }
}

Future<void> handleExportMenuAction(
  BuildContext context,
  ExportMenuAction action,
) async {
  switch (action) {
    case ExportMenuAction.exportJson:
      await _exportJson(context);
      break;
    case ExportMenuAction.exportIcs:
      await _exportIcs(context);
      break;
    case ExportMenuAction.shareIcs:
      await _shareCoursesIcs(context);
      break;
    case ExportMenuAction.importSystemCalendar:
      await _importToSystemCalendar(context);
      break;
  }
}

Future<void> showMoreFunctionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoreFunctionsSheet(rootContext: context),
  );
}

class _MoreFunctionsSheet extends StatelessWidget {
  const _MoreFunctionsSheet({required this.rootContext});

  final BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.56;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final schedule = provider.currentSchedule;
          final todayWeek = schedule == null
              ? provider.currentWeek
              : _resolveCurrentAcademicWeek(schedule, provider.totalWeeks);

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FloatingSheetCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PanelTitleRow(
                            title: '周数',
                            actionLabel: '修改当前周',
                            onTap: () => _showWeekPickerDialog(
                              context,
                              provider,
                              todayWeek,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _WeekStrip(
                            currentWeek: provider.currentWeek,
                            totalWeeks: provider.totalWeeks,
                            onChanged: (value) =>
                                provider.setCurrentWeek(value.round()),
                          ),
                          const SizedBox(height: 16),
                          _PanelTitleRow(
                            title: '课表',
                            actionLabel: '新建课表',
                            onTap: () => _dismissAndRun(context, () async {
                              await showCreateScheduleDialog(rootContext);
                            }),
                          ),
                          const SizedBox(height: 10),
                          _ScheduleSwitcherStrip(rootContext: rootContext),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FloatingSheetCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                      child: _ToolStrip(rootContext: rootContext),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingSheetCard extends StatelessWidget {
  const _FloatingSheetCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.floatingSheetSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.floatingSheetShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitleRow extends StatelessWidget {
  const _PanelTitleRow({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: palette.floatingSheetAction,
          ),
          child: Text(
            actionLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.currentWeek,
    required this.totalWeeks,
    required this.onChanged,
  });

  final int currentWeek;
  final int totalWeeks;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appTheme;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.weekStripBackground,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: palette.weekStripAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.view_week_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                activeTrackColor: palette.weekStripBackground,
                inactiveTrackColor: palette.weekStripBackground,
                thumbColor: palette.weekStripThumb,
                overlayColor: palette.weekStripThumb.withValues(alpha: 0.14),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 4.5,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: currentWeek.toDouble(),
                min: 1,
                max: totalWeeks.toDouble(),
                divisions: totalWeeks > 1 ? totalWeeks - 1 : null,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSwitcherStrip extends StatelessWidget {
  const _ScheduleSwitcherStrip({required this.rootContext});

  final BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<CourseProvider>().schedules;

    if (schedules.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '暂无课表',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: schedules.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _ScheduleSwitchCard(
            rootContext: rootContext,
            schedule: schedules[index],
          );
        },
      ),
    );
  }
}

class _ScheduleSwitchCard extends StatelessWidget {
  const _ScheduleSwitchCard({
    required this.rootContext,
    required this.schedule,
  });

  final BuildContext rootContext;
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CourseProvider>();
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final isCurrent = schedule.isCurrent;
    final textColor = isCurrent ? Colors.white : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isCurrent || schedule.id == null
            ? null
            : () async {
                await provider.switchSchedule(schedule.id!);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
        child: Ink(
          width: 92,
          decoration: BoxDecoration(
            gradient: isCurrent
                ? LinearGradient(
                    colors: [
                      palette.currentScheduleGradientStart,
                      palette.currentScheduleGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCurrent
                ? null
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.white.withValues(alpha: 0.22)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.check_rounded
                        : Icons.calendar_month_rounded,
                    color: textColor,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  schedule.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.rootContext});

  final BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolAction(
        icon: Icons.tune_rounded,
        iconColor: context.appTheme.toolSettingColor,
        label: '课表设置',
        onTap: () => _dismissAndRun(context, () async {
          await Navigator.of(rootContext).push(
            MaterialPageRoute(builder: (_) => const ScheduleSettingsScreen()),
          );
        }),
      ),
      _ToolAction(
        icon: Icons.help_outline_rounded,
        iconColor: context.appTheme.toolHelpColor,
        label: '常见问题',
        onTap: () => _dismissAndRun(context, () async {
          await Navigator.of(
            rootContext,
          ).push(MaterialPageRoute(builder: (_) => const FaqScreen()));
        }),
      ),
      _ToolAction(
        icon: Icons.info_outline_rounded,
        iconColor: context.appTheme.toolAboutColor,
        label: '关于',
        onTap: () => _dismissAndRun(context, () async {
          await Navigator.of(
            rootContext,
          ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
        }),
      ),
      _ToolAction(
        icon: Icons.settings_rounded,
        iconColor: context.appTheme.toolGlobalColor,
        label: '全局设置',
        onTap: () => _dismissAndRun(context, () async {
          await Navigator.of(
            rootContext,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        }),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tools.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(child: _ToolButton(tool: tools[i])),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final _ToolAction tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tool.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tool.icon, color: tool.iconColor, size: 28),
              const SizedBox(height: 6),
              Text(
                tool.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolAction {
  const _ToolAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;
}

Future<void> _dismissAndRun(
  BuildContext sheetContext,
  Future<void> Function() action,
) async {
  Navigator.of(sheetContext).pop();
  await Future<void>.delayed(Duration.zero);
  await action();
}

int _resolveCurrentAcademicWeek(Schedule schedule, int totalWeeks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(
    schedule.startDate.year,
    schedule.startDate.month,
    schedule.startDate.day,
  );
  final diff = today.difference(start).inDays;
  final week = (diff / 7).floor() + 1;
  if (week < 1) return 1;
  if (week > totalWeeks) return totalWeeks;
  return week;
}

Future<void> _showWeekPickerDialog(
  BuildContext context,
  CourseProvider provider,
  int todayWeek,
) async {
  var selectedWeek = provider.currentWeek;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('修改当前周'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '第 $selectedWeek 周',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Slider(
                value: selectedWeek.toDouble(),
                min: 1,
                max: provider.totalWeeks.toDouble(),
                divisions: provider.totalWeeks > 1
                    ? provider.totalWeeks - 1
                    : null,
                label: '第 $selectedWeek 周',
                onChanged: (value) {
                  setDialogState(() {
                    selectedWeek = value.round();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          if (selectedWeek != todayWeek)
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selectedWeek = todayWeek;
                });
              },
              child: const Text('回到本周'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.setCurrentWeek(selectedWeek);
              Navigator.pop(dialogContext);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _saveBytes(String filename, Uint8List bytes) async {
  try {
    return await _fileChannel.invokeMethod<String>('saveFile', {
      'name': filename,
      'bytes': bytes,
    });
  } catch (_) {
    return null;
  }
}

Future<void> _exportJson(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final platform = Theme.of(context).platform;

  if (platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.fuchsia) {
    final bytes = await provider.exportCoursesJsonBytes();
    final uri = await _saveBytes('course_export.json', bytes);
    if (context.mounted && uri != null) {
      messenger.showSnackBar(SnackBar(content: Text('已导出到 $uri')));
    }
    return;
  }

  final typeGroup = fs.XTypeGroup(label: 'json', extensions: ['json']);
  final location = await fs.getSaveLocation(
    acceptedTypeGroups: [typeGroup],
    suggestedName: 'course_export.json',
  );
  final path = await provider.exportCoursesJson(location?.path);
  if (context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text('已导出到 $path')));
  }
}

Future<void> _exportIcs(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final platform = Theme.of(context).platform;

  if (platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.fuchsia) {
    final bytes = await provider.exportCoursesIcsBytes();
    final uri = await _saveBytes('course_export.ics', bytes);
    if (context.mounted && uri != null) {
      messenger.showSnackBar(SnackBar(content: Text('已导出到 $uri')));
    }
    return;
  }

  final typeGroup = fs.XTypeGroup(label: 'ics', extensions: ['ics']);
  final location = await fs.getSaveLocation(
    acceptedTypeGroups: [typeGroup],
    suggestedName: 'course_export.ics',
  );
  final path = await provider.exportCoursesIcs(location?.path);
  if (context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text('已导出到 $path')));
  }
}

Future<void> _shareCoursesIcs(BuildContext context) async {
  final ok = await context.read<CourseProvider>().shareCoursesIcs();
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('当前课表为空，无法分享 ICS')));
}

Future<void> _importToSystemCalendar(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (Theme.of(context).platform != TargetPlatform.android) {
    messenger.showSnackBar(const SnackBar(content: Text('该功能仅在安卓可用')));
    return;
  }

  final count = await context.read<CourseProvider>().importToSystemCalendar();
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text('已写入系统日历 $count 条课程')));
}

Future<void> _pickAndImport(
  BuildContext context, {
  required String label,
  required List<String> extensions,
  required Future<int> Function(String path) importer,
}) async {
  final typeGroup = fs.XTypeGroup(label: label, extensions: extensions);
  final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return;

  final count = await importer(file.path);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('已导入 $count 条课程')));
}

Future<void> _syncCurrentSchedule(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  if (provider.requiresSyncTermSelection || provider.currentSchedule == null) {
    await _showManualSyncDialog(context);
    return;
  }

  try {
    final count = await provider.syncCurrentSchedule();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? '已同步 $count 条课程' : '未获取到课程，请检查登录状态或学期信息'),
      ),
    );
  } on CourseSyncException catch (e) {
    if (!context.mounted) return;
    _showSyncError(context, e);
  }
}

Future<void> _showManualSyncDialog(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  final currentSchedule = provider.currentSchedule;
  final now = DateTime.now();
  var currentYear = now.year;
  if (now.month < 8) {
    currentYear = currentYear - 1;
  }

  String year = currentSchedule?.year ?? currentYear.toString();
  String term = currentSchedule?.term ?? '1';
  final years = List.generate(
    2050 - 1996 + 1,
    (index) => 1996 + index,
  ).reversed.toList();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('同步其他学期'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: year,
            decoration: const InputDecoration(labelText: '学年'),
            menuMaxHeight: 320,
            items: years
                .map(
                  (item) => DropdownMenuItem(
                    value: item.toString(),
                    child: Text('$item~${item + 1}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                year = value;
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: term,
            decoration: const InputDecoration(labelText: '学期'),
            items: const [
              DropdownMenuItem(value: '1', child: Text('第1学期（秋季）')),
              DropdownMenuItem(value: '2', child: Text('第2学期（春季）')),
              DropdownMenuItem(value: '3', child: Text('第3学期（夏季）')),
            ],
            onChanged: (value) {
              if (value != null) {
                term = value;
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              final count = await provider.syncCourses(year, term);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    count > 0 ? '已同步 $count 条课程' : '未获取到课程，请检查登录状态或学期设置',
                  ),
                ),
              );
            } on CourseSyncException catch (e) {
              if (!context.mounted) return;
              _showSyncError(context, e);
            }
          },
          child: const Text('同步'),
        ),
      ],
    ),
  );
}

void _showSyncError(BuildContext context, CourseSyncException error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.message)));
}
