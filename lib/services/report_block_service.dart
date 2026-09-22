import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_client.dart';

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
      return [];
    }
  }

  static Future<bool> isTutorBlocked(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.checkBlocked}/$studentId/check/$tutorId');
        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final responseBody = response.body.trim();
          if (responseBody == 'true') return true;
          if (responseBody == 'false') return false;
          try {
            final data = json.decode(responseBody);
            return data == true || data['blocked'] == true || data['isBlocked'] == true;
          } catch (e) {
            return false;
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> blockTutor(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.blockTutor}/$studentId/block/$tutorId');
        final response = await ApiClient.post(Uri.parse(url));

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'Tutor blocked successfully'};
        } else {
          String errorMsg = 'Failed to block tutor';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? errorMsg;
          } catch (_) {}
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    }
    return {'success': true, 'message': 'Tutor blocked successfully'};
  }

  static Future<Map<String, dynamic>> unblockTutor(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.unblockTutor}/$studentId/unblock/$tutorId');
        final response = await ApiClient.delete(Uri.parse(url));

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'Tutor unblocked successfully'};
        } else {
          String errorMsg = 'Failed to unblock tutor';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? errorMsg;
          } catch (_) {}
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    }
    return {'success': true, 'message': 'Tutor unblocked successfully'};
  }

  // ============ REPORT TUTOR (NEW FLOW) ============

  /// Submit a report to the backend
  static Future<Map<String, dynamic>> createReport({
    required int studentId,
    required int tutorId,
    required String reason,        // enum name, e.g. "HARASSMENT"
    required String description,
    int? connectionId,
    List<String> evidenceUrls = const [],
  }) async {
    if (!useRealApi) {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'message': 'Report submitted successfully'};
    }

    try {
      final requestBody = {
        'tutorId': tutorId,
        'connectionId': connectionId,
        'reason': reason,
        'description': description,
        'evidenceUrls': evidenceUrls,
      };

      // ✅ Uses ApiConfig constant + getFullUrlWithParams helper
      final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
        ApiConfig.createReport,
        {'studentId': studentId.toString()},
      ));

      final response = await ApiClient.post(
        uri,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'id': data['id'],
          'message': 'Report submitted successfully',
        };
      } else {
        String errorMsg = 'Failed to submit report';
        try {
          final err = json.decode(response.body);
          errorMsg = err['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(_cleanErrorMessage(errorMsg));
      }
    } catch (e) {
      throw Exception(_cleanErrorMessage(e.toString()));
    }
  }

  /// Upload a single evidence image. Returns the stored URL path.
  static Future<String> uploadReportEvidence(File image, int studentId) async {
    if (!useRealApi) {
      await Future.delayed(const Duration(milliseconds: 500));
      return '/uploads/report-evidence/mock.jpg';
    }

    try {
      // ✅ Uses ApiConfig constant
      final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
        ApiConfig.uploadReportEvidence,
        {'studentId': studentId.toString()},
      ));

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await ApiClient.sendMultipart(request);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      } else {
        throw Exception('Evidence upload failed');
      }
    } catch (e) {
      throw Exception(_cleanErrorMessage(e.toString()));
    }
  }

  /// Get the student's own submitted reports
  static Future<List<Map<String, dynamic>>> getMyReports(int studentId) async {
    if (!useRealApi) {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }

    try {
      //  Uses ApiConfig constant
      final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
        ApiConfig.getMyReports,
        {'studentId': studentId.toString()},
      ));

      final response = await ApiClient.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load reports');
      }
    } catch (e) {
      throw Exception(_cleanErrorMessage(e.toString()));
    }
  }
}