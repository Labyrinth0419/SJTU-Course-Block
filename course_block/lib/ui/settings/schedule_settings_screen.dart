import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/course_provider.dart';
import 'package:intl/intl.dart';
import 'package:numberpicker/numberpicker.dart';

class ScheduleSettingsScreen extends StatelessWidget {
  const ScheduleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课表设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final schedule = provider.currentSchedule;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('课表数据'),
              _buildSettingTile(
                context,
                title: '第一周的第一天',
                trailing: Text(
                  schedule != null
                      ? DateFormat(
                          'yyyy-MM-dd EEEE',
                          'zh_CN',
                        ).format(schedule.startDate)
                      : '未设置',
                ),
                onTap: () async {
                  // Pick Start Date
                  if (schedule == null) return;
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: schedule.startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('zh', 'CN'),
                  );
                  if (newDate != null) {
                    provider.updateSchedule(
                      schedule.copyWith(startDate: newDate),
                    );
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '一天课程节数',
                trailing: Text('${provider.maxDailyClasses} 节'),
                onTap: () {
                  _showNumberPickerDialog(
                    context,
                    '一天课程节数',
                    provider.maxDailyClasses,
                    (v) => provider.updateSetting('max_daily_classes', v),
                    min: 8,
                    max: 20,
                  );
                },
              ),
              _buildSettingTile(
                context,
                title: '学期周数',
                trailing: Text('${provider.totalWeeks} 周'),
                onTap: () {
                  _showNumberPickerDialog(
                    context,
                    '学期周数',
                    provider.totalWeeks,
                    (v) => provider.updateSetting('total_weeks', v),
                    min: 10,
                    max: 30,
                  );
                },
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('课表外观'),
              _buildSwitchTile(
                '显示周六',
                provider.showSaturday,
                (v) => provider.updateSetting('show_saturday', v),
              ),
              _buildSwitchTile(
                '显示周日',
                provider.showSunday,
                (v) => provider.updateSetting('show_sunday', v),
              ),
              _buildSettingTile(
                context,
                title: '课程格子高度',
                trailing: Text('${provider.gridHeight.toInt()} dp'),
                onTap: () {
                  _showDoubleInputDialog(
                    context,
                    '课程格子高度',
                    provider.gridHeight,
                    (v) => provider.updateSetting('grid_height', v),
                  );
                },
              ),
              _buildSettingTile(
                context,
                title: '格子圆角半径',
                trailing: Text('${provider.cornerRadius.toInt()} dp'),
                onTap: () {
                  _showDoubleInputDialog(
                    context,
                    '格子圆角半径',
                    provider.cornerRadius,
                    (v) => provider.updateSetting('corner_radius', v),
                  );
                },
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('更多外观设置'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '背景、文字颜色和大小、格子高度和不透明度……',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              _buildSettingTile(
                context,
                title: '背景颜色',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: provider.backgroundColor ?? Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onTap: () {
                  _showColorPicker(context, provider);
                },
              ),
              _buildSettingTile(
                context,
                title: '背景图片',
                trailing:
                    provider.backgroundImagePath != null &&
                        provider.backgroundImagePath!.isNotEmpty
                    ? const Icon(Icons.image, color: Colors.blue)
                    : const Text('未设置', style: TextStyle(color: Colors.grey)),
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    provider.setBackgroundImage(image.path);
                  }
                },
              ),
              if (provider.backgroundImagePath != null &&
                  provider.backgroundImagePath!.isNotEmpty) ...[
                _buildSettingTile(
                  context,
                  title: '背景透明度',
                  trailing: Text(
                    '${(provider.backgroundImageOpacity * 100).toInt()}%',
                  ),
                  onTap: () {
                    // Show slider dialog
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('背景透明度'),
                          content: StatefulBuilder(
                            builder: (context, setState) {
                              return SizedBox(
                                height: 50,
                                child: Slider(
                                  value: provider.backgroundImageOpacity,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 20,
                                  label:
                                      '${(provider.backgroundImageOpacity * 100).toInt()}%',
                                  onChanged: (value) {
                                    provider.updateSetting(
                                      'background_image_opacity',
                                      value,
                                    );
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('完成'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                _buildSettingTile(
                  context,
                  title: '清除背景图片',
                  trailing: const Icon(Icons.delete_outline, color: Colors.red),
                  onTap: () {
                    provider.setBackgroundImage('');
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String label,
    required String value,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(trailing),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing:
            trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  void _showColorPicker(BuildContext context, CourseProvider provider) {
    final colors = [
      Colors.white,
      Colors.pink.shade50,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.yellow.shade50,
      Colors.purple.shade50,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择背景颜色'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors
                .map(
                  (c) => InkWell(
                    onTap: () {
                      provider.updateSetting('background_color', c.value);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: c,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: provider.backgroundColor?.value == c.value
                          ? const Icon(Icons.check)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void _showNumberPickerDialog(
    BuildContext context,
    String title,
    int currentValue,
    ValueChanged<int> onChanged, {
    int min = 1,
    int max = 20,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedValue = currentValue;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: NumberPicker(
                value: selectedValue,
                minValue: min,
                maxValue: max,
                onChanged: (value) {
                  setState(() => selectedValue = value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    onChanged(selectedValue);
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDoubleInputDialog(
    BuildContext context,
    String title,
    double currentValue,
    ValueChanged<double> onChanged, {
    String suffix = 'dp',
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  onChanged(val);
                }
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showTimeSettingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上课时间设置'),
        content: const Text('暂不支持自定义每节课的具体时间。目前使用上海交通大学作息时间表。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}
