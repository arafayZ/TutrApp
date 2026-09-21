import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:my_first_app/services/session_expired_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // for forceLogout

/// Central HTTP client that:
/// - Automatically adds the JWT `Authorization` header (if token exists)
/// - Detects 401/403 responses and forces logout to login screen
/// - Returns the raw http.Response for services to parse
class ApiClient {
  static const String _tokenKey = 'auth_token';

  // ------------------------------------------------------------
  // INTERNAL HELPERS
  // ------------------------------------------------------------

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, String>> _authJsonHeaders() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Public headers — no auth (login / signup / OTP)
  static Map<String, String> publicJsonHeaders() => {
    'Content-Type': 'application/json',
  };

  /// Called after every authenticated response.
  /// If 401/403 → clears token, redirects to login, throws SessionExpiredException.
  static Future<http.Response> _check(http.Response response) async {
    // ---- 401: always session expired ----
    if (response.statusCode == 401) {
      final token = await _token();
      if (token != null && token.isNotEmpty) {
        await forceLogout(reason: 'Session expired. Please log in again.');
        throw SessionExpiredException();
      }
    }

    // ---- 403: only force logout if it's a SUSPENSION ----
    if (response.statusCode == 403) {
      final token = await _token();
      if (token != null && token.isNotEmpty) {
        bool isSuspended = false;

        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] == 'ACCOUNT_SUSPENDED') {
            isSuspended = true;
          }
        } catch (_) {
          // Not JSON → treat as a normal permission error, don't logout
        }

        if (isSuspended) {
          await forceLogout(
            reason: 'Your account has been suspended. '
                'Please contact support at tutr.verify@gmail.com',
          );
          throw SessionExpiredException();
        }
        // ✅ NOT suspended → return 403 to caller (chat permission errors etc.)
      }
    }

    // 404 / 200 / 400 / 500 → return as-is
    return response;
  }

  // ------------------------------------------------------------
  // AUTHENTICATED JSON REQUESTS
  // ------------------------------------------------------------

  static Future<http.Response> get(
      Uri url, {
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final res = await http.get(url, headers: await _authJsonHeaders()).timeout(timeout);
    return _check(res);
  }

  static Future<http.Response> post(
      Uri url, {
        Object? body,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final res = await http
        .post(url, headers: await _authJsonHeaders(), body: body)
        .timeout(timeout);
    return _check(res);
  }

  static Future<http.Response> put(
      Uri url, {
        Object? body,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final res = await http
        .put(url, headers: await _authJsonHeaders(), body: body)
        .timeout(timeout);
    return _check(res);
  }

  static Future<http.Response> patch(
      Uri url, {
        Object? body,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final res = await http
        .patch(url, headers: await _authJsonHeaders(), body: body)
        .timeout(timeout);
    return _check(res);
  }

  static Future<http.Response> delete(
      Uri url, {
        Object? body,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final res = await http
        .delete(url, headers: await _authJsonHeaders(), body: body)
        .timeout(timeout);
    return _check(res);
  }

  // ------------------------------------------------------------
  // PUBLIC REQUESTS (no auth — for signup flow)
  // ------------------------------------------------------------

  static Future<http.Response> publicGet(
      Uri url, {
        Duration timeout = const Duration(seconds: 15),
      }) async {
    return await http.get(url, headers: publicJsonHeaders()).timeout(timeout);
  }

  static Future<http.Response> publicPost(
      Uri url, {
        Object? body,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    return await http
        .post(url, headers: publicJsonHeaders(), body: body)
        .timeout(timeout);
  }

  // ------------------------------------------------------------
  // MULTIPART (file / image uploads)
  // ------------------------------------------------------------

  /// Sends a multipart request with auth.
  /// Throws SessionExpiredException on 401/403.
  static Future<http.Response> sendMultipart(
      http.MultipartRequest request, {
        Duration timeout = const Duration(seconds: 60),
      }) async {
    final token = await _token();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    // Use the same smart check as JSON requests
    return _check(response);
  }
}