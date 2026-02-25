// lib/ui/login/webview_login_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart'
    as cookie_mgr;

class WebviewLoginScreen extends StatefulWidget {
  final String initialUrl;
  final String title;

  const WebviewLoginScreen({
    super.key,
    required this.initialUrl,
    required this.title,
  });

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
        "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/89.0.4389.72",
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            if (uri.scheme == 'jaccount') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });

            // Check if login successful
            // Undergraduate: i.sjtu.edu.cn/xtgl/index_initMenu.html or xskbcx_cxXskbcxIndex.html
            // Graduate: yjs.sjtu.edu.cn/...
            if (url.contains('index_initMenu.html') ||
                url.contains('wdkb') ||
                url.contains('main.html') ||
                url.contains('xskbcx_cxXskbcxIndex.html')) {
              try {
                // Use cookie_manager to get all cookies including HttpOnly
                final cookieManager = cookie_mgr.WebviewCookieManager();
                final cookies = await cookieManager.getCookies(url);

                if (cookies.isNotEmpty) {
                  // Format cookies for Dio: "name=value; name2=value2"
                  final cookieString = cookies
                      .map((c) => '${c.name}=${c.value}')
                      .join('; ');

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('cookies', cookieString);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('登录成功，Cookie已保存')),
                    );
                    // Navigate back with success
                    if (mounted) Navigator.pop(context, true);
                  }
                }
              } catch (e) {
                debugPrint('Error getting cookies: $e');
              }
            }
          },
        ),
      );

    // Clear cookies before loading to ensure a fresh login session
    cookie_mgr.WebviewCookieManager().clearCookies().then((_) {
      _controller.loadRequest(Uri.parse(widget.initialUrl));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
