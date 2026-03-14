import 'package:shared_preferences/shared_preferences.dart';

enum AcademicLoginSystem {
  undergraduate(storageKey: 'ug', label: '本科生教务'),
  graduate(storageKey: 'grad', label: '研究生教务');

  const AcademicLoginSystem({required this.storageKey, required this.label});

  final String storageKey;
  final String label;
}

AcademicLoginSystem? academicLoginSystemFromStorage(String? value) {
  for (final system in AcademicLoginSystem.values) {
    if (system.storageKey == value) {
      return system;
    }
  }
  return null;
}

class LoginSessionSummary {
  const LoginSessionSummary({
    required this.activeSystem,
    required this.systems,
    required this.userInfos,
  });

  final AcademicLoginSystem? activeSystem;
  final List<AcademicLoginSystem> systems;
  final Map<AcademicLoginSystem, String?> userInfos;

  bool get hasAnySession => systems.isNotEmpty;

  String? get displayText {
    if (systems.isEmpty) {
      return null;
    }

    if (systems.length == 1) {
      final system = systems.first;
      final userInfo = userInfos[system];
      if (userInfo == null || userInfo.trim().isEmpty) {
        return '${system.label}已登录';
      }
      return '${system.label} · $userInfo';
    }

    if (activeSystem != null) {
      return '已登录 ${systems.length} 个系统，当前使用${activeSystem!.label}';
    }

    return '已登录 ${systems.length} 个系统';
  }
}

class LoginSessionStorage {
  static const String _legacyCookiesKey = 'cookies';
  static const String _legacyUserInfoKey = 'user_info';
  static const String _activeLoginSystemKey = 'active_login_system';

  static String _cookiesKey(AcademicLoginSystem system) =>
      '${system.storageKey}_cookies';

  static String _userInfoKey(AcademicLoginSystem system) =>
      '${system.storageKey}_user_info';

  static Future<void> saveSession(
    AcademicLoginSystem system, {
    required String cookies,
    String? userInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookiesKey(system), cookies);
    if (userInfo != null && userInfo.trim().isNotEmpty) {
      await prefs.setString(_userInfoKey(system), userInfo.trim());
    } else {
      await prefs.remove(_userInfoKey(system));
    }
    await prefs.setString(_activeLoginSystemKey, system.storageKey);
  }

  static Future<String> loadCookies(AcademicLoginSystem system) async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getString(_cookiesKey(system));
    if (scoped != null && scoped.trim().isNotEmpty) {
      return scoped;
    }

    final active = academicLoginSystemFromStorage(
      prefs.getString(_activeLoginSystemKey),
    );
    if (active == system) {
      return prefs.getString(_legacyCookiesKey) ?? '';
    }

    if (active == null && system == AcademicLoginSystem.undergraduate) {
      return prefs.getString(_legacyCookiesKey) ?? '';
    }

    return '';
  }

  static Future<String?> loadUserInfo(AcademicLoginSystem system) async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getString(_userInfoKey(system));
    if (scoped != null && scoped.trim().isNotEmpty) {
      return scoped;
    }

    final active = academicLoginSystemFromStorage(
      prefs.getString(_activeLoginSystemKey),
    );
    if (active == system) {
      return prefs.getString(_legacyUserInfoKey);
    }

    if (active == null && system == AcademicLoginSystem.undergraduate) {
      return prefs.getString(_legacyUserInfoKey);
    }

    return null;
  }

  static Future<AcademicLoginSystem?> loadActiveSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = academicLoginSystemFromStorage(
      prefs.getString(_activeLoginSystemKey),
    );
    if (scoped != null) {
      return scoped;
    }

    final legacyCookies = prefs.getString(_legacyCookiesKey);
    if (legacyCookies != null && legacyCookies.trim().isNotEmpty) {
      return AcademicLoginSystem.undergraduate;
    }

    return null;
  }

  static Future<List<AcademicLoginSystem>> loadAvailableSystems() async {
    final available = <AcademicLoginSystem>[];
    for (final system in AcademicLoginSystem.values) {
      final cookies = await loadCookies(system);
      if (cookies.trim().isNotEmpty) {
        available.add(system);
      }
    }
    return available;
  }

  static Future<LoginSessionSummary> loadSummary() async {
    final systems = await loadAvailableSystems();
    final userInfos = <AcademicLoginSystem, String?>{};
    for (final system in systems) {
      userInfos[system] = await loadUserInfo(system);
    }

    final active = await loadActiveSystem();
    final resolvedActive = systems.contains(active) ? active : null;
    return LoginSessionSummary(
      activeSystem: resolvedActive,
      systems: systems,
      userInfos: userInfos,
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyCookiesKey);
    await prefs.remove(_legacyUserInfoKey);
    await prefs.remove(_activeLoginSystemKey);
    for (final system in AcademicLoginSystem.values) {
      await prefs.remove(_cookiesKey(system));
      await prefs.remove(_userInfoKey(system));
    }
  }
}
