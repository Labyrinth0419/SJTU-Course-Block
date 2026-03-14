import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/schedule.dart';
import '../../core/providers/course_provider.dart';

Future<void> showCurrentScheduleEditorDialog(
  BuildContext context,
  Schedule schedule,
) async {
  final provider = context.read<CourseProvider>();
  final nameController = TextEditingController(text: schedule.name);
  final yearController = TextEditingController(text: schedule.year);
  String term = schedule.term;
  DateTime startDate = schedule.startDate;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('编辑当前课表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '课表名称'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '学年起始年'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: term,
                decoration: const InputDecoration(labelText: '学期'),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('第1学期（秋季）')),
                  DropdownMenuItem(value: '2', child: Text('第2学期（春季）')),
                  DropdownMenuItem(value: '3', child: Text('第3学期（夏季）')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    term = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note),
                title: const Text('开学第一周周一'),
                subtitle: Text(
                  '${DateFormat('yyyy-MM-dd').format(startDate)}（建议选择学期第一周周一）',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('zh', 'CN'),
                  );
                  if (picked == null) return;
                  setDialogState(() {
                    startDate = picked;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final nextName = nameController.text.trim();
              final nextYear = yearController.text.trim();
              if (nextName.isEmpty || nextYear.isEmpty) {
                return;
              }

              await provider.updateSchedule(
                schedule.copyWith(
                  name: nextName,
                  year: nextYear,
                  term: term,
                  startDate: startDate,
                ),
              );

              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已更新当前课表')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showCreateScheduleDialog(BuildContext context) async {
  final provider = context.read<CourseProvider>();
  final now = DateTime.now();
  final nameController = TextEditingController();
  final yearController = TextEditingController(text: now.year.toString());
  String term = '1';
  DateTime startDate = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('新建课表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '课表名称'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '学年起始年'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: term,
                decoration: const InputDecoration(labelText: '学期'),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('第1学期（秋季）')),
                  DropdownMenuItem(value: '2', child: Text('第2学期（春季）')),
                  DropdownMenuItem(value: '3', child: Text('第3学期（夏季）')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    term = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note),
                title: const Text('开学第一周周一'),
                subtitle: Text(
                  '${DateFormat('yyyy-MM-dd').format(startDate)}（建议选择学期第一周周一）',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('zh', 'CN'),
                  );
                  if (picked == null) return;
                  setDialogState(() {
                    startDate = picked;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final nextName = nameController.text.trim();
              final nextYear = yearController.text.trim();
              if (nextName.isEmpty || nextYear.isEmpty) {
                return;
              }

              await provider.addSchedule(
                nextName,
                nextYear,
                term,
                startDate: startDate,
              );

              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已新建并切换到新课表')));
            },
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );
}
