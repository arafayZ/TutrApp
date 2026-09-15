import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dashboard_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import 'student_category_screen.dart';
import 'my_bids_screen.dart';
import 'course_category_screen.dart';
import 'reviews_screen.dart';
import 'add_course_screen.dart';
import 'search_screen.dart';
import 'course_detail_screen.dart';
import 'notifications_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../services/connection_service.dart';
import '../config/api_config.dart';
import '../utils/status_bar_config.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';

class CourseColors {
  static const List<Color> colors = [
    Color(0xFF1A1A2E), // Dark Navy
    Color(0xFF16213E), // Deep Navy
    Color(0xFF0F3460), // Dark Blue
    Color(0xFF8B1E3F), // Dark Crimson
    Color(0xFF2C3E50), // Dark Slate
    Color(0xFF1B4F72), // Deep Teal
    Color(0xFF145A32), // Dark Green
    Color(0xFF7B2C3E), // Deep Maroon
    Color(0xFF4A235A), // Dark Violet
    Color(0xFF1C2833), // Almost Black Blue
    Color(0xFF6E2C00), // Dark Orange-Brown
    Color(0xFF0B5345), // Dark Cyan-Green
    Color(0xFF424949), // Dark Gray
    Color(0xFF5D4037), // Dark Brown
    Color(0xFF283747), // Dark Steel Blue
    Color(0xFF7E5109), // Dark Gold
    Color(0xFF4A4A4A), // Dark Gray
    Color(0xFF3E2723), // Very Dark Brown
    Color(0xFF1A237E), // Deep Indigo
  ];

  static Color getCourseColor(int courseId) {
    return colors[courseId % colors.length];
  }
}

// --- 1. DATA MODEL ---
class Course {
  final int id;
  final String tutorName;
  final String subject;
  final String grade;
  final String price;
  final String rating;
  final String mode;
  final Color courseColor;
  final String? backgroundImage;
  final bool isAvailable;
  final int rank;

  Course({
    required this.id,
    required this.tutorName,
    required this.subject,
    required this.grade,
    required this.price,
    required this.rating,
    required this.mode,
    required this.courseColor,
    this.backgroundImage,
    required this.isAvailable,
    this.rank = 0,
  });
}

enum TutorStatus { pending, active }

// --- 2. MAIN DASHBOARD ---
class TutorDashboard extends StatefulWidget {
  const TutorDashboard({super.key});

  @override
  State<TutorDashboard> createState() => _TutorDashboardState();
}

