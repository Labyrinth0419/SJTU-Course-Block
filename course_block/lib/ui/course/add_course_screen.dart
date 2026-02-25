// lib/ui/course/add_course_screen.dart
import 'package:flutter/material.dart';
import '../../core/models/course.dart';
import '../../core/db/database_helper.dart';
import 'package:provider/provider.dart';
import '../../core/providers/course_provider.dart';

class AddCourseScreen extends StatefulWidget {
  final Course? course; // If provided, edit mode

  const AddCourseScreen({super.key, this.course});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _teacherController;
  late TextEditingController _roomController;
  late int _dayOfWeek;
  late int _startNode;
  late int _step;
  late int _startWeek;
  late int _endWeek;
  late bool _isVirtual;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.course?.courseName ?? '',
    );
    _teacherController = TextEditingController(
      text: widget.course?.teacher ?? '',
    );
    // ... rest of controllers ...
    _roomController = TextEditingController(
      text: widget.course?.classRoom ?? '',
    );
    _dayOfWeek = widget.course?.dayOfWeek ?? 1;
    _startNode = widget.course?.startNode ?? 1;
    _step = widget.course?.step ?? 2;
    _startWeek = widget.course?.startWeek ?? 1;
    _endWeek = widget.course?.endWeek ?? 16;
    _isVirtual = widget.course?.isVirtual ?? false;
    _color = widget.course?.color ?? Course.COLORS[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '添加课程' : '编辑课程'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveCourse),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '课程名称'),
              validator: (value) => value!.isEmpty ? '请输入课程名称' : null,
            ),
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(labelText: '教师'),
            ),
            TextFormField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: '教室'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(labelText: '星期'),
              items: List.generate(7, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('周${['一', '二', '三', '四', '五', '六', '日'][index]}'),
                );
              }),
              onChanged: (value) => setState(() => _dayOfWeek = value!),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _startNode.toString(),
                    decoration: const InputDecoration(labelText: '开始节次'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _startNode = int.tryParse(val) ?? 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _step.toString(),
                    decoration: const InputDecoration(labelText: '节数'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _step = int.tryParse(val) ?? 2,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _startWeek.toString(),
                    decoration: const InputDecoration(labelText: '开始周'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _startWeek = int.tryParse(val) ?? 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _endWeek.toString(),
                    decoration: const InputDecoration(labelText: '结束周'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _endWeek = int.tryParse(val) ?? 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: CheckboxListTile(
                title: const Text('虚拟排课'),
                subtitle: const Text('标记为非必须课程，显示为灰色'),
                value: _isVirtual,
                onChanged: (val) {
                  setState(() {
                    _isVirtual = val ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            const Text('课程颜色', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: Course.COLORS.map((colorStr) {
                final color = Color(
                  int.parse(colorStr.replaceFirst('#', '0xFF')),
                );
                final isSelected = _color == colorStr;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _color = colorStr;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveCourse,
                child: Text(widget.course == null ? '添加课程' : '保存修改'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _saveCourse() async {
    if (_formKey.currentState!.validate()) {
      final scheduleId = context.read<CourseProvider>().currentSchedule?.id;

      final course = Course(
        id: widget.course?.id,
        scheduleId: scheduleId,
        courseId:
            widget.course?.courseId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        courseName: _nameController.text,
        teacher: _teacherController.text,
        classRoom: _roomController.text,
        dayOfWeek: _dayOfWeek,
        startNode: _startNode,
        step: _step,
        startWeek: _startWeek,
        endWeek: _endWeek,
        isVirtual: _isVirtual,
        color: _color,
      );

      if (widget.course == null) {
        await DatabaseHelper.instance.insertCourse(course);
      } else {
        await DatabaseHelper.instance.updateCourse(course);
      }

      if (mounted) Navigator.pop(context, true);
    }
  }
}
