import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/course_provider.dart';
import 'core/services/app_update_service.dart';
import 'ui/widgets/app_update_dialog.dart';
import 'core/theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/settings/settings_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CourseProvider())],
      child: const CourseBlockApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_checkAutomatically());
  });
}

Future<void> _checkAutomatically() async {
  final service = AppUpdateService.instance;
  try {
    final update = await service.checkForUpdate(automatic: true);
    if (update == null || !await service.isAutomaticCheckEnabled()) return;
    final context = appNavigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;
    await AppUpdateDialog.show(context, update);
  } catch (_) {
    // Background checks must not interrupt using the timetable while offline.
  }
}

class CourseBlockApp extends StatelessWidget {
  const CourseBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [routeObserver],
          title: '课程表',
          theme: buildAppTheme(provider.themeScheme, Brightness.light),
          darkTheme: buildAppTheme(provider.themeScheme, Brightness.dark),
          themeMode: provider.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
