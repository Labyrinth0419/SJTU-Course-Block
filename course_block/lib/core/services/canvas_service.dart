import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/canvas_todo.dart';
import 'canvas_session.dart';

/// 需要登录 Canvas 时抛出，UI 据此引导用户去登录。
class CanvasLoginRequiredException implements Exception {
  const CanvasLoginRequiredException([
    this.message = '请先登录 Canvas（oc.sjtu.edu.cn）',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// 创建 Canvas access token 的结果。
class CanvasTokenResult {
  const CanvasTokenResult({
    required this.token,
    this.tokenId,
    this.userInfo,
  });

  /// 明文 token，仅在创建时返回一次。
  final String token;

  /// token 的数据库 id，用于日后 DELETE 撤销。
  final String? tokenId;

  /// 展示用户名。
  final String? userInfo;
}

/// 访问 Canvas LMS（oc.sjtu.edu.cn）的服务。
///
/// 登录流程：WebView 完成 jAccount 登录后，用会话 Cookie 调用 [createToken]
/// 创建一个长期有效的 access token；此后 [fetchTodos] 等请求一律用
/// `Authorization: Bearer <token>`，不再依赖易过期的 Cookie。
class CanvasService {
  static const String _baseUrl = 'https://oc.sjtu.edu.cn';
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final Dio _dio = Dio();

  /// 用会话 Cookie 创建一个 Canvas access token。
  ///
  /// Cookie 认证下的写请求需要 CSRF：从 Cookie 里取 `_csrf_token`，URL-decode 后
  /// 放到请求头 `X-CSRF-Token`（与 Canvas 前端做法一致）。成功返回明文 token +
  /// token id；失败返回 null。
  Future<CanvasTokenResult?> createToken(String cookies) async {
    if (cookies.trim().isEmpty) {
      return null;
    }

    final csrfToken = _extractCsrfToken(cookies);

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/api/v1/users/self/tokens',
        data: {'token[purpose]': 'SJTU CourseBlock 待办'},
        options: Options(
          headers: {
            'Cookie': cookies,
            'X-CSRF-Token': ?csrfToken,
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          'Canvas createToken failed: ${response.statusCode} ${response.data}',
        );
        return null;
      }

      final json = _decodeJsonMap(response.data);
      final token = _asString(json?['token']);
      if (token == null) {
        debugPrint('Canvas createToken response missing token: ${json?.keys}');
        return null;
      }

      final userInfo = await _fetchUserName(token);

      return CanvasTokenResult(
        token: token,
        tokenId: _asString(json?['id']),
        userInfo: userInfo,
      );
    } catch (e) {
      debugPrint('Error creating Canvas token: $e');
      return null;
    }
  }

  /// 拉取待办列表（Bearer 认证）。未登录抛 [CanvasLoginRequiredException]。
  Future<List<CanvasTodo>> fetchTodos() async {
    final token = await CanvasSessionStorage.loadToken();
    if (token == null || token.trim().isEmpty) {
      throw const CanvasLoginRequiredException();
    }

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));
    final end = now.add(const Duration(days: 60));

    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/api/v1/planner/items',
        queryParameters: {
          'start_date': _formatDate(start),
          'end_date': _formatDate(end),
          'filter': 'incomplete_items',
          'per_page': '100',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw const CanvasLoginRequiredException('Canvas 登录已失效，请重新登录');
      }
      if (status != 200) {
        debugPrint('Canvas fetchTodos failed: $status');
        return const [];
      }

      final list = _decodeJsonList(response.data);
      final todos = list
          .map((item) => CanvasTodo.fromPlannerItem(item, baseUrl: _baseUrl))
          .whereType<CanvasTodo>()
          .toList();

      // 按截止时间升序，无截止时间的排末尾。
      todos.sort((a, b) {
        if (a.dueAt == null && b.dueAt == null) return 0;
        if (a.dueAt == null) return 1;
        if (b.dueAt == null) return -1;
        return a.dueAt!.compareTo(b.dueAt!);
      });
      return todos;
    } on CanvasLoginRequiredException {
      rethrow;
    } catch (e) {
      debugPrint('Error fetching Canvas todos: $e');
      return const [];
    }
  }

  /// 注销时撤销服务端 token（best-effort，失败静默）。
  Future<void> deleteToken(String token, String tokenId) async {
    if (token.trim().isEmpty || tokenId.trim().isEmpty) {
      return;
    }
    try {
      await _dio.delete<dynamic>(
        '$_baseUrl/api/v1/users/self/tokens/$tokenId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting Canvas token: $e');
    }
  }

  Future<String?> _fetchUserName(String token) async {
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/api/v1/users/self',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final json = _decodeJsonMap(response.data);
      return _asString(json?['name']) ?? _asString(json?['short_name']);
    } catch (e) {
      debugPrint('Error fetching Canvas user: $e');
      return null;
    }
  }

  /// 从 Cookie 串里取 `_csrf_token` 并 URL-decode。
  String? _extractCsrfToken(String cookies) {
    for (final part in cookies.split(';')) {
      final trimmed = part.trim();
      const key = '_csrf_token=';
      if (trimmed.startsWith(key)) {
        final raw = trimmed.substring(key.length);
        try {
          return Uri.decodeComponent(raw);
        } catch (_) {
          return raw;
        }
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// 剥掉 Canvas 防 JSON 劫持的 `while(1);` 前缀后解析为 Map。
  Map<String, dynamic>? _decodeJsonMap(dynamic data) {
    final decoded = _decodeJson(data);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// 同上，解析为对象列表。
  List<Map<String, dynamic>> _decodeJsonList(dynamic data) {
    final decoded = _decodeJson(data);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  dynamic _decodeJson(dynamic data) {
    if (data is Map || data is List) {
      return data;
    }
    if (data is String) {
      var text = data.trimLeft();
      if (text.startsWith('while(1);')) {
        text = text.substring('while(1);'.length);
      }
      try {
        return jsonDecode(text);
      } catch (_) {}
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
