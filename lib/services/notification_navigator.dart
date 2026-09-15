import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' as app;
import '../tutor/chat_details_screen.dart';
import '../student/chat_details_screen.dart';
import '../tutor/bid_details_screen.dart' as tutor_bid;
import '../student/bid_details_screen.dart' as student_bid;
import '../tutor/course_detail_screen.dart' as tutor_course;
import '../student/course_details_screen.dart' as student_course;
import '../tutor/my_bids_screen.dart';
import '../student/connection_screen.dart';
import '../models/notification_item.dart';

class NotificationNavigator {
  /// Entry point — works from push tap OR list tap
  static Future<void> open(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('role') ?? 'student').toLowerCase();
    final myUserId = prefs.getInt('userId') ?? 0;

    debugPrint('🧭 Navigation — type=${item.type}, role=$role');

    switch (item.type) {
      case 'new_message':
        _openChat(item, role, myUserId);
        break;

      case 'connection_disconnected':
      case 'connection_declined':
        _openCourseDetails(item, role);
        break;

      case 'connection_accepted':
        _openConnections(role);
        break;

      case 'connection_request':
      case 'connection_counter':
      case 'connection_cancelled':
        _openBidDetails(item, role);
        break;

      case 'signup_welcome':
      case 'account_approved':
      // ✅ No navigation for these types — just dismiss
        debugPrint('ℹ️ ${item.type} — no navigation (info only)');
        break;

      default:
        debugPrint('❓ Unknown notification type: ${item.type}');
    }
  }

  // ============================================================
  // CHAT
  // ============================================================
  static void _openChat(NotificationItem item, String role, int myUserId) {
    if (item.referenceId == null || item.senderId == null) return;

    String relativeImage = item.senderImage ?? '';
    if (relativeImage.startsWith('http')) {
      final i = relativeImage.indexOf('/uploads');
      if (i >= 0) relativeImage = relativeImage.substring(i);
    }

    if (role == 'tutor') {
      app.navigatorKey.currentState?.push(
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
      app.navigatorKey.currentState?.push(
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

  // ============================================================
  // BID DETAILS
  // ============================================================
  static void _openBidDetails(NotificationItem item, String role) {
    if (item.courseId == null) {
      debugPrint('❌ No courseId — cannot open bid details');
      return;
    }

    if (role == 'tutor') {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => tutor_bid.BidDetailsScreen(
            courseId: item.courseId!,
            studentId: item.senderId ?? 0,
            studentName: item.senderName ?? 'Student',
            isRequest: item.type == 'connection_request',
          ),
        ),
      );
    } else {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => student_bid.BidDetailsScreen(
            courseId: item.courseId!,
            studentId: item.senderId ?? 0,
          ),
        ),
      );
    }
  }

  // ============================================================
  // COURSE DETAILS (disconnect / decline)
  // ============================================================
  static void _openCourseDetails(NotificationItem item, String role) {
    if (item.courseId == null) {
      debugPrint('❌ No courseId — cannot open course details');
      return;
    }

    if (role == 'tutor') {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => tutor_course.CourseDetailScreen(
            courseId: item.courseId!,
            onCourseUpdated: () {},
          ),
        ),
      );
    } else {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => student_course.CourseDetailsScreen(
            courseData: {
              'id': item.courseId,
              'courseId': item.courseId,
              'tutorName': item.senderName ?? 'Tutor',
              'name': item.senderName ?? 'Tutor',
              'tutorImage': item.senderImage ?? '',
            },
          ),
        ),
      );
    }
  }

  // ============================================================
  // CONNECTIONS (accepted)
  // ============================================================
  static void _openConnections(String role) {
    if (role == 'tutor') {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MyBidsScreen()),
      );
    } else {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ConnectionScreen()),
      );
    }
  }
}