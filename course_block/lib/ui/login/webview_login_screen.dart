import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart'
    as cookie_mgr;
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

class WebviewLoginScreen extends StatefulWidget {
  const WebviewLoginScreen({
    super.key,
    required this.initialUrl,
    required this.title,
  });

  final String initialUrl;
  final String title;

  @override
  State<WebviewLoginScreen> createState() => _WebviewLoginScreenState();
}

class _WebviewLoginScreenState extends State<WebviewLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

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

            if (url.contains('index_initMenu.html') ||
                url.contains('wdkb') ||
                url.contains('main.html') ||
                url.contains('xskbcx_cxXskbcxIndex.html')) {
              await _trySaveCookies(url);
            }
          },
        ),
      );

    cookie_mgr.WebviewCookieManager().clearCookies().then((_) {
      _controller.loadRequest(Uri.parse(widget.initialUrl));
    });
  }

  Future<void> _trySaveCookies(String url) async {
    try {
      final cookieManager = cookie_mgr.WebviewCookieManager();
      final cookies = await cookieManager.getCookies(url);

      if (cookies.isEmpty) return;

      final cookieString = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cookies', cookieString);

      String? display;
      for (final cookie in cookies) {
        final name = cookie.name.toLowerCase();
        if (name.contains('user') ||
            name.contains('uid') ||
            name.contains('jaccount')) {
          display = '${cookie.name}=${cookie.value}';
          break;
        }
      }
      display ??= cookies.first.name;
      await prefs.setString('user_info', display);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录成功，Cookie 已保存')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error getting cookies: $e');
    }
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
                                '登录成功后会自动返回并保存凭据。',
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
