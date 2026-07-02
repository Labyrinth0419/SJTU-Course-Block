import 'package:course_block/core/models/canvas_todo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasTodo.fromPlannerItem', () {
    test('parses an assignment with due date and points', () {
      final item = <String, dynamic>{
        'context_type': 'Course',
        'context_name': '高等数学',
        'plannable_type': 'assignment',
        'plannable_date': '2999-01-10T15:59:00Z',
        'plannable': {
          'title': '第一章作业',
          'due_at': '2999-01-10T15:59:00Z',
          'points_possible': 100,
        },
        'html_url': '/courses/1/assignments/2',
        'submissions': {'submitted': false},
      };

      final todo = CanvasTodo.fromPlannerItem(item);

      expect(todo, isNotNull);
      expect(todo!.title, '第一章作业');
      expect(todo.courseName, '高等数学');
      expect(todo.type, CanvasTodoType.assignment);
      expect(todo.pointsPossible, 100);
      expect(todo.htmlUrl, 'https://oc.sjtu.edu.cn/courses/1/assignments/2');
      expect(todo.dueAt, isNotNull);
      expect(todo.isCompleted, isFalse);
      // Far-future due date is not overdue.
      expect(todo.isOverdue, isFalse);
    });

    test('marks a past-due unsubmitted assignment as overdue', () {
      final item = <String, dynamic>{
        'context_name': '大学物理',
        'plannable_type': 'assignment',
        'plannable': {
          'title': '过期作业',
          'due_at': '2000-01-01T00:00:00Z',
        },
        'html_url': 'https://oc.sjtu.edu.cn/courses/9/assignments/9',
        'submissions': {'submitted': false},
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.isOverdue, isTrue);
    });

    test('does not mark a completed item as overdue', () {
      final item = <String, dynamic>{
        'plannable_type': 'assignment',
        'plannable': {
          'title': '已提交作业',
          'due_at': '2000-01-01T00:00:00Z',
        },
        'submissions': {'submitted': true},
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.isCompleted, isTrue);
      expect(todo.isOverdue, isFalse);
    });

    test('respects planner_override marked_complete', () {
      final item = <String, dynamic>{
        'plannable_type': 'discussion_topic',
        'plannable': {'title': '讨论', 'due_at': '2000-01-01T00:00:00Z'},
        'planner_override': {'marked_complete': true},
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.type, CanvasTodoType.discussion);
      expect(todo.isCompleted, isTrue);
    });

    test('parses a planner_note with todo_date and no due_at', () {
      final item = <String, dynamic>{
        'plannable_type': 'planner_note',
        'plannable': {
          'title': '复习笔记',
          'todo_date': '2999-05-01T08:00:00Z',
        },
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.type, CanvasTodoType.plannerNote);
      expect(todo.title, '复习笔记');
      expect(todo.dueAt, isNotNull);
      expect(todo.htmlUrl, isNull);
      expect(todo.courseName, isNull);
    });

    test('handles a missing title and missing due date gracefully', () {
      final item = <String, dynamic>{
        'plannable_type': 'calendar_event',
        'plannable': <String, dynamic>{},
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.type, CanvasTodoType.calendarEvent);
      expect(todo.title, '未命名待办');
      expect(todo.dueAt, isNull);
      expect(todo.isOverdue, isFalse);
    });

    test('unknown plannable_type falls back to other', () {
      final item = <String, dynamic>{
        'plannable_type': 'wiki_page',
        'plannable': {'title': '页面'},
      };

      final todo = CanvasTodo.fromPlannerItem(item)!;

      expect(todo.type, CanvasTodoType.other);
    });
  });
}
