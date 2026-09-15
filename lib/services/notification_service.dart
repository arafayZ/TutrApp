import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'chat_service.dart';
import 'notification_api_service.dart';

// ============================================================
// BACKGROUND HANDLER — must be top-level function
// ============================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [BG] Message: ${message.data}');
}

// ============================================================
// NOTIFICATION SERVICE — singleton
// ============================================================
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  // Callback — main.dart sets this to handle navigation on tap
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // ✅ Broadcasts badge count changes to listening widgets
  final ValueNotifier<int> badgeNotifier = ValueNotifier<int>(0);

  bool _initialized = false;

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request permission (Android 13+)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 Permission: ${settings.authorizationStatus}');

    // 2. Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      playSound: true,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 3. Initialize local notifications plugin
    const androidInit =
    AndroidInitializationSettings('@drawable/ic_notification');

    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 4. Register background handler
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // 5. Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 6. Tap while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // 7. Tap while app was killed (cold start)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 Launched from notification: ${initial.data}');
      Future.delayed(const Duration(milliseconds: 800), () {
        _onMessageOpened(initial);
      });
    }
  }

  // ------------------------------------------------------------
  // FOREGROUND MESSAGE → show notification + refresh badge
  // ------------------------------------------------------------
  Future<void> _onForegroundMessage(RemoteMessage msg) async {
    debugPrint('📩 [FG] ${msg.notification?.title}');

    final notification = msg.notification;
    if (notification == null) return;

    // Build sender image URL
    final rawImage = msg.data['senderImage']?.toString() ?? '';
    final fullImageUrl = rawImage.isNotEmpty
        ? (rawImage.startsWith('http') ? rawImage : '${ApiConfig.baseUrl}$rawImage')
        : '';

    // Try to download sender's pic
    AndroidBitmap<Object> largeIcon =
    const DrawableResourceAndroidBitmap('@mipmap/launcher_icon');
    if (fullImageUrl.isNotEmpty) {
      final downloaded = await _downloadImage(fullImageUrl);
      if (downloaded != null) largeIcon = downloaded;
    }

    _local.show(
      msg.hashCode,
      notification.title ?? 'New message',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          largeIcon: largeIcon,
        ),
      ),
      payload: jsonEncode(msg.data),
    );

    _updateBadgeFromData(msg.data);

    // ✅ Instantly refresh bell badge when a push arrives
    Future.delayed(const Duration(milliseconds: 300), () {
      refreshBadge();
    });
  }

  // ✅ Helper — downloads image URL to a temp file, returns bitmap
  Future<AndroidBitmap<Object>?> _downloadImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/notif_${url.hashCode}.png');
      await file.writeAsBytes(response.bodyBytes);

      return FilePathAndroidBitmap(file.path);
    } catch (e) {
      debugPrint('❌ Image download failed: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // TAP HANDLING
  // ------------------------------------------------------------
  void _onMessageOpened(RemoteMessage msg) {
    debugPrint('👆 Notification tapped: ${msg.data}');
    onNotificationTap?.call(msg.data);
  }

  void _onLocalNotificationTap(NotificationResponse res) {
    if (res.payload == null) return;
    try {
      final data = jsonDecode(res.payload!) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('❌ Payload parse error: $e');
    }
  }

  // ------------------------------------------------------------
  // BADGE
  // ------------------------------------------------------------
  Future<void> _updateBadgeFromData(Map<String, dynamic> data) async {
    final badgeStr = data['badge'];
    if (badgeStr == null) return;
    final count = int.tryParse(badgeStr.toString()) ?? 0;
    await updateBadge(count);
  }

  Future<void> updateBadge(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
      // Keep the notifier in sync
      if (badgeNotifier.value != count) {
        badgeNotifier.value = count;
      }
    } catch (e) {
      debugPrint('❌ Badge update error: $e');
    }
  }

  /// ✅ Fetch fresh unread count from backend → broadcast to listeners
  /// Call this after push arrives OR after marking as read.
  Future<void> refreshBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;
      if (userId == 0) return;

      final count = await NotificationApiService.getUnreadCount(userId);
      if (badgeNotifier.value != count) {
        badgeNotifier.value = count;
      }
      await AppBadgePlus.updateBadge(count);
    } catch (e) {
      debugPrint('❌ refreshBadge failed: $e');
    }
  }

  // ------------------------------------------------------------
  // TOKEN REGISTRATION
  // ------------------------------------------------------------
  Future<void> registerToken(int userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('📱 FCM Token: $token');

      if (token != null) {
        await ChatService.registerDeviceToken(userId, token, 'android');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 Token refreshed: $newToken');
        await ChatService.registerDeviceToken(userId, newToken, 'android');
      });
    } catch (e) {
      debugPrint(' Token registration failed: $e');
    }
  }

  Future<void> removeToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ChatService.removeDeviceToken(token);
      }
      await FirebaseMessaging.instance.deleteToken();
      await updateBadge(0);
      badgeNotifier.value = 0;
    } catch (e) {
      debugPrint(' Token removal failed: $e');
    }
  }
}