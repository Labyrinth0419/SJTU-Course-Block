import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/course_provider.dart';

class ScheduleManagementScreen extends StatelessWidget {
  const ScheduleManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课表管理')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedules = provider.schedules;

          if (schedules.isEmpty) {
            return const Center(child: Text('暂无课表，请点击右下角添加'));
          }

          return ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return ListTile(
                leading: Icon(
                  schedule.isCurrent
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: schedule.isCurrent ? Colors.green : Colors.grey,
                ),
                title: Text(schedule.name),
                subtitle: Text('${schedule.year} ${schedule.term}学期'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    if (schedule.isCurrent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法删除当前使用的课表')),
                      );
                      return;
                    }
                    // Confirm delete
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除课表'),
                        content: Text('确定要删除课表 "${schedule.name}" 吗？此操作不可恢复。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await provider.deleteSchedule(schedule.id!);
                    }
                  },
                ),
                onTap: () {
                  if (!schedule.isCurrent) {
                    provider.switchSchedule(schedule.id!);
                    Navigator.pop(context); // Go back after switching
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddScheduleDialog(context);
        },
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final yearController = TextEditingController(
      text: DateTime.now().year.toString(),
    );
    final termController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建课表'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '课表名称'),
              ),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: '学年 (例如 2024)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: termController,
                decoration: const InputDecoration(labelText: '学期 (例如 1)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    yearController.text.isNotEmpty &&
                    termController.text.isNotEmpty) {
                  context.read<CourseProvider>().addSchedule(
                    nameController.text,
                    yearController.text,
                    termController.text,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
