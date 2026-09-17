import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class DashboardService {
  static bool get useRealApi => ApiConfig.useRealApi;

  // ============ HELPER METHODS ============

  static String _cleanErrorMessage(String message) {
    String cleaned = message
        .replaceFirst('Exception: ', '')
        .replaceAll('"', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('\\', '')
        .trim();
    return cleaned.isEmpty ? 'Something went wrong' : cleaned;
  }

  // ============ TUTOR DASHBOARD ============
  // Fetches dashboard data for tutor including active students, courses, and top courses

  static Future<Map<String, dynamic>> getTutorDashboard(int tutorId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.tutorDashboard}/$tutorId')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load dashboard'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'tutorId': tutorId,
        'tutorName': 'John Doe',
        'tutorImage': null,
        'totalActiveStudents': 15,
        'totalActiveCourses': 5,
        'topCourses': [
          {
            'courseId': 1,
            'subject': 'Mathematics',
            'averageRating': 4.8,
            'totalStudents': 8,
            'rank': 1
          },
          {
            'courseId': 2,
            'subject': 'Physics',
            'averageRating': 4.5,
            'totalStudents': 5,
            'rank': 2
          },
        ],
      };
    }
  }

  // ============ STUDENT DASHBOARD ============
  // Fetches dashboard data for student including top tutors and recommended courses

  static Future<Map<String, dynamic>> getStudentDashboard(int studentId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.studentDashboard}/$studentId');

        final response = await ApiClient.get(Uri.parse(url)); // 👈 switched to ApiClient

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load dashboard'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'studentId': 1,
        'studentName': 'Emaz Ali Khan',
        'studentImage': '',
        'topTutors': [
          {
            'tutorId': 1,
            'tutorName': 'Sana Khan',
            'averageRating': 4.9,
            'location': 'Karachi',
            'topSubjects': ['Mathematics'],
            'tutorImage': null,
          },
        ],
        'recommendedCourses': [
          {
            'courseId': 1,
            'tutorName': 'Asim Ali Khan',
            'subject': 'Mathematics',
            'category': 'MATRIC',
            'price': 1800,
            'averageRating': 4.2,
            'teachingMode': 'ONLINE',
            'location': 'Online',
          },
        ],
      };
    }
  }
}