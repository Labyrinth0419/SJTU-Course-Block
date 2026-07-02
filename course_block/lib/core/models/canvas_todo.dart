import 'package:flutter/material.dart';

/// Canvas 待办事项的类型，来源于 planner item 的 `plannable_type`。
enum CanvasTodoType {
  assignment(label: '作业', icon: Icons.assignment_outlined),
  quiz(label: '测验', icon: Icons.quiz_outlined),
  discussion(label: '讨论', icon: Icons.forum_outlined),
  announcement(label: '公告', icon: Icons.campaign_outlined),
  calendarEvent(label: '日程', icon: Icons.event_outlined),
  plannerNote(label: '笔记', icon: Icons.sticky_note_2_outlined),
  other(label: '待办', icon: Icons.check_circle_outline);

  const CanvasTodoType({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static CanvasTodoType fromPlannableType(String? raw) {
    switch (raw) {
      case 'assignment':
      case 'sub_assignment':
        return CanvasTodoType.assignment;
      case 'quiz':
        return CanvasTodoType.quiz;
      case 'discussion_topic':
        return CanvasTodoType.discussion;
      case 'announcement':
        return CanvasTodoType.announcement;
      case 'calendar_event':
        return CanvasTodoType.calendarEvent;
      case 'planner_note':
        return CanvasTodoType.plannerNote;
      default:
        return CanvasTodoType.other;
    }
  }
}

/// 一条 Canvas 待办事项，从 `GET /api/v1/planner/items` 的单个元素解析而来。
class CanvasTodo {
  const CanvasTodo({
    required this.title,
    required this.type,
    this.courseName,
    this.dueAt,
    this.htmlUrl,
    this.pointsPossible,
    this.isCompleted = false,
  });

  final String title;
  final CanvasTodoType type;

  /// 所属课程名（planner item 的 `context_name`），个人笔记等可能为空。
  final String? courseName;

  /// 截止/发生时间，已转为本地时区。可能为空（如无截止时间的笔记）。
  final DateTime? dueAt;

  /// 点击后在浏览器打开的 Canvas 页面地址（已补全为绝对地址）。
  final String? htmlUrl;

  /// 满分（作业/测验），可能为空。
  final double? pointsPossible;

  /// 是否已完成/已提交（用于过滤与逾期判定）。
  final bool isCompleted;

  bool get isOverdue =>
      !isCompleted && dueAt != null && dueAt!.isBefore(DateTime.now());

  /// 从 planner item 的一个元素构造。字段做了空安全与类型兜底，
  /// 无法解析的元素返回 null（调用方过滤掉）。
  static CanvasTodo? fromPlannerItem(
    Map<String, dynamic> item, {
    String baseUrl = 'https://oc.sjtu.edu.cn',
  }) {
    final plannableType = item['plannable_type']?.toString();
    final plannable = item['plannable'];
    final plannableMap = plannable is Map<String, dynamic>
        ? plannable
        : const <String, dynamic>{};

    // 标题：作业/测验用 title，日程可能用 title，笔记用 title。
    final title =
        _asString(plannableMap['title']) ??
        _asString(plannableMap['name']) ??
        _asString(item['context_name']) ??
        '未命名待办';

    // 截止/发生时间：优先 plannable 内的时间，再退回顶层 plannable_date。
    final dueAt =
        _asDate(plannableMap['due_at']) ??
        _asDate(plannableMap['todo_date']) ??
        _asDate(plannableMap['start_at']) ??
        _asDate(item['plannable_date']);

    // 点击地址：html_url 可能是相对路径，补全为绝对地址。
    final htmlUrl = _absoluteUrl(_asString(item['html_url']), baseUrl);

    // 完成状态：planner_override.marked_complete 或已提交。
    final override = item['planner_override'];
    final markedComplete =
        override is Map<String, dynamic> && override['marked_complete'] == true;
    final submissions = item['submissions'];
    final submitted =
        submissions is Map<String, dynamic> && submissions['submitted'] == true;

    return CanvasTodo(
      title: title,
      type: CanvasTodoType.fromPlannableType(plannableType),
      courseName: _asString(item['context_name']),
      dueAt: dueAt,
      htmlUrl: htmlUrl,
      pointsPossible: _asDouble(plannableMap['points_possible']),
      isCompleted: markedComplete || submitted,
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDate(dynamic value) {
    final text = _asString(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    return parsed?.toLocal();
  }

  static String? _absoluteUrl(String? url, String baseUrl) {
    if (url == null) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = url.startsWith('/') ? url : '/$url';
    return '$normalizedBase$normalizedPath';
  }
}