class _TutorDashboardState extends State<TutorDashboard> with WidgetsBindingObserver {
  TutorStatus currentStatus = TutorStatus.active;
  String userName = "";
  String? profileImageUrl;
  int activeStudents = 0;
  int activeCourses = 0;
  List<Course> topCourses = [];
  bool _isLoading = true;
  int profileId = 0;
  String _accountStatus = "";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusBarConfig.setLightStatusBar();
    });
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      StatusBarConfig.setLightStatusBar();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    StatusBarConfig.setLightStatusBar();
  }

  @override
  void activate() {
    super.activate();
    StatusBarConfig.setLightStatusBar();
  }

  String _formatMode(String? mode) {
    if (mode == null || mode.isEmpty) return "Online";
    String formatted = mode.replaceAll('_', ' ');
    List<String> words = formatted.split(' ');
    for (int i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1).toLowerCase();
      }
    }
    return words.join(' ');
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      profileId = prefs.getInt('profileId') ?? 0;

      String savedStatus = prefs.getString('accountStatus') ?? 'ACTIVE';
      _accountStatus = savedStatus;

      if (savedStatus.toUpperCase() == 'PENDING') {
        final profileData = await AuthService.getTutorProfile(profileId);

        setState(() {
          currentStatus = TutorStatus.pending;
          userName = (profileData['firstName'] ?? '') + " " + (profileData['lastName'] ?? '');
          profileImageUrl = profileData['profilePictureUrl'];
          _isLoading = false;
        });
        return;
      }

      currentStatus = TutorStatus.active;

      final profileData = await AuthService.getTutorProfile(profileId);

      String serverStatus = profileData['accountStatus'] ??
          profileData['status'] ??
          profileData['verificationStatus'] ??
          'ACTIVE';
      await prefs.setString('accountStatus', serverStatus);

      final dashboardData = await DashboardService.getTutorDashboard(profileId);
      List<dynamic> courses = await CourseService.getTutorCourses(profileId);

      List<Course> availableCourses = [];

      Map<int, int> rankMap = {};
      if (dashboardData['topCourses'] != null) {
        for (var topCourse in dashboardData['topCourses']) {
          int courseId = topCourse['courseId'] ?? 0;
          int rank = topCourse['rank'] ?? 999;
          if (courseId > 0) {
            rankMap[courseId] = rank;
          }
        }
      }

      for (var course in courses) {
        if (course['isAvailable'] == true) {
          int courseId = course['id'];
          int rank = rankMap[courseId] ?? 999; // Get rank from map, default to 999
          availableCourses.add(Course(
            id: courseId,
            tutorName: (profileData['firstName'] ?? '') + " " + (profileData['lastName'] ?? ''),
            subject: course['subject'] ?? '',
            grade: course['category'] ?? '',
            price: course['price'] != null ? "Rs ${course['price']}" : "Rs 0",
            rating: (course['averageRating'] ?? 0.0).toString(),
            mode: _formatMode(course['teachingMode']),
            courseColor: CourseColors.getCourseColor(courseId),
            isAvailable: course['isAvailable'] ?? true,
            rank: rank,
          ));
        }
      }
      availableCourses.sort((a, b) => a.rank.compareTo(b.rank));
      int uniqueStudentsCount = await _getUniqueActiveStudentsCount();

      setState(() {
        userName = (profileData['firstName'] ?? '') + " " + (profileData['lastName'] ?? '');
        profileImageUrl = profileData['profilePictureUrl'];
        activeStudents = uniqueStudentsCount;
        activeCourses = dashboardData['totalActiveCourses'] ?? 0;
        topCourses = availableCourses.take(5).toList();
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        // Clear data on error
        userName = "";
        profileImageUrl = null;
        activeStudents = 0;
        activeCourses = 0;
        topCourses = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data. Please check your connection.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<int> _getUniqueActiveStudentsCount() async {
    try {
      List<Map<String, dynamic>> connections = await ConnectionService.getTutorConfirmedConnections(profileId);
      Set<String> uniqueStudentIds = {};
      for (var connection in connections) {
        if (connection['status']?.toString().toUpperCase() == 'CONFIRMED') {
          uniqueStudentIds.add(connection['studentId'].toString());
        }
      }
      return uniqueStudentIds.length;
    } catch (e) {
      return 0;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
  }

  void _showPendingPopup(String featureName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 56,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Account Under Review",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                featureName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "is not available while your account is pending approval.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Please wait for admin approval. You can edit your profile in the meantime.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Got it",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusBarConfig.setLightStatusBar();
    });

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String displayStudents = activeStudents.toString().padLeft(2, '0');
    final String displayCourses = activeCourses.toString().padLeft(2, '0');

    // PENDING STATE - No bottom navigation bar
    if (currentStatus == TutorStatus.pending) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),
                    _TopProfileRow(
                      greeting: _getGreeting(),
                      name: userName.isNotEmpty ? userName : "Tutor",
                      profileImageUrl: profileImageUrl,
                      isPending: true,
                      onPendingTap: _showPendingPopup,
                    ),
                    const SizedBox(height: 60),
                    _PendingReviewView(
                      onPendingTap: _showPendingPopup,
                      profileId: profileId,
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check for error state (no data)
    // Check for error state (no data)
    final bool hasNoData = userName.isEmpty && topCourses.isEmpty && activeStudents == 0 && activeCourses == 0;

    if (hasNoData) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Sliver
              SliverToBoxAdapter(
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.person, color: Colors.black54, size: 30),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  "Tutor",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                            child: const Icon(Icons.search, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                            child: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Centered Error Content Sliver
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Unable to load data",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Please check your internet connection",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Pull down to refresh",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _refreshDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Retry",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ACTIVE STATE - Full dashboard with bottom navigation
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCourseScreen()),
          );
          if (result == true) {
            _refreshDashboard();
          }
        },
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 35),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  _TopProfileRow(
                    greeting: _getGreeting(),
                    name: userName.isNotEmpty ? userName : "Tutor",
                    profileImageUrl: profileImageUrl,
                    isPending: false,
                    onPendingTap: _showPendingPopup,
                  ),
                  const SizedBox(height: 25),
                  _StatCardsGrid(students: displayStudents, courses: displayCourses),
                  const SizedBox(height: 35),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Activity Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _ActivityCenterRow(
                          isPending: false,
                          onPendingTap: _showPendingPopup,
                        ),
                        const SizedBox(height: 40),
                        _buildDynamicContent(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }

  Widget _buildDynamicContent() {
    if (topCourses.isEmpty) {
      return const _EmptyCoursesView();
    }
    return _ActiveCoursesListView(
      courses: topCourses,
      onCourseUpdated: _refreshDashboard,
      isPending: false,
      onPendingTap: _showPendingPopup,
    );
  }
}

