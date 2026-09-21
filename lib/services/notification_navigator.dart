import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' as app;
import '../tutor/chat_details_screen.dart';
import '../student/chat_details_screen.dart';
import '../tutor/bid_details_screen.dart' as tutor_bid;
import '../student/bid_details_screen.dart' as student_bid;
import '../tutor/course_detail_screen.dart' as tutor_course;
import '../student/course_details_screen.dart' as student_course;
import '../tutor/connection_screen.dart' as tutor_connection;
import '../student/connection_screen.dart' as student_connection;
import '../services/connection_service.dart';
import '../models/notification_item.dart';

class NotificationNavigator {
  static Future<void> open(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('role') ?? 'student').toLowerCase();
    final myUserId = prefs.getInt('userId') ?? 0;

    debugPrint(' Navigation — type=${item.type}, role=$role');

    switch (item.type) {
      case 'new_message':
        _openChat(item, role, myUserId);
        break;

      case 'connection_disconnected':
      case 'connection_declined':
      case 'connection_expired':
        _openCourseDetails(item, role);
        break;

      case 'connection_accepted':
        _openConnections(role);
        break;

      case 'connection_request':
      case 'connection_counter':
      case 'connection_cancelled':
        await _openBidDetails(item, role);
        break;

      case 'signup_welcome':
      case 'account_approved':
        debugPrint('ℹ ${item.type} — no navigation (info only)');
        break;

      default:
        debugPrint(' Unknown notification type: ${item.type}');
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
  // BID DETAILS — check live status first
  // ============================================================
  static Future<void> _openBidDetails(NotificationItem item, String role) async {
    if (item.courseId == null || item.senderId == null) {
      debugPrint(' Missing courseId or senderId — cannot route');
      return;
    }

    //  Fetch the live status from the backend
    final status = await ConnectionService.getLatestStatusForCourseAndStudent(
      courseId: item.courseId!,
      studentId: item.senderId!,
    );

    debugPrint(' Bid status = $status (course=${item.courseId}, student=${item.senderId})');

    switch (status) {
      case 'PENDING':
      case 'NEGOTIATING':
        _pushBidDetails(item, role);
        break;

      case 'CONFIRMED':
        _openConnections(role);
        break;

      case 'REJECTED':
      case 'CANCELLED':
      case 'EXPIRED':
      case 'DISCONNECTED':
      case 'NONE':
      default:
        _openCourseDetails(item, role);
        break;
    }
  }

  static void _pushBidDetails(NotificationItem item, String role) {
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
  // COURSE DETAILS
  // ============================================================
  static void _openCourseDetails(NotificationItem item, String role) {
    if (item.courseId == null) {
      debugPrint(' No courseId — cannot open course details');
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
  // CONNECTIONS
  // ============================================================
  static void _openConnections(String role) {
    if (role == 'tutor') {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
          const tutor_connection.ConnectionScreen(studentName: ''),
        ),
      );
    } else {
      app.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const student_connection.ConnectionScreen(),
        ),
      );
    }
  }
}