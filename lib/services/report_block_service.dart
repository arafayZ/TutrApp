import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class ReportBlockService {
  static bool get useRealApi => ApiConfig.useRealApi;

  // ============ HELPER METHODS ============

  static String _cleanErrorMessage(String message) {
    if (message.isEmpty) return 'Something went wrong';

    String cleaned = message
        .replaceFirst('Exception: ', '')
        .replaceAll('"', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('\\', '')
        .replaceAll('Λ', '')
        .replaceAll('OK', '')
        .trim();

    cleaned = cleaned.replaceFirst(RegExp(r'^[^a-zA-Z\s]+'), '').trim();

    if (cleaned.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(cleaned)) {
      return cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return 'Something went wrong';
  }

  static String _mapReportReason(String reason) {
    switch (reason.toLowerCase()) {
      case 'spam or fake account':
        return 'Spam_or_Fake_Account';
      case 'inappropriate messages':
        return 'Inappropriate_Messages';
      case 'harassment':
        return 'HARASSMENT';
      case 'wrong information':
        return 'Wrong_Information';
      case 'payment issues':
        return 'Payment_Issues';
      case 'other':
        return 'OTHER';
      default:
        return 'OTHER';
    }
  }

  // ============ BLOCKED TUTORS MANAGEMENT ============

  static Future<List<Map<String, dynamic>>> getBlockedTutors(int studentId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.getBlockedList}/$studentId/list');
        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load blocked tutors'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'tutorId': 1,
          'tutorName': 'Ahmed Khan',
          'tutorHeadline': 'Physics Expert',
          'tutorImage': null,
        },
        {
          'tutorId': 2,
          'tutorName': 'Sara Malik',
          'tutorHeadline': 'Math Instructor',
          'tutorImage': null,
        },
      ];
    }
  }

  static Future<bool> isTutorBlocked(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.checkBlocked}/$studentId/check/$tutorId');
        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final responseBody = response.body.trim();
          if (responseBody == 'true') {
            return true;
          } else if (responseBody == 'false') {
            return false;
          } else {
            try {
              final data = json.decode(responseBody);
              return data == true || data['blocked'] == true || data['isBlocked'] == true;
            } catch (e) {
              return false;
            }
          }
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      return false;
    }
  }

  static Future<Map<String, dynamic>> blockTutor(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.blockTutor}/$studentId/block/$tutorId');
        final response = await ApiClient.post(Uri.parse(url));

        if (response.statusCode == 200) {
          final responseBody = response.body.trim();
          if (responseBody == 'true') {
            return {'success': true, 'message': 'Tutor blocked successfully'};
          }
          try {
            final data = json.decode(responseBody);
            return {'success': true, 'message': data['message'] ?? 'Tutor blocked successfully'};
          } catch (e) {
            return {'success': true, 'message': 'Tutor blocked successfully'};
          }
        } else {
          String errorMsg = '';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? 'Failed to block tutor';
          } catch (e) {
            errorMsg = response.body.trim();
          }
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': 'Tutor blocked successfully'};
    }
  }

  static Future<Map<String, dynamic>> unblockTutor(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.unblockTutor}/$studentId/unblock/$tutorId');
        final response = await ApiClient.delete(Uri.parse(url));

        if (response.statusCode == 200) {
          final responseBody = response.body.trim();
          if (responseBody == 'true') {
            return {'success': true, 'message': 'Tutor unblocked successfully'};
          }
          try {
            final data = json.decode(responseBody);
            return {'success': true, 'message': data['message'] ?? 'Tutor unblocked successfully'};
          } catch (e) {
            return {'success': true, 'message': 'Tutor unblocked successfully'};
          }
        } else {
          String errorMsg = '';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? 'Failed to unblock tutor';
          } catch (e) {
            errorMsg = response.body.trim();
          }
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': 'Tutor unblocked successfully'};
    }
  }

  // ============ REPORT TUTOR ============

  static Future<Map<String, dynamic>> reportTutor({
    required int studentId,
    required int tutorId,
    required String reason,
    String? description,
  }) async {
    if (useRealApi) {
      try {
        String mappedReason = _mapReportReason(reason);

        final requestBody = {
          'studentId': studentId,
          'tutorId': tutorId,
          'reason': mappedReason,
          'description': description ?? '',
        };

        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.reportTutor)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final responseBody = response.body.trim();
          if (responseBody == 'true') {
            return {'success': true, 'message': 'Report submitted successfully'};
          }
          try {
            final data = json.decode(responseBody);
            return {'success': true, 'message': data['message'] ?? 'Report submitted successfully'};
          } catch (e) {
            return {'success': true, 'message': 'Report submitted successfully'};
          }
        } else {
          String errorMsg = '';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? 'Failed to report tutor';
          } catch (e) {
            errorMsg = response.body.trim();
          }
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': 'Report submitted successfully'};
    }
  }
}