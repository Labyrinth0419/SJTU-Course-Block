import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'webview_login_screen.dart';

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('选择登录方式')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.aboutGradientStart,
                          palette.aboutGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
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
                          '教务系统登录',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '选择你的教务入口，登录成功后会自动保存 Cookie。',
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
          _LoginEntryCard(
            icon: Icons.school_rounded,
            color: theme.colorScheme.primaryContainer,
            title: '本科生教务系统',
            subtitle: '适用于本科课程同步与课表导入',
            badge: '常用',
            onTap: () => _openLogin(
              context,
              initialUrl: 'https://i.sjtu.edu.cn/jaccountlogin',
              title: '本科生登录',
            ),
          ),
          const SizedBox(height: 10),
          _LoginEntryCard(
            icon: Icons.auto_stories_rounded,
            color: theme.colorScheme.secondaryContainer,
            title: '研究生教务系统',
            subtitle: '适用于研究生课表入口',
            onTap: () => _openLogin(
              context,
              initialUrl:
                  'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/wdkb/1566868668786.shtml',
              title: '研究生登录',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLogin(
    BuildContext context, {
    required String initialUrl,
    required String title,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebviewLoginScreen(initialUrl: initialUrl, title: title),
      ),
    );

    if (result == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }
}

class _LoginEntryCard extends StatelessWidget {
  const _LoginEntryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(icon, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
