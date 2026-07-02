import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/canvas_todo.dart';
import '../../core/providers/course_provider.dart';
import '../../core/services/login_session.dart';
import '../login/webview_login_screen.dart';

class CanvasTodosScreen extends StatefulWidget {
  const CanvasTodosScreen({super.key});

  @override
  State<CanvasTodosScreen> createState() => _CanvasTodosScreenState();
}

class _CanvasTodosScreenState extends State<CanvasTodosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CourseProvider>().loadCanvasTodos();
    });
  }

  Future<void> _refresh() {
    return context.read<CourseProvider>().loadCanvasTodos();
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const WebviewLoginScreen(
          initialUrl: 'https://oc.sjtu.edu.cn/login',
          title: 'Canvas 登录',
          loginSystem: AcademicLoginSystem.undergraduate,
          isCanvas: true,
        ),
      ),
    );
    if (result == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openTodo(CanvasTodo todo) async {
    final url = todo.htmlUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canvas 待办')),
      body: Consumer<CourseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCanvasTodos) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = provider.canvasTodoError;
          if (error != null) {
            return _CanvasMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Canvas 未登录',
              message: error,
              actionLabel: '去登录 Canvas',
              onAction: _openLogin,
            );
          }

          final todos = provider.canvasTodos;
          if (todos.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  _CanvasMessage(
                    icon: Icons.check_circle_outline_rounded,
                    title: '暂无待办',
                    message: '近期没有需要完成的 Canvas 事项。',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: todos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _CanvasTodoCard(
                todo: todos[index],
                onTap: () => _openTodo(todos[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CanvasTodoCard extends StatelessWidget {
  const _CanvasTodoCard({required this.todo, required this.onTap});

  final CanvasTodo todo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: todo.htmlUrl == null ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: Icon(todo.type.icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(text: todo.type.label),
                        if (todo.courseName != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              todo.courseName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (todo.dueAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: todo.isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDue(todo.dueAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: todo.isOverdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: todo.isOverdue
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (todo.isOverdue) ...[
                            const SizedBox(width: 6),
                            Text(
                              '已逾期',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (todo.htmlUrl != null)
                const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDue(DateTime due) {
    return DateFormat('MM月dd日 HH:mm', 'zh_CN').format(due);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CanvasMessage extends StatelessWidget {
  const _CanvasMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.login_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
