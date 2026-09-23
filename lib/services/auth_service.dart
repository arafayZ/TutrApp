import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/api_mapper.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart'; // 👈 central HTTP client (adds JWT + auto-logout on 401/403)
import 'session_expired_exception.dart';

class AuthService {
  static bool get useRealApi => ApiConfig.useRealApi;

  // ============================================================
  // ==================== TOKEN STORAGE =========================
  // ============================================================

  static const String _tokenKey = 'auth_token';

  /// Save JWT token after successful login
  static Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Read saved token (null if not logged in)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Remove token on logout
  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ============================================================
  // ==================== HELPER METHODS ========================
  // ============================================================

  static String _cleanErrorMessage(String message) {
    String cleaned = message
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'[\uFEFF\u200B\u200C\u200D\u2060]'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll('"', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('\\', '')
        .replaceAll('^', '')
        .replaceFirst(RegExp(r'error:', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[0-9]+'), '')
        .trim();

    cleaned = cleaned.replaceFirst(RegExp(r'^[^A-Za-z]+'), '');

    if (cleaned.contains('must be at least')) {
      cleaned = cleaned.substring(cleaned.indexOf('must be at least'));
    } else if (cleaned.contains('Invalid email')) {
      cleaned = 'Invalid email or password';
    } else if (cleaned.contains('Email already exists')) {
      cleaned = 'Email already exists';
    } else if (cleaned.contains('User not found')) {
      cleaned = 'User not found';
    } else if (cleaned.contains('Current password is incorrect')) {
      cleaned = 'Current password is incorrect';
    } else if (cleaned.contains('Passwords do not match')) {
      cleaned = 'Passwords do not match';
    } else if (cleaned.contains('Password must be at least')) {
      cleaned = cleaned.substring(cleaned.indexOf('Password'));
    } else if (cleaned.contains('Date of birth cannot be in the future')) {
      cleaned = 'Date of birth cannot be in the future';
    } else if (cleaned.contains('Date of birth is required')) {
      cleaned = 'Date of birth is required';
    } else if (cleaned.contains('Only Gmail') || cleaned.contains('Yahoo')) {
      cleaned = 'Only Gmail and Yahoo email addresses are allowed';
    } else if (cleaned.contains('complete your tutor profile')) {
      cleaned = 'Please complete your tutor profile first';
    } else if (cleaned.contains('upload your verification documents')) {
      cleaned = 'Please upload your verification documents';
    } else if (cleaned.contains('complete your student profile')) {
      cleaned = 'Please complete your student profile first';
    } else if (cleaned.toLowerCase().contains('verify your email')) {
      cleaned = 'Please verify your email first. Check your inbox for OTP.';
    } else if (cleaned.toLowerCase().contains('suspended')) {
    cleaned = 'Your account has been suspended. Please contact support at tutr.verify@gmail.com';
    } else if (cleaned.toLowerCase().contains('permanently disabled') ||
        cleaned.toLowerCase().contains('policy violation') ||
        cleaned.toLowerCase().contains('banned')) {
      cleaned = 'This account has been permanently disabled due to policy violations.';
    } else if (cleaned.toLowerCase().contains('rejected')) {
    cleaned = 'Your documents were rejected. Please re-upload.';
    }
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\s\.]'), '').trim();

    return cleaned.isEmpty ? 'Something went wrong' : cleaned;
  }

  // ============================================================
  // ==================== AUTHENTICATION APIS ===================
  // ============================================================

  static Future<Map<String, dynamic>> login(String email, String password) async {
    if (useRealApi) {
      try {
        // 🔓 PUBLIC endpoint — raw http, no JWT needed
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.login)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email, 'password': password}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final backendData = json.decode(response.body);
          final mappedData = ApiMapper.mapLoginResponse(backendData);

          // ✅ Save JWT token
          await _saveToken(backendData['token']);

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', mappedData['id']);
          await prefs.setInt('profileId', mappedData['profileId'] ?? 0);
          await prefs.setString('userRole', mappedData['role']);
          await prefs.setInt('registrationStep', mappedData['registrationStep'] ?? 1);
          await prefs.setBool('emailVerified', mappedData['emailVerified'] ?? false);
          return mappedData;
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Login failed'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter email and password');
      }
      await _saveToken('dummy-token-for-testing');
      if (email.contains('tutor')) {
        return {
          'id': 1,
          'profileId': 1,
          'email': email,
          'role': 'TUTOR',
          'accountStatus': 'ACTIVE',
          'registrationStep': 4,
          'message': 'Login successful',
          'redirectUrl': '/tutor/dashboard',
        };
      } else {
        return {
          'id': 2,
          'profileId': 1,
          'email': email,
          'role': 'STUDENT',
          'accountStatus': 'ACTIVE',
          'registrationStep': 2,
          'message': 'Login successful',
          'redirectUrl': '/student/dashboard',
        };
      }
    }
  }

  static Future<Map<String, dynamic>> register(String email, String password, String role) async {
    if (useRealApi) {
      try {
        final requestBody = ApiMapper.mapRegisterRequest(email, password, role);
        // 🔓 PUBLIC endpoint
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.register)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final backendData = json.decode(response.body);
          return ApiMapper.mapRegisterResponse(backendData);
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Registration failed'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': role == 'Tutor' ? 1 : 2,
        'email': email,
        'role': role.toUpperCase(),
        'accountStatus': role == 'Tutor' ? 'PENDING' : 'ACTIVE',
        'registrationStep': 1,
      };
    }
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (useRealApi) {
      try {
        // 🔒 Authenticated — use ApiClient (adds JWT)
        // But we don't want forceLogout to trigger on 401 during logout,
        // so this is a rare case where we skip the 401 check.
        final token = await getToken();
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.logout)),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to logout');
        }
      } catch (e) {
        // Still clear local data but preserve onboarding
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }

    await _clearToken();

    await prefs.remove('userId');
    await prefs.remove('profileId');
    await prefs.remove('role');
    await prefs.remove('userRole');
    await prefs.remove('accountStatus');
    await prefs.remove('registrationStep');
    await prefs.remove('email');

    await prefs.setBool('hasSeenOnboarding', hasSeenOnboarding);
  }

  static Future<Map<String, dynamic>> getUserByEmail(String email) async {
    if (useRealApi) {
      try {
        // 🔓 PUBLIC — used during login error flow before token exists
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/user?email=$email'),
          headers: ApiClient.publicJsonHeaders(),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('User not found');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': 1,
        'email': email,
        'role': 'TUTOR',
        'registrationStep': 1,
        'accountStatus': 'ACTIVE',
      };
    }
  }

  // ============================================================
  // ==================== REGISTRATION APIS =====================
  // ============================================================

  static Future<Map<String, dynamic>> registerTemp(String email, String password, String role) async {
    if (useRealApi) {
      try {
        // 🔓 PUBLIC
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.registerTemp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({
            'email': email,
            'password': password,
            'role': role,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Registration failed'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'tempEmail': email,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
        'message': 'OTP sent to your email'
      };
    }
  }

  static Future<Map<String, dynamic>> verifyAndSave(String email, String otpCode) async {
    if (useRealApi) {
      try {
        // 🔓 PUBLIC
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.verifyAndSave)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({
            'email': email,
            'otpCode': otpCode,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Verification failed'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (otpCode == '1234') {
        return {'id': 1, 'email': email, 'role': 'STUDENT', 'message': 'Verified'};
      } else {
        throw Exception('Invalid OTP');
      }
    }
  }

  // ============================================================
  // ==================== EMAIL VERIFICATION APIS ===============
  // ============================================================

  static Future<Map<String, dynamic>> sendOtp(String email) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.sendOtp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to send OTP'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'Verification code sent to your email', 'email': email};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otpCode) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.verifyOtp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email, 'otpCode': otpCode}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Invalid OTP'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (otpCode == '1234') {
        return {'message': 'Email verified successfully', 'verified': true};
      } else {
        throw Exception('Invalid OTP code');
      }
    }
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.resendOtp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to resend OTP'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'New verification code sent to your email'};
    }
  }

  static Future<Map<String, dynamic>> checkVerificationStatus(String email) async {
    if (useRealApi) {
      try {
        final response = await http.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.checkVerification}/$email')),
          headers: ApiClient.publicJsonHeaders(),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to check status'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'email': email, 'verified': false, 'expiryMinutesRemaining': 5};
    }
  }

  // ============================================================
  // ==================== FORGOT PASSWORD APIS ==================
  // ============================================================

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.forgotPassword)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to send reset code'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (email.isEmpty) {
        throw Exception('Email not found');
      }
      return {'message': 'Password reset code sent to your email', 'email': email};
    }
  }

  static Future<Map<String, dynamic>> verifyResetOtp(String email, String otpCode) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.verifyResetOtp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email, 'otpCode': otpCode}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Invalid OTP'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (otpCode == '1234') {
        return {'message': 'OTP verified. You can now reset your password.', 'verified': true};
      } else {
        throw Exception('Invalid OTP code');
      }
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String otpCode, String newPassword, String confirmPassword) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.resetPassword)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({
            'email': email,
            'otpCode': otpCode,
            'newPassword': newPassword,
            'confirmPassword': confirmPassword,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to reset password'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (newPassword != confirmPassword) {
        throw Exception('New password and confirm password do not match');
      }
      return {'message': 'Password reset successfully. Please login with your new password.'};
    }
  }

  static Future<Map<String, dynamic>> resendForgotOtp(String email) async {
    if (useRealApi) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.resendForgotOtp)),
          headers: ApiClient.publicJsonHeaders(),
          body: json.encode({'email': email}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to resend code'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'New password reset code sent to your email'};
    }
  }

  // ============================================================
  // ==================== COMMON UTILITY APIS ===================
  // ============================================================

  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.changePassword)),
          body: json.encode({
            'userId': userId,
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'confirmPassword': confirmPassword,
          }),
        );

        if (response.statusCode == 200) {
          return {'message': 'Password changed successfully'};
        } else {
          final errorData = json.decode(response.body);
          String errorMessage = errorData['error'] ?? 'Failed to change password';
          errorMessage = _cleanErrorMessage(errorMessage);
          throw Exception(errorMessage);
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (newPassword != confirmPassword) {
        throw Exception('Passwords do not match');
      }
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      if (currentPassword.isEmpty) {
        throw Exception('Current password is required');
      }
      return {'message': 'Password changed successfully'};
    }
  }

  // ============================================================
  // ==================== TUTOR PROFILE APIS ====================
  // ============================================================

  static Future<Map<String, dynamic>> createTutorProfile(Map<String, dynamic> data) async {
    if (useRealApi) {
      try {
        final requestBody = ApiMapper.mapTutorProfileRequest(data);
        // 🔒 AUTHENTICATED
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.tutorProfile)),
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          final backendData = json.decode(response.body);
          return ApiMapper.mapTutorProfileResponse(backendData);
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to create profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': 1,
        'user': {'id': data['userId']},
        'firstName': data['firstName'],
        'lastName': data['lastName'],
        'profilePictureUrl': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getTutorProfile(int profileId) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getTutorProfile}/$profileId')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load profile'));
        }
      } on SessionExpiredException {
        rethrow;
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': profileId,
        'firstName': 'John',
        'lastName': 'Doe',
        'email': 'tutor@example.com',
        'phoneNumber': '923001234567',
        'headline': 'Experienced Math Tutor',
        'gender': 'Male',
        'dateOfBirth': '1990-01-01',
        'location': 'Karachi',
        'universityName': 'Karachi University',
        'collegeName': 'Government College',
        'workExperience': '5 years teaching',
        'profilePictureUrl': null,
      };
    }
  }

  static Future<Map<String, dynamic>> editTutorProfile(Map<String, dynamic> data) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.put(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.editTutorProfileJson)),
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            return {'message': 'Profile updated successfully'};
          }
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to update profile'));
        }
      } on SessionExpiredException {
        rethrow;
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'Profile updated successfully'};
    }
  }

  static Future<Map<String, dynamic>> uploadTutorImage(int profileId, String imagePath, {String? oldImageUrl}) async {
    if (useRealApi) {
      try {
        File imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          throw Exception('Image file not found');
        }

        String extension = imagePath.split('.').last.toLowerCase();
        String contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.uploadTutorImage)),
        );
        request.fields['tutorProfileId'] = profileId.toString();

        if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
          request.fields['oldImageUrl'] = oldImageUrl;
        }

        var multipartFile = await http.MultipartFile.fromPath(
          'profileImage',
          imagePath,
          contentType: MediaType.parse(contentType),
        );
        request.files.add(multipartFile);

        // 🔒 AUTHENTICATED — ApiClient adds JWT + handles 401/403
        final response = await ApiClient.sendMultipart(request);

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to upload image');
        }
      } on SessionExpiredException {
        rethrow;
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'profilePictureUrl': '/uploads/mock-image.jpg'};
    }
  }

  static Future<Map<String, dynamic>> getDocumentsByUser(int userId) async {
    if (useRealApi) {
      try {
        final response = await ApiClient.get(
          Uri.parse('${ApiConfig.baseUrl}/api/documents/user/$userId'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else if (response.statusCode == 404) {
          return {}; // no documents found
        } else {
          throw Exception('Failed to load documents');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {};
    }
  }

  static Future<Map<String, dynamic>> uploadDocuments(int userId, File cnicFile, File certificateFile) async {
    if (useRealApi) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.uploadDocuments)),
        );
        request.fields['userId'] = userId.toString();
        request.files.add(await http.MultipartFile.fromPath('cnicImage', cnicFile.path));
        request.files.add(await http.MultipartFile.fromPath('certificateImage', certificateFile.path));

        // 🔒 AUTHENTICATED
        final response = await ApiClient.sendMultipart(request);

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to upload documents');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 2));
      return {
        'id': 1,
        'verificationStatus': 'PENDING',
        'message': 'Documents uploaded successfully'
      };
    }
  }

  // ============================================================
  // ==================== STUDENT PROFILE APIS ==================
  // ============================================================

  static Future<Map<String, dynamic>> createStudentProfile(Map<String, dynamic> data) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.post(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.studentProfile)),
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = json.decode(response.body);
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to create student profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'id': 1};
    }
  }

  static Future<Map<String, dynamic>> getStudentProfile(int profileId) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.get(
          Uri.parse(ApiConfig.getFullUrl('${ApiConfig.getStudentProfile}/$profileId')),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to load student profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'id': profileId,
        'firstName': 'Abdul',
        'lastName': 'Rafay',
        'email': 'student@example.com',
        'phoneNumber': '92345892658',
        'gender': 'Male',
        'dateOfBirth': '2003-01-19',
        'location': 'Nazimabad, Karachi',
        'universityName': 'KIET',
        'degree': 'BSCS',
        'profilePictureUrl': null,
      };
    }
  }

  static Future<Map<String, dynamic>> editStudentProfile(Map<String, dynamic> data) async {
    if (useRealApi) {
      try {
        var request = http.MultipartRequest(
          'PUT',
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.editStudentProfile)),
        );

        request.fields['profileId'] = data['profileId'].toString();
        request.fields['firstName'] = data['firstName'] ?? '';
        request.fields['lastName'] = data['lastName'] ?? '';
        request.fields['phoneNumber'] = data['phoneNumber'] ?? '';
        request.fields['gender'] = data['gender'] ?? '';
        request.fields['dateOfBirth'] = data['dateOfBirth'] ?? '';
        request.fields['location'] = data['location'] ?? '';
        request.fields['schoolName'] = data['schoolName'] ?? '';
        request.fields['collegeName'] = data['collegeName'] ?? '';

        if (data['profileImage'] != null && data['profileImage'] is File) {
          File imageFile = data['profileImage'];
          var multipartFile = await http.MultipartFile.fromPath(
            'profileImage',
            imageFile.path,
          );
          request.files.add(multipartFile);
        }

        // 🔒 AUTHENTICATED
        final response = await ApiClient.sendMultipart(request);

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            return {'message': 'Profile updated successfully'};
          }
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to update student profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'Profile updated successfully'};
    }
  }

  static Future<Map<String, dynamic>> editStudentProfileJson(Map<String, dynamic> data) async {
    if (useRealApi) {
      try {
        // 🔒 AUTHENTICATED
        final response = await ApiClient.put(
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.editStudentProfileJson)),
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            return {'message': 'Profile updated successfully'};
          }
          return json.decode(response.body);
        } else {
          final errorData = response.body.isNotEmpty ? json.decode(response.body) : {};
          throw Exception(_cleanErrorMessage(errorData['error'] ?? 'Failed to update student profile'));
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'message': 'Profile updated successfully'};
    }
  }

  static Future<Map<String, dynamic>> uploadStudentImage(int profileId, String imagePath, {String? oldImageUrl}) async {
    if (useRealApi) {
      try {
        File imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          throw Exception('Image file not found');
        }

        String extension = imagePath.split('.').last.toLowerCase();
        String contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.getFullUrl(ApiConfig.uploadStudentImage)),
        );
        request.fields['studentProfileId'] = profileId.toString();

        if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
          request.fields['oldImageUrl'] = oldImageUrl;
        }

        var multipartFile = await http.MultipartFile.fromPath(
          'profileImage',
          imagePath,
          contentType: MediaType.parse(contentType),
        );
        request.files.add(multipartFile);

        // 🔒 AUTHENTICATED
        final response = await ApiClient.sendMultipart(request);

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to upload student image');
        }
      } catch (e) {
        throw Exception(_cleanErrorMessage(e.toString()));
      }
    } else {
      await Future.delayed(const Duration(seconds: 1));
      return {'profilePictureUrl': '/uploads/mock-student-image.jpg'};
    }
  }
}