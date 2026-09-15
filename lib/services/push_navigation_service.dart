// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../main.dart' as app;
// import '../config/api_config.dart';
// import '../tutor/chat_details_screen.dart';
// import '../student/chat_details_screen.dart';
//
// class PushNavigationService {
//   static void handleNotificationTap(Map<String, dynamic> data) {
//     final type = data['type']?.toString();
//     if (type == 'new_message') {
//       _openChat(data);
//     }
//   }
//
//   static Future<void> _openChat(Map<String, dynamic> data) async {
//     final prefs = await SharedPreferences.getInstance();
//     final role = (prefs.getString('role') ?? 'student').toLowerCase();
//     final myUserId = prefs.getInt('userId') ?? 0;
//
//     final chatRoomId = int.tryParse(data['chatRoomId']?.toString() ?? '');
//     final senderId = int.tryParse(data['senderId']?.toString() ?? '');
//     final senderName = data['senderName']?.toString() ?? 'User';
//
//     // ✅ Keep senderImage as a RELATIVE path.
//     // The chat screen adds ApiConfig.baseUrl itself.
//     String senderImage = data['senderImage']?.toString() ?? '';
//
//     // If backend somehow sent a full URL, strip the baseUrl to make it relative
//     if (senderImage.startsWith(ApiConfig.baseUrl)) {
//       senderImage = senderImage.substring(ApiConfig.baseUrl.length);
//     }
//
//     debugPrint('🔍 Push nav payload:');
//     debugPrint('   senderName  = "$senderName"');
//     debugPrint('   senderImage = "$senderImage" (relative)');
//     debugPrint('   → final URL = "${senderImage.isEmpty ? "null" : "${ApiConfig.baseUrl}$senderImage"}"');
//
//     if (chatRoomId == null || senderId == null) return;
//
//     if (role == 'tutor') {
//       app.navigatorKey.currentState?.push(
//         MaterialPageRoute(
//           builder: (_) => TutorChatDetailsScreen(
//             userName: senderName,
//             userImage: senderImage.isEmpty ? null : senderImage,
//             studentUserId: senderId,
//             tutorUserId: myUserId,
//             chatRoomId: chatRoomId,
//           ),
//         ),
//       );
//     } else {
//       app.navigatorKey.currentState?.push(
//         MaterialPageRoute(
//           builder: (_) => StudentChatDetailsScreen(
//             userName: senderName,
//             userImage: senderImage.isEmpty ? null : senderImage,
//             tutorId: senderId,
//             tutorUserId: senderId,
//             studentId: myUserId,
//             studentUserId: myUserId,
//             chatRoomId: chatRoomId,
//           ),
//         ),
//       );
//     }
//   }
// }