import 'dart:convert';
import '../config/api_config.dart';
import '../utils/api_mapper.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class ConnectionService {
  static bool get useRealApi => ApiConfig.useRealApi;

  // ============ HELPER METHODS ============

  static String _cleanErrorMessage(String message) {
    String cleaned = message;

    cleaned = cleaned.replaceFirst('Exception: ', '');
    cleaned = cleaned.replaceFirst('FormatUnexpected character (at character 1)\n', '');
    cleaned = cleaned.replaceFirst('FormatUnexpected character (at character 1)', '');

    cleaned = cleaned.replaceAll('"', '');
    cleaned = cleaned.replaceAll('{', '');
    cleaned = cleaned.replaceAll('}', '');
    cleaned = cleaned.replaceAll('[', '');
    cleaned = cleaned.replaceAll(']', '');
    cleaned = cleaned.replaceAll('\\', '');
    cleaned = cleaned.replaceAll('Λ', '');
    cleaned = cleaned.replaceAll('^', '');
    cleaned = cleaned.replaceAll('\n', ' ');

    cleaned = cleaned.replaceAll(' OK', '');
    cleaned = cleaned.replaceAll(' A ', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\bA\b'), '');

    cleaned = cleaned.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) {
      return 'Something went wrong';
    }

    return cleaned;
  }

  // ============ TUTOR CONNECTION APIS ============

  static Future<List<Map<String, dynamic>>> getTutorConnections(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorConnections)}/$tutorProfileId'),
        );

        if (response.statusCode == 200) {
          List<dynamic> connections = json.decode(response.body);
          return connections.map((conn) => ApiMapper.mapConnectionResponse(conn)).toList();
        } else {
          throw Exception('Failed to fetch tutor connections');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'connectionId': 1,
          'courseId': 1,
          'subject': 'Mathematics',
          'studentId': 1,
          'studentName': 'Asim Ali Khan',
          'studentImage': null,
          'tutorId': 1,
          'tutorName': 'Emaz Ali Khan',
          'tutorHeadline': 'Experienced Tutor',
          'status': 'ACTIVE',
          'originalPrice': 2000,
          'studentBidPrice': 1500,
          'tutorOffer': null,
          'agreedPrice': 1500,
          'requestedAt': '2026-04-01T10:00:00',
        },
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> getTutorConfirmedConnections(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorConfirmedConnections)}/$tutorProfileId/confirmed'),
        );

        if (response.statusCode == 200) {
          List<dynamic> connections = json.decode(response.body);
          return connections.map((conn) => ApiMapper.mapConnectionResponse(conn)).toList();
        } else {
          throw Exception('Failed to fetch confirmed connections');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'connectionId': 1,
          'courseId': 1,
          'subject': 'Mathematics',
          'studentId': 1,
          'studentName': 'Asim Ali Khan',
          'studentImage': null,
          'tutorId': 1,
          'tutorName': 'Emaz Ali Khan',
          'status': 'CONFIRMED',
          'agreedPrice': 1500,
          'originalPrice': 2000,
          'location': 'Karachi',
          'phoneNumber': '03451234567',
          'gender': 'Male',
          'studentEmail': 'asim@gmail.com',
        },
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getPendingRequests)}/$tutorProfileId/pending'),
        );

        if (response.statusCode == 200) {
          List<dynamic> requests = json.decode(response.body);
          return requests.map((req) => ApiMapper.mapConnectionResponse(req)).toList();
        } else {
          throw Exception('Failed to fetch pending requests');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNegotiations(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getNegotiations)}/$tutorProfileId/negotiations'),
        );

        if (response.statusCode == 200) {
          List<dynamic> negotiations = json.decode(response.body);
          return negotiations.map((neg) => ApiMapper.mapConnectionResponse(neg)).toList();
        } else {
          throw Exception('Failed to fetch negotiations');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'connectionId': 2,
          'courseId': 1,
          'subject': 'Mathematics',
          'studentId': 2,
          'studentName': 'Bilal Raza',
          'studentImage': null,
          'originalPrice': 2000,
          'studentBidPrice': 1800,
          'tutorOffer': 1900,
          'status': 'NEGOTIATING',
        },
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> getTutorBids(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorBids)}/$tutorProfileId/bids-with-cards'),
        );

        if (response.statusCode == 200) {
          List<dynamic> bids = json.decode(response.body);
          return bids.map((bid) => ApiMapper.mapConnectionResponse(bid)).toList();
        } else {
          throw Exception('Failed to fetch tutor bids');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTutorBidForCourse(int tutorId, int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorBids)}/$tutorId/course/$courseId/bids'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isNotEmpty) {
            return Map<String, dynamic>.from(data.first);
          }
          return {};
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to fetch tutor bid'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'connectionId': 1,
        'courseId': courseId,
        'studentName': 'Sample Student',
        'studentImage': null,
        'originalPrice': 5000,
        'studentBidPrice': 2500,
        'tutorOffer': 2502,
        'status': 'NEGOTIATING',
        'averageRating': 3.5,
        'category': 'MATRIC',
        'teachingMode': 'STUDENT_HOME',
        'subject': 'Biology',
      };
    }
  }

  static Future<Map<String, dynamic>> getTutorBidForCourseAndStudent(
      int tutorId, int courseId, int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorBidForStudent)}/$tutorId/course/$courseId/student/$studentId/bid'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isEmpty) {
            return {};
          }
          return data;
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to fetch bid'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  static Future<Map<String, dynamic>> tutorRespond(
      int connectionId, {
        required bool accept,
        int? counterOffer,
      }) async {
    if (useRealApi) {
      try {
        String url = '${ApiConfig.getFullUrl(ApiConfig.tutorRespond)}/$connectionId/tutor-respond?accept=$accept';
        if (counterOffer != null) {
          url += '&counterOffer=$counterOffer';
        }

        final response = await ApiClient.post(Uri.parse(url));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to respond'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  // ============ STUDENT CONNECTION APIS ============

  static Future<Map<String, dynamic>> getStudentDetail(int connectionId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.studentDetail)}/$connectionId'),
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);

          if (data['agreedPrice'] is double) {
            data['agreedPrice'] = (data['agreedPrice'] as double).toInt();
          }
          if (data['originalPrice'] is double) {
            data['originalPrice'] = (data['originalPrice'] as double).toInt();
          }

          return data;
        } else {
          throw Exception('Failed to fetch student details');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'studentId': 1,
        'studentName': 'Asim Ali Khan',
        'profileImageUrl': null,
        'location': 'Karachi',
        'phoneNumber': '03451234567',
        'gender': 'Male',
        'studentEmail': 'asim@gmail.com',
        'agreedPrice': 1500,
        'originalPrice': 2000,
        'status': 'CONFIRMED',
        'connectionId': connectionId,
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentConnectionsRaw(int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getStudentConnections}/$studentId')),
        );

        if (response.statusCode == 200) {
          final List<dynamic> connections = json.decode(response.body);
          return connections.map((conn) => Map<String, dynamic>.from(conn)).toList();
        } else {
          throw Exception('Failed to fetch student connections');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentConfirmedConnections(int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getStudentConfirmedConnections}/$studentId/confirmed')),
        );

        if (response.statusCode == 200) {
          final List<dynamic> connections = json.decode(response.body);
          return connections.map((conn) => Map<String, dynamic>.from(conn)).toList();
        } else {
          throw Exception('Failed to fetch confirmed connections');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStudentBids(int studentId, int courseId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.getStudentBids}/$studentId/course/$courseId/bids');

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else {
          throw Exception('Failed to load student bids');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<Map<String, dynamic>> requestConnection({
    required int courseId,
    required int studentId,
  }) async {
    if (useRealApi) {
      try {
        final requestBody = {
          'courseId': courseId,
          'studentId': studentId,
        };

        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.requestConnection)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'connectionId': data['connectionId'],
            'status': data['status'],
          };
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to send connection request'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'success': true,
        'connectionId': DateTime.now().millisecondsSinceEpoch,
        'status': 'PENDING',
      };
    }
  }

  static Future<Map<String, dynamic>> requestConnectionWithOffer({
    required int courseId,
    required int studentId,
    required double suggestedPrice,
  }) async {
    if (useRealApi) {
      try {
        final requestBody = {
          'courseId': courseId,
          'studentId': studentId,
          'suggestedPrice': suggestedPrice,
        };

        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.requestConnection)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'connectionId': data['connectionId'],
            'status': data['status'],
          };
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to send offer'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'success': true,
        'connectionId': DateTime.now().millisecondsSinceEpoch,
        'status': 'NEGOTIATING',
      };
    }
  }

  static Future<Map<String, dynamic>> studentRespondToCounter(
      int connectionId, {
        required bool accept,
        double? newOffer,
      }) async {
    if (useRealApi) {
      try {
        String url = '${ApiConfig.getFullUrl(ApiConfig.studentRespond)}/$connectionId/student-respond?accept=$accept';
        if (newOffer != null) {
          url += '&newOffer=$newOffer';
        }

        final response = await ApiClient.post(Uri.parse(url));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'status': data['status'],
            'message': accept ? 'Offer accepted' : 'Offer rejected',
          };
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(errorData['error'] ?? 'Failed to respond');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true};
    }
  }

  static Future<void> studentCancelPending(int connectionId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.studentCancel}/$connectionId/student-cancel')),
        );

        if (response.statusCode != 200) {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to cancel request'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  static Future<void> studentDisconnect(int connectionId, {String disconnectedBy = "STUDENT"}) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.disconnect}/$connectionId/disconnect?disconnectedBy=$disconnectedBy')),
        );

        if (response.statusCode != 200) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to disconnect');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ============ TUTOR DISCONNECT APIS ============

  static Future<void> disconnect(int connectionId, {String disconnectedBy = "TUTOR"}) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.post(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.disconnect)}/$connectionId/disconnect?disconnectedBy=$disconnectedBy'),
        );

        if (response.statusCode == 200) {
          return;
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to disconnect');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ============ SEARCH AND FILTER APIS ============

  static Future<List<Map<String, dynamic>>> searchStudents(int tutorProfileId, String query) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.searchStudents)}/$tutorProfileId/search?query=$query'),
        );

        if (response.statusCode == 200) {
          List<dynamic> students = json.decode(response.body);
          return students.map((s) => ApiMapper.mapConnectionResponse(s)).toList();
        } else {
          throw Exception('Failed to search students');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'studentId': 1,
          'studentName': 'Asim Ali Khan',
          'studentImage': null,
          'location': 'Karachi',
          'phoneNumber': '03451234567',
          'studentEmail': 'asim@gmail.com',
        },
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> filterStudents(
      int tutorProfileId, {
        String? category,
        String? teachingMode,
      }) async {
    if (useRealApi) {
      try {
        String url = '${ApiConfig.getFullUrl(ApiConfig.filterStudents)}/$tutorProfileId/students/filter';
        List<String> queryParams = [];

        if (category != null && category.isNotEmpty) {
          queryParams.add('category=$category');
        }
        if (teachingMode != null && teachingMode.isNotEmpty) {
          queryParams.add('teachingMode=$teachingMode');
        }

        if (queryParams.isNotEmpty) {
          url += '?${queryParams.join('&')}';
        }

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          List<dynamic> students = json.decode(response.body);
          return students.map((s) => ApiMapper.mapConnectionResponse(s)).toList();
        } else {
          throw Exception('Failed to filter students');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'studentId': 1,
          'studentName': 'Asim Ali Khan',
          'studentImage': null,
          'location': 'Karachi',
          'phoneNumber': '03451234567',
          'studentEmail': 'asim@gmail.com',
          'category': category,
          'teachingMode': teachingMode,
        },
      ];
    }
  }

  // ============ OFFER APIS ============

  static Future<Map<String, dynamic>> sendOffer(
      int connectionId,
      double offerPrice,
      ) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.post(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.tutorRespond)}/$connectionId/tutor-respond?accept=false&counterOffer=$offerPrice'),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'status': data['status'],
            'message': 'Offer sent successfully',
          };
        } else {
          String errorMsg = '';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? 'Failed to send offer';
          } catch (e) {
            errorMsg = response.body;
          }
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true, 'status': 'NEGOTIATING', 'message': 'Offer sent successfully'};
    }
  }

  // ============================================
//  NOTIFICATION ROUTING — check live status
// ============================================
  static Future<String> getLatestStatusForCourseAndStudent({
    required int courseId,
    required int studentId,
  }) async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '${ApiConfig.getFullUrl(ApiConfig.getStatusByCourseStudent)}'
              '?courseId=$courseId&studentId=$studentId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['status'] ?? 'NONE').toString().toUpperCase();
      }
      return 'NONE';
    } catch (e) {
      print(' getLatestStatus failed: $e');
      return 'NONE';
    }
  }
}