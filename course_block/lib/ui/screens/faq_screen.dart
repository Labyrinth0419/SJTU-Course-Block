import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

const _releasesUrl =
    'https://github.com/Labyrinth0419/SJTU-Course-Block/releases';
const _apiUrl =
    'https://api.github.com/repos/Labyrinth0419/SJTU-Course-Block/releases/latest';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final List<_FaqItem> _items = const [
    _FaqItem(
      icon: Icons.download_rounded,
      title: '如何更新课表？',
      body: '点击首页右上角的导入图标，可以从教务系统同步当前学期或其他学期，也可以手动导入 JSON / ICS 文件。',
    ),
    _FaqItem(
      icon: Icons.widgets_outlined,
      title: '桌面组件不刷新怎么办？',
      body: '尝试在应用内进入设置界面，然后再次回到首页，这会触发刷新。如果仍无效，可重启设备。',
    ),
    _FaqItem(
      icon: Icons.ios_share_rounded,
      title: '如何备份/恢复数据？',
      body: '点击首页右上角的导出图标可以生成备份文件；点击导入图标并选择 JSON 文件即可恢复之前备份的课表。',
    ),
  ];

  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = 'v${info.version}';
        });
      }
    });
  }

  bool _isNewer(String remote, String local) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^v'), '')
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final r = parse(remote);
    final l = parse(local);
    for (var i = 0; i < r.length || i < l.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final resp = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resp.statusCode != 200) {
        _showSnack('检查失败（${resp.statusCode}），请稍后重试');
        return;
      }

      final tag = (jsonDecode(resp.body) as Map)['tag_name'] as String? ?? '';
      final current = _version.replaceFirst('v', '');

      if (_isNewer(tag, current)) {
        _showUpdateDialog(tag);
      } else {
        _showSnack('已是最新版本 $_version');
      }
    } on Exception {
      if (mounted) {
        _showSnack('网络错误，请检查连接后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showUpdateDialog(String latestTag) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('最新版本：$latestTag\n当前版本：$_version'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(_releasesUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('前往下载'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
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
                      Icons.help_outline_rounded,
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
                          '常见问题',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '把常用说明、更新检查和反馈入口集中在一起。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_version.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _version,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqCard(item: item),
            ),
          ),
          const SizedBox(height: 2),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.system_update_rounded,
                    color: theme.colorScheme.primaryContainer,
                    title: '检查更新',
                    subtitle: _checking ? '正在检查最新版本' : '查看 GitHub Release',
                    trailing: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _checking ? null : _checkUpdate,
                  ),
                  const SizedBox(height: 8),
                  _ActionRow(
                    icon: Icons.bug_report_outlined,
                    color: theme.colorScheme.secondaryContainer,
                    title: '提交问题反馈',
                    subtitle: '前往项目仓库反馈问题或提出建议',
                    onTap: () => launchUrl(
                      Uri.parse(_releasesUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Icon(item.icon, size: 20),
          ),
          title: Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '点击展开说明',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}
