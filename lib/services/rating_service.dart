import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)

class RatingService {
  static bool get useRealApi => ApiConfig.useRealApi;

  // ============ HELPER METHODS ============

  static String _cleanErrorMessage(String message) {
    String cleaned = message
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatUnexpected character (at character 1)\n', '')
        .replaceFirst('FormatUnexpected character (at character 1)', '')
        .replaceAll('"', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('\\', '')
        .replaceAll('Λ', '')
        .replaceAll('^', '')
        .replaceAll('\n', ' ')
        .trim();

    cleaned = cleaned.replaceAll(' OK', '');
    cleaned = cleaned.replaceAll(' A ', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\bA\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\bOK\b'), '');

    cleaned = cleaned.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^[0-9\s]+'), '');
    cleaned = cleaned.trim();

    final lowerMsg = cleaned.toLowerCase();

    if (lowerMsg.contains('already rated')) {
      return 'You have already rated this course';
    }
    if (lowerMsg.contains('already reviewed')) {
      return 'You have already reviewed this course';
    }
    if (lowerMsg.contains('not found')) {
      return 'Course not found';
    }
    if (lowerMsg.contains('invalid')) {
      return 'Invalid request. Please try again';
    }
    if (lowerMsg.contains('rating must be between')) {
      return 'Rating must be between 1 and 5';
    }
    if (lowerMsg.contains('review cannot be empty')) {
      return 'Review cannot be empty';
    }

    if (cleaned.isEmpty) {
      return 'Something went wrong. Please try again';
    }

    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  // ============ TOP RATED COURSES ============

  static Future<List<dynamic>> getTopRatedCourses(int tutorId, {int limit = 5}) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTopRatedCourses)}/$tutorId/top-courses?limit=$limit'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to load top courses');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  // ============ TUTOR RATING SUMMARY ============

  static Future<Map<String, dynamic>> getTutorRatingSummary(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorRatingSummary)}/$tutorProfileId/summary'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch rating summary');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  // ============ TUTOR FILTER OPTIONS ============

  static Future<Map<String, dynamic>> getTutorFilterOptions(int tutorProfileId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getTutorFilterOptions)}/$tutorProfileId/filter-options'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch filter options');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  // ============ REVIEW DETAIL ============

  static Future<Map<String, dynamic>> getReviewDetail(int reviewId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.getFullUrl(ApiConfig.getReviewDetail)}/$reviewId'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to fetch review detail');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  // ============ TUTOR RATING SUMMARY WITH FILTERS ============

  static Future<Map<String, dynamic>> getTutorRatingSummaryWithFilters(
      int tutorProfileId, {
        String? category,
        String? teachingMode,
      }) async {
    if (useRealApi) {
      try {
        String url = '${ApiConfig.getFullUrl(ApiConfig.getTutorRatingSummary)}/$tutorProfileId/summary';
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
          return json.decode(response.body);
        } else {
          return {
            'averageRating': 0.0,
            'totalRatings': 0,
            'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
            'tutorName': '',
            'reviews': [],
          };
        }
      } catch (e) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
          'tutorName': '',
          'reviews': [],
        };
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  // ============ COURSE REVIEWS ============

  static Future<List<Map<String, dynamic>>> getCourseReviews(int courseId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.getCourseReviews}/$courseId/reviews');

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          if (jsonData is Map<String, dynamic> && jsonData.containsKey('reviews')) {
            final List<dynamic> reviews = jsonData['reviews'];
            return reviews.map((review) => Map<String, dynamic>.from(review)).toList();
          } else if (jsonData is List) {
            return jsonData.map((review) => Map<String, dynamic>.from(review)).toList();
          }
          return [];
        } else {
          return [];
        }
      } catch (e) {
        return [];
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  // ============ TOP TUTORS ============

  static Future<List<dynamic>> getTopTutors(int studentId) async {
    if (useRealApi) {
      try {
        final url = ApiConfig.getFullUrl('${ApiConfig.topTutors}/$studentId');

        final response = await ApiClient.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data;
        } else {
          throw Exception(_cleanErrorMessage('Failed to load top tutors'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    }
  }

  // ============ SUBMIT RATING ============

  static Future<Map<String, dynamic>> submitRating({
    required int studentId,
    required int courseId,
    required int rating,
    required String review,
  }) async {
    if (useRealApi) {
      try {
        final requestBody = {
          'studentId': studentId,
          'courseId': courseId,
          'rating': rating,
          'review': review,
        };

        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.submitRating)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Review submitted successfully',
          };
        } else {
          String errorMsg = '';
          try {
            final errorData = json.decode(response.body);
            errorMsg = errorData['error'] ?? 'Failed to submit review';
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
      return {'success': true, 'message': 'Review submitted successfully'};
    }
  }
}