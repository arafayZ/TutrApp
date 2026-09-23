// lib/services/student_report_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_client.dart';

class StudentReportService {

  // ============================================================
  // CREATE REPORT (tutor → student)
  // ============================================================
  static Future<Map<String, dynamic>> createReport({
    required int tutorId,
    required int studentId,
    required String reason,
    required String description,
    int? connectionId,
    List<String> evidenceUrls = const [],
  }) async {
    final body = {
      'studentId': studentId,
      'connectionId': connectionId,
      'reason': reason,
      'description': description,
      'evidenceUrls': evidenceUrls,
    };

    // ✅ Uses ApiConfig constant
    final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
      ApiConfig.createStudentReport,
      {'tutorId': tutorId.toString()},
    ));

    final res = await ApiClient.post(
      uri,
      body: json.encode(body),
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return {'success': true, 'id': data['id']};
    } else {
      final err = json.decode(res.body);
      throw Exception(err['error'] ?? 'Failed to submit report');
    }
  }

  // ============================================================
  // UPLOAD EVIDENCE
  // ============================================================
  static Future<String> uploadEvidence(File image, int tutorId) async {
    // ✅ Uses ApiConfig constant
    final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
      ApiConfig.uploadStudentReportEvidence,
      {'tutorId': tutorId.toString()},
    ));

    final req = http.MultipartRequest('POST', uri);
    req.files.add(await http.MultipartFile.fromPath('file', image.path));

    final res = await ApiClient.sendMultipart(req);
    if (res.statusCode == 200) {
      return json.decode(res.body)['url'];
    }
    throw Exception('Evidence upload failed');
  }

  // ============================================================
  // GET MY REPORTS (tutor's submitted reports)
  // ============================================================
  static Future<List<Map<String, dynamic>>> getMyReports(int tutorId) async {
    // ✅ Uses ApiConfig constant
    final uri = Uri.parse(ApiConfig.getFullUrlWithParams(
      ApiConfig.getMyStudentReports,
      {'tutorId': tutorId.toString()},
    ));

    final res = await ApiClient.get(uri);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load reports');
  }
}