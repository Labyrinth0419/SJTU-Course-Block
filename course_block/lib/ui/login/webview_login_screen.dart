import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart'
    as cookie_mgr;
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/login_session.dart';
import '../../core/theme/app_theme.dart';

class WebviewLoginScreen extends StatefulWidget {
  const WebviewLoginScreen({
    super.key,
    required this.initialUrl,
    required this.loginSystem,
    required this.title,
  });

  final String initialUrl;
  final AcademicLoginSystem loginSystem;
  final String title;

  @override
  State<WebviewLoginScreen> createState() => _WebviewLoginScreenState();
}

class _WebviewLoginScreenState extends State<WebviewLoginScreen> {
  static const String _graduateCookieUrl = 'https://yjs.sjtu.edu.cn/gsapp/';
  static const String _graduateCurrentTermUrl =
      'https://yjsxk.sjtu.edu.cn/yjsxkapp/sys/xsxkapp/xsxkHome/loadPublicInfo_index.do';
  static const String _graduateCourseQueryUrl =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';
  static const String _graduateReferer =
      'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/*default/index.do?THEME=indigo&EMAP_LANG=zh#/xskcb';

  late final WebViewController _controller;
  final Dio _dio = Dio();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _didSave = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/89.0.4389.72',
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            if (uri.scheme == 'jaccount') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _isLoading = false);

            if (_didSave || _isSaving) {
              return;
            }

            if (widget.loginSystem == AcademicLoginSystem.undergraduate &&
                (url.contains('index_initMenu.html') ||
                    url.contains('main.html') ||
                    url.contains('xskbcx_cxXskbcxIndex.html'))) {
              await _trySaveUndergraduateCookies(url);
            }

            if (widget.loginSystem == AcademicLoginSystem.graduate) {
              final uri = Uri.tryParse(url);
              if (uri?.host == 'yjs.sjtu.edu.cn') {
                await _trySaveGraduateCookies();
              }
            }
          },
        ),
      );

    cookie_mgr.WebviewCookieManager().clearCookies().then((_) {
      _controller.loadRequest(Uri.parse(widget.initialUrl));
    });
  }

  Future<void> _trySaveUndergraduateCookies(String url) async {
    try {
      _isSaving = true;
      final cookieManager = cookie_mgr.WebviewCookieManager();
      final cookies = await cookieManager.getCookies(url);

      if (cookies.isEmpty) return;

      final cookieString = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');

      String? display;
      for (final cookie in cookies) {
        final name = cookie.name.toLowerCase();
        if (name.contains('user') ||
            name.contains('uid') ||
            name.contains('jaccount')) {
          display = cookie.value;
          break;
        }
      }
      display ??= '已登录';
      await LoginSessionStorage.saveSession(
        AcademicLoginSystem.undergraduate,
        cookies: cookieString,
        userInfo: display,
      );

      if (!mounted) return;
      _didSave = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录成功，已保存登录信息')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error getting cookies: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _trySaveGraduateCookies() async {
    try {
      _isSaving = true;
      final cookieManager = cookie_mgr.WebviewCookieManager();
      final cookies = await cookieManager.getCookies(_graduateCookieUrl);

      if (cookies.isEmpty) {
        return;
      }

      final cookieString = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      final userInfo = await _validateGraduateLogin(cookieString);
      if (userInfo == null || userInfo.trim().isEmpty) {
        return;
      }

      await LoginSessionStorage.saveSession(
        AcademicLoginSystem.graduate,
        cookies: cookieString,
        userInfo: userInfo,
      );

      if (!mounted) return;
      _didSave = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('研究生登录成功，已保存登录信息')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error validating graduate login: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<String?> _validateGraduateLogin(String cookies) async {
    final currentTerm = await _loadGraduateCurrentTerm();
    if (currentTerm == null) {
      return null;
    }

    final response = await _dio.post<dynamic>(
      '$_graduateCourseQueryUrl?_=${DateTime.now().millisecondsSinceEpoch}',
      data: {
        'XNXQDM': currentTerm,
        'XH': '',
        'pageNumber': '1',
        'pageSize': '1',
      },
      options: Options(
        headers: {
          'Cookie': cookies,
          'Referer': _graduateReferer,
          'Origin': 'https://yjs.sjtu.edu.cn',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        followRedirects: false,
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = response.data;
    Map<String, dynamic>? json;
    if (data is Map<String, dynamic>) {
      json = data;
    } else if (data is String) {
      json = _tryDecodeJson(data);
    }
    if (json == null) {
      return null;
    }

    final code = json['code']?.toString();
    if (code != '0') {
      return null;
    }

    final datas = json['datas'];
    if (datas is! Map<String, dynamic>) {
      return null;
    }

    final result = datas['xsjxrwcx'];
    if (result is! Map<String, dynamic>) {
      return null;
    }

    final rows = result['rows'];
    if (rows is List) {
      for (final item in rows) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final studentId = item['XH']?.toString();
        final school = item['KKDW_DISPLAY']?.toString();
        if (studentId != null && studentId.trim().isNotEmpty) {
          if (school != null && school.trim().isNotEmpty) {
            return '$studentId · $school';
          }
          return studentId;
        }
      }
    }

    return '已登录';
  }

  Future<String?> _loadGraduateCurrentTerm() async {
    final response = await _dio.get<dynamic>(
      _graduateCurrentTermUrl,
      options: Options(responseType: ResponseType.plain),
    );
    if (response.statusCode != 200) {
      return null;
    }

    final data = response.data;
    Map<String, dynamic>? json;
    if (data is Map<String, dynamic>) {
      json = data;
    } else if (data is String) {
      json = _tryDecodeJson(data);
    }
    final lcxx = json?['lcxx'];
    if (lcxx is! Map<String, dynamic>) {
      return null;
    }
    final code = lcxx['XNXQDM']?.toString();
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    return code.trim();
  }

  Map<String, dynamic>? _tryDecodeJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.aboutGradientStart,
                                palette.aboutGradientEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '正在打开登录页面',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '登录成功后会自动返回。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: _isLoading ? null : 1,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isLoading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.72,
                            ),
                            child: Center(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 12),
                                      Text(
                                        '加载中',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
