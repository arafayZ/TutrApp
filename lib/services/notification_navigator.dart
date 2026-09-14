import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tutor/chat_details_screen.dart';
import '../student/chat_details_screen.dart';
import '../models/notification_item.dart';

class NotificationNavigator {
  static Future<void> open(BuildContext context, NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('role') ?? 'student').toLowerCase();
    final myUserId = prefs.getInt('userId') ?? 0;

    switch (item.type) {
      case 'new_message':
        _openChat(context, item, role, myUserId);
        break;

      case 'connection_request':
      case 'connection_accepted':
      // TODO: Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => ConnectionScreen(...)));
        break;

      case 'new_bid':
      case 'bid_accepted':
      // TODO: open bids screen
        break;

      case 'signup_welcome':
      case 'account_approved':
      // TODO: open profile / home
        break;

      default:
        debugPrint('Unknown notification type: ${item.type}');
    }
  }

  static void _openChat(
      BuildContext context,
      NotificationItem item,
      String role,
      int myUserId,
      ) {
    if (item.referenceId == null || item.senderId == null) return;

    // Relative path — chat screen prefixes baseUrl
    String relativeImage = item.senderImage ?? '';
    // Strip baseUrl if it slipped in
    if (relativeImage.startsWith('http')) {
      final i = relativeImage.indexOf('/uploads');
      if (i >= 0) relativeImage = relativeImage.substring(i);
    }

    if (role == 'tutor') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorChatDetailsScreen(
            userName: item.senderName ?? 'User',
            userImage: relativeImage.isEmpty ? null : relativeImage,
            studentUserId: item.senderId,
            tutorUserId: myUserId,
            chatRoomId: item.referenceId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentChatDetailsScreen(
            userName: item.senderName ?? 'User',
            userImage: relativeImage.isEmpty ? null : relativeImage,
            tutorId: item.senderId!,
            tutorUserId: item.senderId,
            studentId: myUserId,
            studentUserId: myUserId,
            chatRoomId: item.referenceId,
          ),
        ),
      );
    }
  }
}