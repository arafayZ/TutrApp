import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class AccountService {
  // ------------------------------------------------------------
  // Fetch account status: ACTIVE, INACTIVE, PENDING
  // ------------------------------------------------------------
  static Future<String> getAccountStatus(int userId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getAccountStatus}/$userId/status'),
      );

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
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deactivateTutor}/$tutorId/deactivate'),
      );

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
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.reactivateTutor}/$tutorId/reactivate'),
      );

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