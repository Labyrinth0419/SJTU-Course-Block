import 'dart:async';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version.dart';
import 'course_settings_store.dart';

class ReleaseUpdate {
  const ReleaseUpdate({
    required this.currentVersion,
    required this.version,
    required this.releaseUri,
    this.notes = '',
  });

  final String currentVersion;
  final String version;
  final Uri releaseUri;
  final String notes;
}

class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    Future<String> Function()? currentVersion,
    DateTime Function()? now,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _dio = dio ?? Dio(),
       _currentVersion = currentVersion ?? _installedVersion,
       _now = now ?? DateTime.now,
       _requestTimeout = requestTimeout {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.sendTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  static final instance = AppUpdateService();
  static const repositoryUrl =
      'https://github.com/Labyrinth0419/SJTU-Course-Block';
  static const latestReleaseApi =
      'https://api.github.com/repos/Labyrinth0419/SJTU-Course-Block/releases/latest';
  static const lastCheckDateKey = 'app_update_last_check_date';

  final Dio _dio;
  final Future<String> Function() _currentVersion;
  final DateTime Function() _now;
  final Duration _requestTimeout;
  Future<ReleaseUpdate?>? _pending;

  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<bool> isAutomaticCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(CourseSettingsStore.autoUpdateEnabledKey) != false;
  }

  Future<ReleaseUpdate?> checkForUpdate({bool automatic = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = _now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (automatic &&
        (prefs.get(CourseSettingsStore.autoUpdateEnabledKey) == false ||
            prefs.get(lastCheckDateKey) == date)) {
      return null;
    }

    final pending = _pending ??= _fetchUpdate().then((update) async {
      // Failed/offline checks must not prevent another attempt later today.
      await prefs.setString(lastCheckDateKey, date);
      return update;
    });
    try {
      return await pending;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  Future<ReleaseUpdate?> _fetchUpdate() async {
    final current = await _currentVersion();
    final currentVersion = AppVersion.parse(current);
    final cancelToken = CancelToken();
    final response = await _dio
        .get<dynamic>(
          latestReleaseApi,
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'CourseBlockUpdater',
            },
            validateStatus: (status) => status == 200 || status == 404,
          ),
        )
        .timeout(
          _requestTimeout,
          onTimeout: () {
            cancelToken.cancel('Update check deadline reached');
            throw TimeoutException('Update check timed out');
          },
        );
    if (response.statusCode == 404) return null;
    final data = response.data;
    if (data is! Map || data['tag_name'] is! String) {
      throw FormatException('Invalid release response');
    }
    if (data['draft'] == true || data['prerelease'] == true) return null;
    final tag = (data['tag_name'] as String).trim();
    final latestVersion = AppVersion.parse(tag);
    if (latestVersion.prerelease.isNotEmpty ||
        latestVersion.compareTo(currentVersion) <= 0) {
      return null;
    }

    final releaseUri = Uri.parse(
      data['html_url'] is String
          ? data['html_url'] as String
          : '$repositoryUrl/releases/latest',
    );
    if (releaseUri.scheme != 'https' ||
        releaseUri.host != 'github.com' ||
        releaseUri.userInfo.isNotEmpty ||
        releaseUri.port != 443 ||
        !releaseUri.path.startsWith(
          '/Labyrinth0419/SJTU-Course-Block/releases/',
        )) {
      throw FormatException('Untrusted release URL');
    }
    final body = data['body'] is String ? data['body'] as String : '';
    return ReleaseUpdate(
      currentVersion: current,
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      releaseUri: releaseUri,
      notes: body.length > 3000 ? '${body.substring(0, 3000)}…' : body,
    );
  }
}
