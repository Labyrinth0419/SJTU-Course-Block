import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/database_helper.dart';
import '../../core/models/course.dart';
import '../../core/providers/course_provider.dart';
import '../../core/theme/app_theme.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key, this.course});

  final Course? course;

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _roomController;
  late int _dayOfWeek;
  late int _startNode;
  late int _step;
  late int _startWeek;
  late int _endWeek;
  late bool _isVirtual;
  late String _color;
  late bool _colorManuallySelected;

  bool get _isEditMode => widget.course != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.course?.courseName ?? '',
    );
    _teacherController = TextEditingController(
      text: widget.course?.teacher ?? '',
    );
    _roomController = TextEditingController(
      text: widget.course?.classRoom ?? '',
    );
    _dayOfWeek = widget.course?.dayOfWeek ?? 1;
    _startNode = widget.course?.startNode ?? 1;
    _step = widget.course?.step ?? 2;
    _startWeek = widget.course?.startWeek ?? 1;
    _endWeek = widget.course?.endWeek ?? 16;
    _isVirtual = widget.course?.isVirtual ?? false;
    final initialColor = widget.course?.color ?? '';
    _color = initialColor;
    _colorManuallySelected = !isAutoCourseColorValue(initialColor);
    _nameController.addListener(_handleAutoColorChanged);
    _teacherController.addListener(_handleAutoColorChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _handleAutoColorChanged() {
    if (_colorManuallySelected || !mounted) return;
    setState(() {});
  }

  String _resolvedColorValue(CourseProvider provider) {
    if (_colorManuallySelected && _color.isNotEmpty) {
      return _color;
    }

    final identity = buildCourseColorSeed(
      _nameController.text,
      _teacherController.text,
    );
    final editingCourseId = widget.course?.id;
    final assignments = assignScheduledCourseColorTokens([
      for (final course in provider.courses)
        if (course.id != editingCourseId)
          CourseColorIdentityEntry(
            identity: buildCourseColorSeed(course.courseName, course.teacher),
            colorValue: course.color,
          ),
      CourseColorIdentityEntry(identity: identity, colorValue: ''),
    ], swatches: provider.courseColorPalette.colors(Brightness.light));

    return assignments[identity] ??
        provider.courseColorPalette.autoColorToken(identity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final provider = context.watch<CourseProvider>();
    final courseColorPalette = provider.courseColorPalette;
    final courseColors = courseColorPalette.colors(theme.brightness);
    final resolvedColorValue = _resolvedColorValue(provider);
    final title = _isEditMode ? '编辑课程' : '添加课程';
    final buttonLabel = _isEditMode ? '保存修改' : '添加课程';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(onPressed: _saveCourse, child: const Text('保存')),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            palette.aboutGradientStart,
                            palette.aboutGradientEnd,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '设置课程名称、时间和周次。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '基础信息',
              children: [
                _FieldLabel(
                  icon: Icons.book_rounded,
                  color: theme.colorScheme.primaryContainer,
                  text: '课程名称',
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: '请输入课程名称'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入课程名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FieldLabel(
                  icon: Icons.person_outline_rounded,
                  color: theme.colorScheme.secondaryContainer,
                  text: '授课教师',
                ),
                TextFormField(
                  controller: _teacherController,
                  decoration: const InputDecoration(hintText: '可不填'),
                ),
                const SizedBox(height: 14),
                _FieldLabel(
                  icon: Icons.location_on_outlined,
                  color: theme.colorScheme.tertiaryContainer,
                  text: '上课地点',
                ),
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(hintText: '可不填'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '时间安排',
              children: [
                _FieldLabel(
                  icon: Icons.calendar_today_rounded,
                  color: theme.colorScheme.primaryContainer,
                  text: '星期',
                ),
                DropdownButtonFormField<int>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(hintText: '选择星期'),
                  items: List.generate(7, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        '周${['一', '二', '三', '四', '五', '六', '日'][index]}',
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _dayOfWeek = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        icon: Icons.play_arrow_rounded,
                        color: theme.colorScheme.secondaryContainer,
                        label: '开始节次',
                        initialValue: _startNode,
                        onChanged: (value) => _startNode = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        icon: Icons.more_time_rounded,
                        color: theme.colorScheme.tertiaryContainer,
                        label: '节数',
                        initialValue: _step,
                        onChanged: (value) => _step = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        icon: Icons.filter_1_rounded,
                        color: theme.colorScheme.primaryContainer,
                        label: '开始周',
                        initialValue: _startWeek,
                        onChanged: (value) => _startWeek = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        icon: Icons.filter_9_plus_rounded,
                        color: theme.colorScheme.secondaryContainer,
                        label: '结束周',
                        initialValue: _endWeek,
                        onChanged: (value) => _endWeek = value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '显示与状态',
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    value: _isVirtual,
                    onChanged: (value) {
                      setState(() {
                        _isVirtual = value;
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      foregroundColor: theme.colorScheme.onTertiaryContainer,
                      child: const Icon(Icons.layers_clear_rounded),
                    ),
                    title: Text(
                      '虚拟排课',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text('标记为非必须课程，显示为灰色'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 14),
                _FieldLabel(
                  icon: Icons.palette_outlined,
                  color: theme.colorScheme.primaryContainer,
                  text: '课程颜色',
                ),
                const SizedBox(height: 4),
                Text(
                  '当前色板：${courseColorPalette.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(courseColors.length, (index) {
                    final color = courseColors[index];
                    final isSelected =
                        resolveCourseColorSelectionIndex(
                          resolvedColorValue,
                          courseColors.length,
                        ) ==
                        index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _colorManuallySelected = true;
                          _color = buildCourseColorToken(index);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(
                                alpha: 0.14,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: color.computeLuminance() > 0.55
                                    ? const Color(0xFF181C27)
                                    : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saveCourse,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CourseProvider>();
    final scheduleId = provider.currentSchedule?.id;
    final colorValue = _resolvedColorValue(provider);
    final course = Course(
      id: widget.course?.id,
      scheduleId: scheduleId,
      courseId:
          widget.course?.courseId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      courseName: _nameController.text.trim(),
      teacher: _teacherController.text.trim(),
      classRoom: _roomController.text.trim(),
      dayOfWeek: _dayOfWeek,
      startNode: _startNode,
      step: _step,
      startWeek: _startWeek,
      endWeek: _endWeek,
      isVirtual: _isVirtual,
      color: colorValue,
    );

    if (widget.course == null) {
      await DatabaseHelper.instance.insertCourse(course);
    } else {
      await DatabaseHelper.instance.updateCourse(course);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.icon,
    required this.color,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(icon: icon, color: color, text: label),
        TextFormField(
          initialValue: initialValue.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: label),
          onChanged: (value) => onChanged(int.tryParse(value) ?? initialValue),
        ),
      ],
    );
  }
}
