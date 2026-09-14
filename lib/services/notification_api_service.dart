import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/notification_item.dart';

class NotificationApiService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ------------------------------------------------------------
  // LIST
  // ------------------------------------------------------------
  static Future<List<NotificationItem>> getUserNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getUserNotifications}/$userId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((e) => NotificationItem.fromJson(e)).toList();
  }

  // ------------------------------------------------------------
  // UNREAD COUNT
  // ------------------------------------------------------------
  static Future<int> getUnreadCount(int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getNotifUnreadCount}/$userId/unread-count'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return 0;
    final data = json.decode(response.body);
    return data['unreadCount'] ?? 0;
  }

  // ------------------------------------------------------------
  // MARK AS READ
  // ------------------------------------------------------------
  static Future<void> markAsRead(int id, int userId) async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.markNotifRead}/$id/read?userId=$userId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<void> markAllAsRead(int userId) async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.markAllNotifRead}/$userId/read-all'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------
  static Future<void> delete(int id, int userId) async {
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deleteNotif}/$id?userId=$userId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
  }
}