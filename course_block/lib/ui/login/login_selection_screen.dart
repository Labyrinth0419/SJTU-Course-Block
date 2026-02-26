import 'package:flutter/material.dart';
import 'webview_login_screen.dart';

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择登录方式')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebviewLoginScreen(
                      initialUrl: 'https://i.sjtu.edu.cn/jaccountlogin',
                      title: '本科生登录',
                    ),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('本科生教务系统登录'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WebviewLoginScreen(
                      initialUrl:
                          'https://yjs.sjtu.edu.cn/gsapp/sys/wdkbapp/modules/wdkb/1566868668786.shtml', // Approximation, user can navigate
                      title: '研究生教务系统登录',
                    ),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('研究生教务系统登录'),
            ),
          ],
        ),
      ),
    );
  }
}
