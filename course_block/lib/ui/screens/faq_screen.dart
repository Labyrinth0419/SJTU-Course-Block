import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  /// 比较版本号，若 a > b 返回 true（忽略前缀 'v'）
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
      if (mounted) _showSnack('网络错误，请检查连接后重试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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

  final List<_FaqItem> _items = [
    _FaqItem(header: '如何更新课表？', body: '打开"同步课表"页面，输入学年学期并点击同步即可。也可以手动添加课程。'),
    _FaqItem(
      header: '桌面组件不刷新怎么办？',
      body: '尝试在应用内进入设置界面，然后再次回到首页，这会触发刷新。如果仍无效，可重启设备。',
    ),
    _FaqItem(
      header: '如何备份/恢复数据？',
      body: '在设置中使用导出功能生成 JSON 文件；使用导入功能可恢复之前备份的课表。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ExpansionPanelList.radio(
                children: _items
                    .map(
                      (item) => ExpansionPanelRadio(
                        value: item.header,
                        headerBuilder: (context, isExpanded) {
                          return ListTile(title: Text(item.header));
                        },
                        body: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(item.body),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('检查更新'),
            trailing: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _checking ? null : _checkUpdate,
          ),
          ListTile(
            title: const Text('提交问题反馈'),
            onTap: () => launchUrl(
              Uri.parse(_releasesUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(_version.isEmpty ? '' : '当前版本: $_version')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String header;
  final String body;
  _FaqItem({required this.header, required this.body});
}
