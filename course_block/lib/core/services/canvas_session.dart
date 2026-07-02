import 'package:shared_preferences/shared_preferences.dart';

/// Canvas（oc.sjtu.edu.cn）会话存储。
///
/// 与教务系统 [AcademicLoginSystem]/[LoginSessionStorage] 完全独立——课程同步会
/// 遍历 [AcademicLoginSystem.values] 决定从哪些系统拉课表，Canvas 绝不能混进那个
/// 枚举，否则会污染课程同步。这里用固定的独立键持久化 Canvas 的 API token。
///
/// 登录后创建的是长期有效的 Canvas access token（Bearer），而不是易过期的会话
/// Cookie，因此这里只存 token 明文、token id（用于注销时撤销）和展示用户名。
class CanvasSessionStorage {
  static const String _tokenKey = 'canvas_api_token';
  static const String _tokenIdKey = 'canvas_token_id';
  static const String _userInfoKey = 'canvas_user_info';

  static Future<void> saveSession({
    required String token,
    String? tokenId,
    String? userInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (tokenId != null && tokenId.trim().isNotEmpty) {
      await prefs.setString(_tokenIdKey, tokenId.trim());
    } else {
      await prefs.remove(_tokenIdKey);
    }
    if (userInfo != null && userInfo.trim().isNotEmpty) {
      await prefs.setString(_userInfoKey, userInfo.trim());
    } else {
      await prefs.remove(_userInfoKey);
    }
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token;
  }

  static Future<String?> loadTokenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenIdKey);
  }

  static Future<String?> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userInfoKey);
  }

  static Future<bool> hasSession() async {
    final token = await loadToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenIdKey);
    await prefs.remove(_userInfoKey);
  }
}
