import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AccountService {
  // ------------------------------------------------------------
  // Fetch account status: ACTIVE, INACTIVE, PENDING
  // ------------------------------------------------------------
  static Future<String> getAccountStatus(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getAccountStatus}/$userId/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['status'] ?? 'UNKNOWN').toString().toUpperCase();
      } else {
        throw Exception('Failed to fetch account status');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ------------------------------------------------------------
  // Deactivate tutor account
  // ------------------------------------------------------------
  static Future<Map<String, dynamic>> deactivateTutor(int tutorId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deactivateTutor}/$tutorId/deactivate'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Account deactivated',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to deactivate',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  // ------------------------------------------------------------
  // Reactivate tutor account
  // ------------------------------------------------------------
  static Future<Map<String, dynamic>> reactivateTutor(int tutorId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.reactivateTutor}/$tutorId/reactivate'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Account reactivated',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to reactivate',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}