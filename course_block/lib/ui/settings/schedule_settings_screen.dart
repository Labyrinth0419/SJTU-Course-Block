import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/course_provider.dart';
import 'package:intl/intl.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class ScheduleSettingsScreen extends StatelessWidget {
  const ScheduleSettingsScreen({super.key});

  static const MethodChannel _fileChannel = MethodChannel('course_block/file');

  Future<String?> _saveBytes(String filename, Uint8List bytes) async {
    try {
      final res = await _fileChannel.invokeMethod<String>('saveFile', {
        'name': filename,
        'bytes': bytes,
      });
      return res;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课表设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final schedule = provider.currentSchedule;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, '课表数据'),
              _buildSettingTile(
                context,
                title: '课表名称',
                trailing: Text(schedule?.name ?? '未命名'),
                onTap: () async {
                  if (schedule == null) return;
                  final controller = TextEditingController(text: schedule.name);
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('编辑课表名称'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: '输入名称'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                  if (newName != null && newName.trim().isNotEmpty) {
                    provider.updateSchedule(
                      schedule.copyWith(name: newName.trim()),
                    );
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '学年',
                trailing: Text(schedule?.year ?? ''),
                onTap: () async {
                  if (schedule == null) return;
                  final controller = TextEditingController(text: schedule.year);
                  final newYear = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('编辑学年'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '例如 2024'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                  if (newYear != null && newYear.trim().isNotEmpty) {
                    provider.updateSchedule(
                      schedule.copyWith(year: newYear.trim()),
                    );
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '学期',
                trailing: Text(schedule?.term ?? ''),
                onTap: () async {
                  if (schedule == null) return;
                  final controller = TextEditingController(text: schedule.term);
                  final newTerm = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('编辑学期'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '例如 1'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                  if (newTerm != null && newTerm.trim().isNotEmpty) {
                    provider.updateSchedule(
                      schedule.copyWith(term: newTerm.trim()),
                    );
                  }
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
              const SizedBox(height: 10),
              _buildSectionHeader(context, '导出与备份'),
              _buildSettingTile(
                context,
                title: '导出为 JSON',
                trailing: const Icon(Icons.file_copy, color: Colors.blue),
                onTap: () async {
                  if (Theme.of(context).platform == TargetPlatform.android ||
                      Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.fuchsia) {
                    final bytes = await provider.exportCoursesJsonBytes();
                    final uri = await _saveBytes('course_export.json', bytes);
                    if (uri != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已导出到 $uri')));
                    }
                    return;
                  }
                  final typeGroup = fs.XTypeGroup(
                    label: 'json',
                    extensions: ['json'],
                  );
                  String? savePath;
                  try {
                    final location = await fs.getSaveLocation(
                      acceptedTypeGroups: [typeGroup],
                      suggestedName: 'course_export.json',
                    );
                    savePath = location?.path;
                  } catch (e) {
                    savePath = null;
                  }
                  String path;
                  if (savePath != null) {
                    path = await provider.exportCoursesJson(savePath);
                  } else {
                    path = await provider.exportCoursesJson();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('已导出到 $path')));
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '导出为 ICS',
                trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                onTap: () async {
                  if (Theme.of(context).platform == TargetPlatform.android ||
                      Theme.of(context).platform == TargetPlatform.iOS ||
                      Theme.of(context).platform == TargetPlatform.fuchsia) {
                    final bytes = await provider.exportCoursesIcsBytes();
                    final uri = await _saveBytes('course_export.ics', bytes);
                    if (uri != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已导出到 $uri')));
                    }
                    return;
                  }
                  final typeGroup = fs.XTypeGroup(
                    label: 'ics',
                    extensions: ['ics'],
                  );
                  String? savePath;
                  try {
                    final location = await fs.getSaveLocation(
                      acceptedTypeGroups: [typeGroup],
                      suggestedName: 'course_export.ics',
                    );
                    savePath = location?.path;
                  } catch (e) {
                    savePath = null;
                  }
                  String path;
                  if (savePath != null) {
                    path = await provider.exportCoursesIcs(savePath);
                  } else {
                    path = await provider.exportCoursesIcs();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('已导出到 $path')));
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '从 JSON 导入',
                trailing: const Icon(Icons.upload_file, color: Colors.green),
                onTap: () async {
                  final typeGroup = fs.XTypeGroup(
                    label: 'json',
                    extensions: ['json'],
                  );
                  final file = await fs.openFile(
                    acceptedTypeGroups: [typeGroup],
                  );
                  if (file != null) {
                    final path = file.path;
                    final count = await provider.importCoursesJson(path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('导入 $count 条课程')));
                    }
                  }
                },
              ),
              _buildSettingTile(
                context,
                title: '从 ICS 导入',
                trailing: const Icon(Icons.upload_file, color: Colors.green),
                onTap: () async {
                  final typeGroup = fs.XTypeGroup(
                    label: 'ics',
                    extensions: ['ics'],
                  );
                  final file = await fs.openFile(
                    acceptedTypeGroups: [typeGroup],
                  );
                  if (file != null) {
                    final path = file.path;
                    final count = await provider.importCoursesIcs(path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('导入 $count 条课程')));
                    }
                  }
                },
              ),

              const SizedBox(height: 10),
              _buildSectionHeader(context, '外观设置'),
              _buildSwitchTile(
                context,
                '显示周六',
                provider.showSaturday,
                (v) => provider.updateSetting('show_saturday', v),
              ),
              _buildSwitchTile(
                context,
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
              _buildSectionHeader(context, '背景设置'),
              const SizedBox(height: 8),
              _buildBackgroundPreview(context, provider),
              const SizedBox(height: 16),
              _buildSettingTile(
                context,
                title: '背景颜色（浅色）',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        provider.backgroundColorLight ??
                        Theme.of(context).colorScheme.background,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onTap: () {
                  _showColorPicker(context, provider, 'background_color_light');
                },
              ),
              _buildSettingTile(
                context,
                title: '背景颜色（深色）',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        provider.backgroundColorDark ??
                        Theme.of(context).colorScheme.background,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onTap: () {
                  _showColorPicker(context, provider, 'background_color_dark');
                },
              ),
              _buildSettingTile(
                context,
                title: '背景图片',
                trailing:
                    provider.backgroundImagePath != null &&
                        provider.backgroundImagePath!.isNotEmpty
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.file(
                          File(provider.backgroundImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        '未设置',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                onTap: () async {
                  final picker = ImagePicker();
                  if (provider.backgroundImagePath != null &&
                      provider.backgroundImagePath!.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('背景图片'),
                          content: GestureDetector(
                            onTap: () async {
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null) {
                                provider.setBackgroundImage(image.path);
                                Navigator.pop(ctx);
                              }
                            },
                            child: Image.file(
                              File(provider.backgroundImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('关闭'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  provider.setBackgroundImage(image.path);
                                }
                                Navigator.pop(ctx);
                              },
                              child: const Text('更换'),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      provider.setBackgroundImage(image.path);
                    }
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
                  trailing: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildBackgroundPreview(
    BuildContext context,
    CourseProvider provider,
  ) {
    final light =
        provider.backgroundColorLight ??
        Theme.of(context).colorScheme.background;
    final dark =
        provider.backgroundColorDark ??
        Theme.of(context).colorScheme.background;
    final imagePath = provider.backgroundImagePath;
    final opacity = provider.backgroundImageOpacity;
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: imagePath != null && imagePath.isNotEmpty
                  ? BoxDecoration(
                      color: light,
                      image: DecorationImage(
                        image: FileImage(File(imagePath)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(opacity),
                          BlendMode.dstATop,
                        ),
                      ),
                    )
                  : BoxDecoration(color: light),
              child: const Center(child: Text('浅色')),
            ),
          ),
          Expanded(
            child: Container(
              decoration: imagePath != null && imagePath.isNotEmpty
                  ? BoxDecoration(
                      color: dark,
                      image: DecorationImage(
                        image: FileImage(File(imagePath)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(opacity),
                          BlendMode.dstATop,
                        ),
                      ),
                    )
                  : BoxDecoration(color: dark),
              child: const Center(child: Text('深色')),
            ),
          ),
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
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
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
            Theme.of(context).colorScheme.background,
          ]
        : <Color>[
            Colors.black,
            Colors.pink.shade900,
            Colors.blue.shade900,
            Colors.green.shade900,
            Colors.grey.shade800,
            Colors.brown.shade800,
            Theme.of(context).colorScheme.background,
          ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isLight ? '选择浅色背景颜色' : '选择深色背景颜色'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors
                .map(
                  (c) => InkWell(
                    onTap: () {
                      provider.updateSetting(settingKey, c.value);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: c,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          ((settingKey == 'background_color_light'
                                      ? provider.backgroundColorLight
                                      : provider.backgroundColorDark)
                                  ?.value ==
                              c.value)
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
}
