import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_update_service.dart';

class AppUpdateDialog {
  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context,
    ReleaseUpdate update, {
    Future<bool> Function(Uri)? openUrl,
  }) async {
    if (_isShowing || !context.mounted) return;
    _isShowing = true;
    bool? download;
    try {
      download = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('发现新版本 v${update.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本：v${update.currentVersion}\n'
                  '最新版本：v${update.version}',
                ),
                if (update.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(update.notes.trim()),
                ],
                const SizedBox(height: 16),
                const Text(
                  '前往官方 GitHub Release 页面下载 APK，并覆盖安装。'
                  '升级时请沿用已安装包的架构，不需要卸载应用。',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('前往下载'),
            ),
          ],
        ),
      );
    } finally {
      _isShowing = false;
    }
    if (download != true || !context.mounted) return;
    try {
      final opened =
          await (openUrl?.call(update.releaseUri) ??
              launchUrl(
                update.releaseUri,
                mode: LaunchMode.externalApplication,
              ));
      if (!opened) throw StateError('No browser available');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载页面，请在浏览器访问项目的 GitHub Release')),
      );
    }
  }
}
