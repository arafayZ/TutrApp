// Import Flutter material design package
import 'package:flutter/material.dart';
import 'package:my_first_app/services/notification_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

// Importing different TUTOR screens
import 'signup/splash_screen.dart';
import 'signup/login_screen.dart';
import 'signup/role_selection_screen.dart';
import 'signup/profile_creation_screen.dart';
import 'signup/tutor_verification_screen.dart';
import 'tutor/tutor_dashboard.dart';
import 'student/student_dashboard.dart';
import 'tutor/my_bids_screen.dart';
import 'tutor/profile_screen.dart';
import 'tutor/edit_profile_screen.dart';
import 'tutor/terms_conditions_screen.dart';
import 'tutor/connection_screen.dart';
import 'tutor/inbox_screen.dart';
import 'tutor/chat_details_screen.dart';
import 'tutor/security_screen.dart';
import 'tutor/unavailable_courses_screen.dart';
import 'tutor/notifications_screen.dart';
import 'tutor/student_category_screen.dart';
import 'tutor/student_details_screen.dart';
import 'tutor/course_category_screen.dart';
import 'signup/onboarding_screen.dart';

// NEW IMPORTS for Student Management
import 'tutor/my_students_list_screen.dart';
import 'tutor/student_profile_screen.dart';

// Push notifications
import 'services/notification_service.dart';
import 'services/notification_navigator.dart';
import 'models/notification_item.dart';

// Global navigator key for notification tap routing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize notifications
  await NotificationService.instance.init();

  // ✅ Register tap handler — routes ALL notification types via NotificationNavigator
  NotificationService.instance.onNotificationTap = (data) async {
    try {
      final item = NotificationItem.fromJson(data);

      // ✅ 1. Mark as read on the backend (if we have a notification ID)
      final notificationId = int.tryParse(data['notificationId']?.toString() ?? '')
          ?? int.tryParse(data['id']?.toString() ?? '');

      if (notificationId != null && notificationId > 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getInt('userId') ?? 0;
          if (userId > 0) {
            await NotificationApiService.markAsRead(notificationId, userId);
            await NotificationService.instance.refreshBadge();
          }
        } catch (e) {
          debugPrint('⚠️ Mark as read failed: $e');
        }
      }

      // ✅ 2. Navigate
      NotificationNavigator.open(item);
    } catch (e) {
      debugPrint('❌ Notification tap error: $e');
    }
  };

  runApp(const TutrApp());
}

class TutrApp extends StatelessWidget {
  const TutrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TUTR',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          surface: Colors.white,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Colors.black87, fontSize: 16),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),

      onGenerateRoute: (settings) {
        // Handle the Connection Screen route
        if (settings.name == '/connection') {
          final String studentName = settings.arguments as String? ?? "Student";
          return MaterialPageRoute(
            builder: (context) => ConnectionScreen(studentName: studentName),
          );
        }

        // Handle the Student Details route (Metric, Inter, etc.)
        if (settings.name == '/student_details') {
          final String category = settings.arguments as String? ?? "Matric";
          return MaterialPageRoute(
            builder: (context) => StudentDetailsScreen(categoryName: category),
          );
        }

        // Handle My Students List (Passing courseId and courseName)
        if (settings.name == '/my_students_list') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MyStudentsListScreen(
              courseId: args?['courseId'] ?? 0,
              courseName: args?['courseName'] ?? '',
            ),
          );
        }

        // Handle Student Profile (Passing the StudentDetails object)
        if (settings.name == '/student_profile_details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => StudentProfileScreen(
              student: args['student'] as StudentDetails,
              onDisconnect: args['onDisconnect'] as Function(String),
            ),
          );
        }

        return null;
      },

      routes: {
        '/login': (context) => const LoginScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/tutor_dashboard': (context) => const TutorDashboard(),
        '/student_dashboard': (context) => const StudentDashboard(),
        '/tutor_verification': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return TutorVerificationScreen(userId: args?['userId'] ?? 0);
        },
        '/profile': (context) => const ProfileScreen(),
        '/inbox': (context) => const TutorInboxScreen(),
        '/profile_creation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProfileCreationScreen(
            role: args['role'],
            userId: args['userId'],
          );
        },
        '/student_category': (context) => const StudentCategoryScreen(),
        '/course_category': (context) => const CourseCategoryScreen(),
        '/edit_profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return EditProfileScreen(profileId: args['profileId']);
        },
        '/terms_conditions': (context) => const TermsConditionsScreen(),
        '/chat_details': (context) => const TutorChatDetailsScreen(userName: 'User'),
        '/security': (context) => const SecurityScreen(),
        '/unavailable_courses': (context) => const UnavailableCoursesScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}