// --- 3. STAT CARDS ---
class _StatCardsGrid extends StatelessWidget {
  final String students, courses;
  const _StatCardsGrid({required this.students, required this.courses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          _StatCard(
            count: students,
            label: "Active Students",
            colors: const [Color(0xFFE64D26), Color(0xFF8B2D17)],
          ),
          const SizedBox(width: 12),
          _StatCard(
            count: courses,
            label: "Active Courses",
            colors: const [Color(0xFF007EF2), Color(0xFF003D75)],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String count, label;
  final List<Color> colors;
  const _StatCard({required this.count, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// --- 4. COURSE CARD ---
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onCourseUpdated;
  final bool isPending;
  final Function(String) onPendingTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onCourseUpdated,
    required this.isPending,
    required this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (isPending) {
          onPendingTap("Course Details");
          return;
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              courseId: course.id,
              onCourseUpdated: onCourseUpdated,
            ),
          ),
        );
        if (result == true) {
          onCourseUpdated();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Opacity(
          opacity: isPending ? 0.6 : 1.0,
          child: Column(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: course.courseColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    height: 60,
                    width: 60,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.school,
                        size: 50,
                        color: Colors.white.withOpacity(0.8),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.tutorName.isNotEmpty ? course.tutorName : "Tutor",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            course.subject.isNotEmpty ? course.subject : "Course",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          course.grade.isNotEmpty ? course.grade : "Grade",
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          course.price.isNotEmpty ? course.price : "Rs 0",
                          style: const TextStyle(color: Color(0xFF0961F5), fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        _buildDivider(),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(" ${course.rating}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        _buildDivider(),
                        Text(
                          course.mode.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 18)),
  );
}

// --- 5. DYNAMIC VIEWS ---
class _ActiveCoursesListView extends StatelessWidget {
  final List<Course> courses;
  final VoidCallback onCourseUpdated;
  final bool isPending;
  final Function(String) onPendingTap;

  const _ActiveCoursesListView({
    required this.courses,
    required this.onCourseUpdated,
    required this.isPending,
    required this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Top Courses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ...courses.map((course) => CourseCard(
          course: course,
          onCourseUpdated: onCourseUpdated,
          isPending: isPending,
          onPendingTap: onPendingTap,
        )),
      ],
    );
  }
}

// --- PENDING REVIEW VIEW ---
class _PendingReviewView extends StatelessWidget {
  final Function(String) onPendingTap;
  final int profileId;

  const _PendingReviewView({
    required this.onPendingTap,
    required this.profileId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              size: 70,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "Account Under Review",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.orange.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Your account is currently being reviewed by our admin team.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "This process usually takes 24-48 hours.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 24, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "You can still edit your profile information while waiting for approval.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          profileId: profileId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Logout",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure you want to logout from your account?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _performLogout(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Logout", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      await AuthService.logout();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );
      }
    } catch (e) {
      print('Logout error: $e');
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Failed to logout. Please try again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("OK", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }
  }
}

class _EmptyCoursesView extends StatelessWidget {
  const _EmptyCoursesView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Top Courses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/cancel.png',
                height: 180,
                width: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.hourglass_empty, size: 100, color: Colors.grey.shade400);
                },
              ),
              const SizedBox(height: 20),
              const Text("No Courses Yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text("Tap the + button to add your first course", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

// --- TOP PROFILE ROW ---
class _TopProfileRow extends StatelessWidget {
  final String greeting, name;
  final String? profileImageUrl;
  final bool isPending;
  final Function(String) onPendingTap;

  const _TopProfileRow({
    required this.greeting,
    required this.name,
    this.profileImageUrl,
    required this.isPending,
    required this.onPendingTap,
  });

  String getFullImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                ? NetworkImage(getFullImageUrl(profileImageUrl))
                : null,
            child: profileImageUrl == null || profileImageUrl!.isEmpty
                ? const Icon(Icons.person, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  name.isNotEmpty ? name : "Tutor",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isPending
                ? () => onPendingTap("Search")
                : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
            child: Opacity(
              opacity: isPending ? 0.5 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                child: const Icon(Icons.search, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _NotificationBell(),
        ],
      ),
    );
  }
}

// --- ACTIVITY CENTER ROW ---
class _ActivityCenterRow extends StatelessWidget {
  final bool isPending;
  final Function(String) onPendingTap;

  const _ActivityCenterRow({
    required this.isPending,
    required this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActIcon(
          icon: Icons.person_outline,
          label: "Students",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentCategoryScreen())),
        ),
        _ActIcon(
          icon: Icons.book_outlined,
          label: "Courses",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CourseCategoryScreen())),
        ),
        _ActIcon(
          icon: Icons.gavel,
          label: "Bids",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBidsScreen())),
        ),
        _ActIcon(
          icon: Icons.star_border,
          label: "Reviews",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReviewsScreen())),
        ),
      ],
    );
  }
}

// ============================================================
// NOTIFICATION BELL WITH UNREAD BADGE
// ============================================================
// ============================================================
// NOTIFICATION BELL — LIVE + LISTENING TO PUSH UPDATES
// ============================================================
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell>
    with WidgetsBindingObserver {
  int _unread = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial fetch
    _refresh();

    // ✅ Instant updates when a push notification arrives
    NotificationService.instance.badgeNotifier.addListener(_onBadgeChanged);

    // Backup poll every 30s (catches anything FCM missed)
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    NotificationService.instance.badgeNotifier.removeListener(_onBadgeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _onBadgeChanged() {
    if (!mounted) return;
    final newCount = NotificationService.instance.badgeNotifier.value;
    if (newCount != _unread) {
      setState(() => _unread = newCount);
    }
  }

  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    if (userId == 0) return;
    try {
      final count = await NotificationApiService.getUnreadCount(userId);
      if (mounted && count != _unread) {
        setState(() => _unread = count);
        NotificationService.instance.badgeNotifier.value = count;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
        _refresh();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              color: Colors.white,
              size: 22,
            ),
          ),
          if (_unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActIcon({
    required this.icon,
    required this.label,
    this.onTap,
  });



  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}