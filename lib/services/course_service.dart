import 'dart:convert';
import '../config/api_config.dart';
import '../utils/api_mapper.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class CourseService {
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
        .replaceAll('Λ', '')
        .replaceAll('OK', '')
        .replaceAll('\n', '')
        .trim();

    cleaned = cleaned.replaceFirst(RegExp(r'^[^a-zA-Z\s]+'), '').trim();

    String lowerMsg = cleaned.toLowerCase();

    if (lowerMsg.contains('students are connected') ||
        lowerMsg.contains('cannot delete course: students are connected') ||
        lowerMsg.contains('students are connected to this course')) {
      return 'Cannot delete course. Students are enrolled in it.';
    }

    if (lowerMsg.contains('new counter offer must be less than your previous offer')) {
      final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (priceMatch != null) {
        return 'Counter offer must be less than your previous offer of ${priceMatch.group(1)} PKR';
      }
      return 'Counter offer must be less than your previous offer';
    }

    if (lowerMsg.contains('new offer must be greater than your previous offer')) {
      final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (priceMatch != null) {
        return 'New offer must be greater than your previous offer of ${priceMatch.group(1)} PKR';
      }
      return 'New offer must be greater than your previous offer';
    }

    if (lowerMsg.contains('your offer must be less than tutor\'s offer')) {
      final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (priceMatch != null) {
        return 'Your offer must be less than tutor\'s offer of ${priceMatch.group(1)} PKR';
      }
      return 'Your offer must be less than tutor\'s offer';
    }

    if (lowerMsg.contains('counter offer must be greater than student\'s offer')) {
      final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
      if (priceMatch != null) {
        return 'Counter offer must be greater than student\'s offer of ${priceMatch.group(1)} PKR';
      }
      return 'Counter offer must be greater than student\'s offer';
    }

    if (lowerMsg.contains('fromday') && lowerMsg.contains('today')) {
      return 'From day must come before to day';
    }

    if ((lowerMsg.contains('start time') && lowerMsg.contains('end time')) ||
        (lowerMsg.contains('starttime') && lowerMsg.contains('endtime'))) {
      return 'Start time must be before end time';
    }

    if (lowerMsg.contains('format')) {
      if (lowerMsg.contains('day')) return 'From day must come before to day';
      if (lowerMsg.contains('time')) return 'Start time must be before end time';
      return 'Please check your input and try again';
    }

    if (lowerMsg.contains('price')) return 'Invalid price value';
    if (lowerMsg.contains('subject')) return 'Subject is required';
    if (lowerMsg.contains('category')) return 'Category is required';
    if (lowerMsg.contains('teaching mode')) return 'Teaching mode is required';
    if (lowerMsg.contains('location')) return 'Location is required';
    if (lowerMsg.contains('classes')) return 'Number of classes is required';

    if (cleaned.isEmpty || RegExp(r'^[0-9\s]+$').hasMatch(cleaned)) {
      return 'Something went wrong';
    }

    if (cleaned.isNotEmpty) {
      return cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  // ============ COURSE CRUD OPERATIONS ============

  static Future<Map<String, dynamic>> createCourse(Map<String, dynamic> courseData) async {
    if (useRealApi) {
      try {
        final requestBody = ApiMapper.mapCourseRequest(courseData);

        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.createCourse)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final backendData = json.decode(response.body);
          return ApiMapper.mapCourseResponse(backendData);
        } else {
          final errorData = json.decode(response.body);
          String errorMsg = errorData['error'] ?? 'Failed to create course';
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': DateTime.now().millisecondsSinceEpoch,
        'subject': courseData['subject'],
        'category': courseData['category'],
        'teachingMode': courseData['teachingMode'],
        'price': courseData['price'],
        'isAvailable': true,
      };
    }
  }

  static Future<Map<String, dynamic>> updateCourse(int courseId, Map<String, dynamic> courseData) async {
    if (useRealApi) {
      try {
        final requestBody = ApiMapper.mapCourseRequest(courseData);

        final response = await ApiClient.put(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.updateCourse)}/$courseId'),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final backendData = json.decode(response.body);
          return ApiMapper.mapCourseResponse(backendData);
        } else {
          final errorData = json.decode(response.body);
          String errorMsg = errorData['error'] ?? 'Failed to update course';
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'id': courseId, ...courseData};
    }
  }

  static Future<void> deleteCourse(int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.delete(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.deleteCourse)}/$courseId'),
        );

        if (response.statusCode != 200) {
          final errorData = json.decode(response.body);
          String errorMsg = errorData['error'] ?? 'Failed to delete course';
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  static Future<String> toggleAvailability(int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.put(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.toggleAvailability)}/$courseId/toggle-availability'),
        );

        if (response.statusCode == 200) {
          return response.body;
        } else {
          final errorData = json.decode(response.body);
          String errorMsg = errorData['error'] ?? 'Failed to toggle availability';
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return 'Course is now unavailable';
    }
  }

  // ============ TUTOR COURSE APIS ============

  static Future<List<dynamic>> getTutorCourses(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorCourses)}/$tutorProfileId'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch courses');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'id': 1,
          'subject': 'Mathematics',
          'price': 5000,
          'isAvailable': true,
          'averageRating': 4.8
        },
        {
          'id': 2,
          'subject': 'Physics',
          'price': 6000,
          'isAvailable': false,
          'averageRating': 4.5
        },
      ];
    }
  }

  static Future<Map<String, dynamic>> getTutorCourseDetail(int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorCourseDetail)}/$courseId'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else if (response.statusCode == 404) {
          throw Exception('Course not found');
        } else {
          final errorData = json.decode(response.body);
          String errorMsg = errorData['error'] ?? 'Failed to fetch course details';
          throw Exception(_cleanErrorMessage(errorMsg));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': courseId,
        'subject': 'Mathematics',
        'category': 'Matric',
        'teachingMode': 'Online',
        'price': 5000,
        'isAvailable': true,
        'averageRating': 4.8,
        'totalRatings': 12,
        'about': 'This is a sample course description.',
        'classesPerMonth': 8,
        'startTime': '14:00:00',
        'endTime': '16:00:00',
        'fromDay': 'Monday',
        'toDay': 'Friday',
        'location': 'Online',
      };
    }
  }

  static Future<List<dynamic>> getTutorCourseCards(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorCourseCards)}/$tutorProfileId/cards'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch tutor course cards');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'id': 1,
          'courseId': 1,
          'subject': 'Mathematics',
          'price': 5000,
          'category': 'MATRIC',
          'teachingMode': 'ONLINE',
          'averageRating': 4.8,
          'totalStudents': 23,
          'tutorName': 'John Doe',
          'location': 'Karachi',
          'isAvailable': true,
        },
      ];
    }
  }

  // ============ STUDENT COURSE APIS ============

  static Future<List<dynamic>> getAvailableCourses() async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.getAvailableCourses)),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch available courses');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'courseId': 1,
          'subject': 'Mathematics',
          'price': 5000,
          'category': 'MATRIC',
          'teachingMode': 'ONLINE',
          'averageRating': 4.8,
          'totalStudents': 23,
          'tutorName': 'John Doe',
          'location': 'Karachi',
          'about': 'Math course',
          'isAvailable': true
        },
      ];
    }
  }

  static Future<List<dynamic>> searchCourses(Map<String, String> params) async {
    if (useRealApi) {
      try {
        List<String> queryParams = [];
        params.forEach((key, value) {
          if (value.isNotEmpty) {
            queryParams.add('$key=${Uri.encodeComponent(value)}');
          }
        });

        String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
        final url = ApiConfig.getFullUrl('${ApiConfig.searchCourses}$queryString');

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to search courses'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'id': 1,
          'courseName': 'Physics',
          'subject': 'Physics',
          'price': 2000,
          'teachingMode': 'ONLINE',
          'averageRating': 4.2,
          'tutorName': 'Asif Ali Khan',
          'tutorId': 1,
          'tutorImage': null,
        },
      ];
    }
  }

  static Future<List<dynamic>> getAvailableCoursesForStudent(int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getAvailableCoursesForStudent}/$studentId/available')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load courses'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<Map<String, dynamic>> getCourseForStudent(int courseId, int studentId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.getCourseForStudent}/$courseId/student?studentId=$studentId');

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);

          if (!data.containsKey('courseId') && !data.containsKey('subject')) {
            throw Exception('Invalid course data received');
          }

          return data;
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(errorData['error'] ?? 'Failed to load course details');
        }
      } catch (e) {
        throw Exception('Failed to load course details');
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'courseId': courseId,
        'subject': 'Sample Course',
        'price': 5000,
        'category': 'MATRIC',
        'averageRating': 4.5,
        'totalRatings': 10,
        'location': 'Online',
        'teachingMode': 'ONLINE',
        'about': 'Sample course description',
        'classesPerMonth': 8,
        'startTime': '6:00 PM',
        'endTime': '8:00 PM',
        'fromDay': 'Monday',
        'toDay': 'Friday',
        'tutorName': 'Sample Tutor',
        'tutorId': 1,
        'tutorImage': null,
        'tutorHeadline': 'Expert Tutor',
        'connectionStatus': 'NONE',
        'connectionId': null,
      };
    }
  }

  // ============ FAVORITE OPERATIONS ============

  static Future<Map<String, dynamic>> addToFavorites(int studentId, int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.addFavorite}/$studentId/add/$courseId')),
        );

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'Added to favorites'};
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to add to favorites'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true};
    }
  }

  static Future<Map<String, dynamic>> removeFromFavorites(int studentId, int courseId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.delete(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.removeFavorite}/$studentId/remove/$courseId')),
        );

        if (response.statusCode == 200) {
          return {'success': true, 'message': 'Removed from favorites'};
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to remove from favorites'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'success': true};
    }
  }

  static Future<List<dynamic>> getFavorites(int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getFavorites}/$studentId')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load favorites'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  // ============ TUTOR PROFILE APIS ============

  static Future<List<dynamic>> getAllTutors(int studentId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getalltutor}/$studentId')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load tutors'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTutorProfile(int studentId, int tutorId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.tutorProfileView}/$studentId/$tutorId/profile')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load tutor profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }
}