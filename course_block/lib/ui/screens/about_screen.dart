import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/course_provider.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/course_settings_store.dart';
import '../../core/theme/app_theme.dart';
import '../settings/launcher_icon_dialog.dart';
import '../widgets/app_update_dialog.dart';

const _repoUrl = 'https://github.com/Labyrinth0419/SJTU-Course-Block';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.updateService, this.openReleaseUrl});

  final AppUpdateService? updateService;
  final Future<bool> Function(Uri)? openReleaseUrl;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appName = 'Course Block';
  String _version = '';
  String _buildNumber = '';
  int _versionTaps = 0;
  bool _unlocking = false;
  bool _checkingUpdates = false;

  AppUpdateService get _updateService =>
      widget.updateService ?? AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _appName = info.appName;
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    });
  }

  Future<void> _onVersionTap() async {
    final provider = context.read<CourseProvider>();
    if (provider.hiddenFeaturesUnlocked || _unlocking) return;
    _versionTaps++;
    if (_versionTaps < 7) return;
    _unlocking = true;
    try {
      await provider.updateAppSetting(
        CourseSettingsStore.hiddenFeaturesUnlockedKey,
        true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('似乎发生了什么变化')));
    } catch (_) {
      _versionTaps = 6;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开启隐藏功能失败，请重试')));
    } finally {
      _unlocking = false;
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final update = await _updateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _checkingUpdates = false);
      if (update == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前没有可用的新版本')));
      } else {
        await AppUpdateDialog.show(
          context,
          update,
          openUrl: widget.openReleaseUrl,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('检查更新失败，请检查网络后重试')));
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _setAutoUpdate(bool value) async {
    try {
      await context.read<CourseProvider>().updateAppSetting(
        CourseSettingsStore.autoUpdateEnabledKey,
        value,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存自动更新设置失败，请重试')));
    }
  }

  Future<void> _openRepo() async {
    await launchUrl(Uri.parse(_repoUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;
    final provider = context.watch<CourseProvider>();
    final versionText = _version.isEmpty
        ? '读取中'
        : _buildNumber.isEmpty
        ? 'v$_version'
        : 'v$_version ($_buildNumber)';

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
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
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '上海交通大学课程展示与导入工具',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          versionText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text('应用版本'),
                  subtitle: Text(versionText),
                  onTap: _onVersionTap,
                ),
                if (provider.hiddenFeaturesUnlocked) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.android_rounded),
                    title: const Text('更改启动器图标'),
                    subtitle: Text(
                      provider.launcherIcon == null
                          ? '当前使用默认图标'
                          : '当前使用 ${provider.launcherIcon}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLauncherIconDialog(context),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_rounded),
                  title: const Text('检查更新'),
                  subtitle: const Text('与 GitHub 最新正式 Release 比较'),
                  trailing: _checkingUpdates
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _checkingUpdates ? null : _checkForUpdates,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.update_rounded),
                  title: const Text('自动更新'),
                  subtitle: const Text('每天首次启动检查，下载安装需确认'),
                  value: provider.autoUpdateEnabled,
                  onChanged: _setAutoUpdate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.code_rounded,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: const Text('开源仓库'),
                  subtitle: const Text(
                    'GitHub / Labyrinth0419 / SJTU-Course-Block',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: _openRepo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Course Block 是一款面向上海交通大学同学的课表工具。你可以在这里同步课表、手动添加或编辑课程、查看每周安排，也可以按自己的习惯调整主题、颜色和显示方式。无论是日常看课、临时补课，还是整理一份更清晰、更顺手的个人课表，它都希望尽量帮你省掉重复操作。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
