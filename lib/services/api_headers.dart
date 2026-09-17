import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_app/services/session_expired_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // 👈 for forceLogout

class ApiHeaders {
  static const String _tokenKey = 'auth_token';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, String>> json() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> publicJson() => {
    'Content-Type': 'application/json',
  };

  static Future<void> addToMultipart(http.MultipartRequest request) async {
    final token = await _token();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
  }
}

/// 👇 Global response handler — call this after every HTTP request
class ApiResponse {
  /// Handles 401/403 → forceLogout + throws SessionExpiredException.
  /// Returns parsed JSON body if 200/2xx.
  static Future<dynamic> check(http.Response response) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      await forceLogout();
      throw SessionExpiredException();
    }

    if (response.statusCode >= 400) {
      throw Exception(
        response.body.isNotEmpty ? response.body : 'Request failed',
      );
    }

    if (response.body.isEmpty) return null;
    return json.decode(response.body);
  }
}