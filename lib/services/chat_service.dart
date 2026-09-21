// lib/services/chat_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'chat_exceptions.dart'; // 👈 NEW

class ChatService {

  // ============================================================
  // GET OR CREATE SHARED CHAT ROOM
  // ============================================================
  static Future<ChatRoom> getOrCreateSharedChatRoom(
      int studentUserId, int tutorUserId, int userId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getSharedChatRoom}'
            '?studentId=$studentUserId&tutorId=$tutorUserId&userId=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatRoom.fromJson(data);
      }

      // ✅ No confirmed connection → special exception
      if (response.statusCode == 404) {
        throw ChatUnavailableException(
          'No confirmed connection with this tutor',
        );
      }

      // ✅ Not part of chat → special exception
      if (response.statusCode == 403) {
        throw ChatForbiddenException('Access denied to this chat');
      }

      // Everything else → generic
      String errorMsg = 'Failed to get/create shared chat room';
      try {
        final error = json.decode(response.body);
        errorMsg = error['message'] ?? error['error'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);

    } on ChatUnavailableException {
      rethrow;
    } on ChatForbiddenException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // EXISTING: Connection-based chat room (backward compat)
  // ============================================================
  static Future<ChatRoom> getOrCreateChatRoom(
      int connectionId, int userId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getChatRoom}'
            '/$connectionId?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatRoom.fromJson(data);
      }

      if (response.statusCode == 404) {
        throw ChatUnavailableException('Chat not available');
      }
      if (response.statusCode == 403) {
        throw ChatForbiddenException('Access denied to this chat');
      }

      throw Exception('Failed to get chat room');
    } on ChatUnavailableException {
      rethrow;
    } on ChatForbiddenException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  static Future<List<ChatRoom>> getUserChatRooms(int userId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getUserChatRooms}/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatRoom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get chat rooms');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================
  static Future<Message> sendMessage(SendMessageRequest request) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessage}'),
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Message.fromJson(data);
      }

      // ✅ No confirmed connection → special exception
      if (response.statusCode == 404) {
        throw ChatUnavailableException(
          'Cannot send message: no confirmed connection',
        );
      }

      if (response.statusCode == 403) {
        throw ChatForbiddenException('Access denied to this chat');
      }

      throw Exception('Failed to send message');
    } on ChatUnavailableException {
      rethrow;
    } on ChatForbiddenException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // GET MESSAGES
  // ============================================================
  static Future<List<Message>> getMessages(
      int roomId, int userId, {int page = 0, int size = 50}) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getMessages}'
            '/$roomId?userId=$userId&page=$page&size=$size'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      }

      // ✅ No confirmed connection → special exception
      if (response.statusCode == 404) {
        throw ChatUnavailableException(
          'Cannot access messages: no confirmed connection',
        );
      }

      if (response.statusCode == 403) {
        throw ChatForbiddenException('Access denied to this chat');
      }

      throw Exception('Failed to get messages');
    } on ChatUnavailableException {
      rethrow;
    } on ChatForbiddenException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // REST OF FILE — UNCHANGED
  // ============================================================

  static Future<void> markAllAsRead(int roomId, int userId) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.markAsRead}'
            '/$roomId/read-all?userId=$userId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark as read');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static Future<int> getUnreadCount(int userId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getUnreadCount}/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unreadCount'] ?? 0;
      } else {
        throw Exception('Failed to get unread count');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static Future<void> deleteMessage(int messageId, int userId) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deleteMessage}'
            '/$messageId?userId=$userId'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        throw Exception('Failed to delete message');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static Future<bool> isChatAvailable(int connectionId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.checkChatAvailable}'
            '/$connectionId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isAvailable'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // AUDIO + FILE UPLOADS
  // ============================================

  static Future<String> uploadAudio(File audioFile, int userId) async {
    try {
      print('📤 Uploading audio: ${audioFile.path}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadAudio}?userId=$userId'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      final response = await ApiClient.sendMultipart(request);

      print('📡 Upload status: ${response.statusCode}');
      print('📡 Upload response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['audioUrl'];
      } else {
        throw Exception('Failed to upload audio: ${response.body}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Error uploading: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(File file, int userId) async {
    try {
      print('📤 Uploading file: ${file.path}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadFile}?userId=$userId'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final response = await ApiClient.sendMultipart(request);

      print('📡 Upload status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'fileUrl': data['fileUrl'],
          'fileName': data['fileName'],
          'fileSize': data['fileSize'],
          'fileType': data['fileType'],
        };
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Error uploading: ${e.toString()}');
    }
  }

  // ============================================
  // PUSH NOTIFICATIONS — Device Token
  // ============================================

  static Future<void> registerDeviceToken(
      int userId,
      String token,
      String platform,
      ) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerDeviceToken}'),
        body: json.encode({
          'userId': userId,
          'token': token,
          'platform': platform,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to register device token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static Future<void> removeDeviceToken(String token) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.removeDeviceToken}'),
        body: json.encode({'token': token}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove device token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }
}