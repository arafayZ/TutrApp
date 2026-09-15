import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Imports for your existing screens and widgets ---
import '../services/favorite_refresh_service.dart';
import '../services/connection_refresh_service.dart';
import '../services/dashboard_service.dart';
import '../services/course_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import '../tutor/inbox_screen.dart';
import '../widgets/student_bottom_nav.dart';
import 'search_screen.dart';
import 'connection_screen.dart';
import 'notification_screen.dart';
import 'inbox_screen.dart';
import 'top_tutors_screen.dart';
import 'matric_screen.dart';
import 'intermediate_screen.dart';
import 'o_a_level_screen.dart';
import 'entrance_test_screen.dart';
import 'profile_screen.dart';
import 'favourites_screen.dart';
import '../utils/status_bar_config.dart';
import 'course_details_screen.dart';
import 'tutor_profile_screen.dart';
import '../config/api_config.dart';
import 'notification_screen.dart';

// --- Helper function to get category badge colors ---
Map<String, Color> getCategoryBadgeColors(String level) {
  switch (level.toLowerCase()) {
    case 'matric':
      return {'bg': Colors.orange.shade100, 'text': Colors.orange.shade800};
    case 'intermediate':
      return {'bg': Colors.teal.shade100, 'text': Colors.teal.shade800};
    case 'o level':
      return {'bg': Colors.blue.shade100, 'text': Colors.blue.shade800};
    case 'a level':
      return {'bg': Colors.green.shade100, 'text': Colors.green.shade800};
    case 'entrance test':
      return {'bg': Colors.purple.shade100, 'text': Colors.purple.shade800};
    default:
      return {'bg': Colors.grey.shade100, 'text': Colors.grey.shade800};
  }
}

// --- COURSE COLORS ---
class CourseColors {
  static const List<Color> colors = [
    Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460),
    Color(0xFF8B1E3F), Color(0xFF2C3E50), Color(0xFF1B4F72),
    Color(0xFF145A32), Color(0xFF7B2C3E), Color(0xFF4A235A),
    Color(0xFF1C2833), Color(0xFF6E2C00), Color(0xFF0B5345),
    Color(0xFF424949), Color(0xFF5D4037), Color(0xFF283747),
    Color(0xFF7E5109), Color(0xFF4A4A4A), Color(0xFF3E2723),
    Color(0xFF1A237E),
  ];

  static Color getCourseColor(int courseId) {
    return colors[courseId % colors.length];
  }
}

// --- DATA MODELS ---
class Tutor {
  final int id;
  final String name;
  final String? profilePic;
  final String subject;
  final String rating;
  final String location;

  Tutor({
    required this.id,
    required this.name,
    this.profilePic,
    this.subject = "Mathematics",
    this.rating = "4.8",
    this.location = "Online",
  });
}

class Course {
  final int id;
  final String tutorName;
  final String subject;
  final String level;
  final String price;
  final String rating;
  final String mode;
  final String location;
  final Color themeColor;
  final int tutorId;
  final String tutorImage;
  final double priceValue;
  bool isFavorited;

  Course({
    required this.id,
    required this.tutorName,
    required this.subject,
    required this.level,
    required this.price,
    required this.rating,
    required this.mode,
    required this.location,
    required this.themeColor,
    required this.tutorId,
    required this.tutorImage,
    required this.priceValue,
    this.isFavorited = false,
  });
}

// --- MAIN DASHBOARD ---
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _studentId = 0;
  String _studentName = "";
  String _studentImage = "";

  // API Data
  List<Tutor> _topTutors = [];
  List<Course> _recommendedCourses = [];
  bool _isLoading = true;
  bool _useApi = true;
  bool _isFirstLoad = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    StatusBarConfig.setLightStatusBar();
    WidgetsBinding.instance.addObserver(this);
    _loadStudentId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    StatusBarConfig.resetStatusBar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstLoad && !_isLoading) {
      _refreshData();
    }
  }

  Future<void> _loadStudentId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentId = prefs.getInt('profileId') ?? 0;
    });
    await _loadDashboardData();
    _isFirstLoad = false;
  }

  Future<void> _refreshData() async {
    if (!_isLoading) {
      await _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_studentId != 0 && _useApi) {
        final response = await DashboardService.getStudentDashboard(_studentId);
        if (!mounted) return;
        _processDashboardData(response);
      } else {
        _showEmptyState();
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      _showEmptyState();
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEmptyState() {
    _studentName = "";
    _studentImage = "";
    _topTutors = [];
    _recommendedCourses = [];
  }

  void _processDashboardData(Map<String, dynamic> data) {
    _studentName = data['studentName'] ?? '';
    _studentImage = data['studentImage'] ?? '';

    final List<dynamic> topTutorsList = data['topTutors'] ?? [];
    _topTutors = topTutorsList.map((tutor) {
      String? imageUrl = tutor['tutorImage']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        imageUrl = '${ApiConfig.baseUrl}$imageUrl';
      }
      return Tutor(
        id: tutor['tutorId'] ?? 0,
        name: tutor['tutorName'] ?? '',
        subject: tutor['topSubjects']?.isNotEmpty == true ? tutor['topSubjects'][0] : '',
        rating: tutor['averageRating']?.toString() ?? '0.0',
        location: tutor['location'] ?? '',
        profilePic: imageUrl,
      );
    }).toList();

    final List<dynamic> coursesList = data['recommendedCourses'] ?? [];
    _recommendedCourses = coursesList.map((course) {
      double priceValue = 0.0;
      if (course['price'] is int) {
        priceValue = (course['price'] as int).toDouble();
      } else if (course['price'] is double) {
        priceValue = course['price'] as double;
      }

      double ratingValue = 0.0;
      if (course['averageRating'] is int) {
        ratingValue = (course['averageRating'] as int).toDouble();
      } else if (course['averageRating'] is double) {
        ratingValue = course['averageRating'] as double;
      }

      String teachingModeText = 'Online';
      String teachingMode = course['teachingMode']?.toString() ?? '';
      if (teachingMode == 'ONLINE') {
        teachingModeText = 'Online';
      } else if (teachingMode == 'STUDENT_HOME') {
        teachingModeText = "Student's Home";
      } else if (teachingMode == 'TUTOR_HOME') {
        teachingModeText = "Tutor's Home";
      }

      String category = course['category']?.toString() ?? 'General';
      String levelDisplay = _getCategoryDisplayName(category);

      return Course(
        id: course['courseId'] ?? 0,
        tutorName: course['tutorName'] ?? '',
        subject: course['subject'] ?? '',
        level: levelDisplay,
        price: priceValue > 0 ? '${priceValue.toStringAsFixed(0)} PKR' : '',
        rating: ratingValue.toStringAsFixed(1),
        mode: teachingModeText,
        location: course['location'] ?? '',
        themeColor: CourseColors.getCourseColor(course['courseId'] ?? 0),
        tutorId: course['tutorId'] ?? 0,
        tutorImage: '',
        priceValue: priceValue,
        isFavorited: course['isFavorited'] == true,
      );
    }).toList();
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toUpperCase()) {
      case 'MATRIC': return 'Matric';
      case 'INTERMEDIATE': return 'Intermediate';
      case 'O_LEVEL': return 'O Level';
      case 'A_LEVEL': return 'A Level';
      case 'ENTRY_TEST': return 'Entrance Test';
      default: return category;
    }
  }

  Future<void> _toggleFavorite(Course course, int index) async {
    final bool newFavStatus = !course.isFavorited;

    setState(() {
      _recommendedCourses[index].isFavorited = newFavStatus;
    });

    try {
      if (newFavStatus) {
        await CourseService.addToFavorites(_studentId, course.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${course.subject} added to favorites'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
        );
      } else {
        await CourseService.removeFromFavorites(_studentId, course.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${course.subject} removed from favorites'), backgroundColor: Colors.grey, duration: const Duration(seconds: 2)),
        );
      }
      FavoriteRefreshService().notifyRefresh();
    } catch (e) {
      setState(() {
        _recommendedCourses[index].isFavorited = !newFavStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites'), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If not on home tab (index 0), go to home tab
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false; // Don't close app, just went to home
        }
        // If already on home tab, let the system handle back button
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeContent(),
            const ConnectionScreen(),
            const StudentInboxScreen(),
            const FavouritesScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: StudentBottomNav(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 1) {
              ConnectionRefreshService().notifyRefresh();
            }
            if (index == 3) {
              FavoriteRefreshService().notifyRefresh();
            }
            if (index == 0 && !_isFirstLoad && !_isLoading) {
              _refreshData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading && _isFirstLoad) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    // Check if there's no data (server error or empty response)
    final bool hasNoData = _topTutors.isEmpty && _recommendedCourses.isEmpty && _studentName.isEmpty;

    if (hasNoData && !_isLoading) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.black,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _HeaderSection(
                greeting: _getGreeting(),
                name: "Student",
                profileImage: "",
              ),
              const SizedBox(height: 50),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Unable to load data",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please check your internet connection\nand pull down to refresh",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Retry",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    }

    final bool showSeeAll = _topTutors.length > 4;
    final displayTutors = showSeeAll ? _topTutors.sublist(0, 4) : _topTutors;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.black,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _HeaderSection(
              greeting: _getGreeting(),
              name: _studentName.isNotEmpty ? _studentName : "Student",
              profileImage: _studentImage,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  const _PromoSlider(),
                  const SizedBox(height: 30),
                  const _CategorySelector(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Top Tutor", showSeeAll: showSeeAll && _topTutors.isNotEmpty),
                  const SizedBox(height: 15),
                  _TopTutorsList(tutors: displayTutors),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Recommended Courses", showSeeAll: false),
                  const SizedBox(height: 15),
                  _RecommendedCoursesList(
                    courses: _recommendedCourses,
                    studentId: _studentId,
                    onFavoriteToggle: _toggleFavorite,
                  ),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool showSeeAll = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (showSeeAll)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TopTutorsScreen()));
              },
              child: const Row(
                children: [
                  Text("SEE ALL ", style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold, fontSize: 10)),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2979FF)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// --- HEADER SECTION WITH UPDATED NOTIFICATION NAVIGATION ---
class _HeaderSection extends StatelessWidget {
  final String greeting, name;
  final String profileImage;

  const _HeaderSection({
    required this.greeting,
    required this.name,
    this.profileImage = '',
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 35),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage: profileImage.isNotEmpty
                    ? NetworkImage('${ApiConfig.baseUrl}$profileImage')
                    : null,
                child: profileImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.black54, size: 26)
                    : null,
              ),
              const Spacer(),
              _HeaderActionBtn(
                icon: Icons.search,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SearchScreen())),
              ),
              const SizedBox(width: 12),
              const _StudentNotificationBell(),
            ],
          ),
          const SizedBox(height: 20),
          Text(greeting, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HeaderActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderActionBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _PromoSlider extends StatefulWidget {
  const _PromoSlider();

  @override
  State<_PromoSlider> createState() => _PromoSliderState();
}

class _PromoSliderState extends State<_PromoSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> ads = [
    {"title": "Today's Special", "subtitle": "25% OFF*", "desc": "Get a Discount for Every Course Order only Valid for Today!", "colors": [const Color(0xFF2979FF), const Color(0xFF0D47A1)]},
    {"title": "Flash Sale", "subtitle": "50% OFF", "desc": "Join our premium Mathematics masterclass at half price!", "colors": [const Color(0xFFFF5252), const Color(0xFFB71C1C)]},
    {"title": "New Arrival", "subtitle": "FREE DEMO", "desc": "Check out our new Physics laboratory sessions starting this week.", "colors": [const Color(0xFF00BFA5), const Color(0xFF004D40)]},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              return Container(
                width: MediaQuery.of(context).size.width - 40,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: LinearGradient(
                    colors: ads[index]['colors'],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ads[index]['subtitle'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(ads[index]['title'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(ads[index]['desc'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(ads.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 5),
            width: _currentPage == i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentPage == i ? Colors.amber : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
            ),
          )),
        ),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {"name": "Matric", "screen": const MatricScreen()},
      {"name": "Intermediate", "screen": const IntermediateScreen()},
      {"name": "O & A Level", "screen": const OALevelScreen()},
      {"name": "Entrance Test", "screen": const EntranceTestScreen()},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categories", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(
          height: 35,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => categories[i]['screen']),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 25),
                  child: Text(
                    categories[i]['name'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STUDENT NOTIFICATION BELL (with unread badge)
// ============================================================
class _StudentNotificationBell extends StatefulWidget {
  const _StudentNotificationBell();

  @override
  State<_StudentNotificationBell> createState() =>
      _StudentNotificationBellState();
}

class _StudentNotificationBellState extends State<_StudentNotificationBell>
    with WidgetsBindingObserver {
  int _unread = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial fetch
    _refresh();

    // ✅ Listen for instant badge updates from NotificationService
    NotificationService.instance.badgeNotifier.addListener(_onBadgeChanged);

    // Backup poll every 30s
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
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        );
        _refresh();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              color: Colors.white,
              size: 21,
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

class _TopTutorsList extends StatelessWidget {
  final List<Tutor> tutors;
  const _TopTutorsList({required this.tutors});

  @override
  Widget build(BuildContext context) {
    if (tutors.isEmpty) {
      return Container(
        height: 110,
        decoration: BoxDecoration(color: Colors.transparent),
        child: Center(
          child: Text(
            "No tutors available",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tutors.length,
        itemBuilder: (context, i) {
          final tutor = tutors[i];
          return GestureDetector(
            onTap: () {
              final tutorData = {
                'id': tutor.id,
                'tutorId': tutor.id,
                'name': tutor.name,
                'sub': tutor.subject,
                'rating': tutor.rating,
                'location': tutor.location,
                'tutorImage': tutor.profilePic?.replaceFirst(ApiConfig.baseUrl, ''),
              };
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TutorProfileScreen(tutorData: tutorData)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(18),
                      image: tutor.profilePic != null && tutor.profilePic!.isNotEmpty
                          ? DecorationImage(image: NetworkImage(tutor.profilePic!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (tutor.profilePic == null || tutor.profilePic!.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tutor.name.isNotEmpty ? tutor.name : "Tutor",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- RECOMMENDED COURSES LIST ---
class _RecommendedCoursesList extends StatefulWidget {
  final List<Course> courses;
  final int studentId;
  final Function(Course, int) onFavoriteToggle;

  const _RecommendedCoursesList({
    required this.courses,
    required this.studentId,
    required this.onFavoriteToggle,
  });

  @override
  State<_RecommendedCoursesList> createState() => _RecommendedCoursesListState();
}



class _RecommendedCoursesListState extends State<_RecommendedCoursesList> {
  late List<Course> courses;

  @override
  void initState() {
    super.initState();
    courses = widget.courses.map((c) => c).toList();
  }


  @override
  void didUpdateWidget(covariant _RecommendedCoursesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courses != widget.courses) {
      courses = widget.courses.map((c) => c).toList();
    }
  }



  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text("No Courses Available", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              SizedBox(height: 8),
              Text("Check back later for new courses", style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(courses.length, (index) {
        final course = courses[index];
        final badgeColors = getCategoryBadgeColors(course.level);

        return GestureDetector(
          onTap: () {
            final courseData = {
              'id': course.id,
              'courseId': course.id,
              'tutorName': course.tutorName,
              'name': course.tutorName,
              'sub': course.subject,
              'title': course.subject,
              'category': course.level,
              'price': course.price,
              'rating': course.rating,
              'totalRatings': '28',
              'location': course.location,
              'teachingMode': course.mode,
              'about': 'Master ${course.subject} concepts with step-by-step guidance!',
              'classesPerMonth': 20,
              'startTime': '6:00 PM',
              'endTime': '8:00 PM',
              'fromDay': 'Monday',
              'toDay': 'Friday',
              'isFavorited': course.isFavorited,
              'tutorImage': course.tutorImage,
              'priceValue': course.priceValue,
            };
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CourseDetailsScreen(courseData: courseData)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: course.themeColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          height: 60,
                          width: 60,
                          color: Colors.white,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.school, size: 50, color: Colors.white.withOpacity(0.8));
                          },
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => widget.onFavoriteToggle(course, index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                            child: Icon(
                              course.isFavorited ? Icons.favorite : Icons.favorite_border,
                              color: course.isFavorited ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.tutorName.isNotEmpty ? course.tutorName : "Tutor",
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: badgeColors['bg'], borderRadius: BorderRadius.circular(12)),
                            child: Text(course.level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColors['text'])),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(course.price.isNotEmpty ? course.price : "0 PKR", style: const TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold, fontSize: 15)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 16))),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(" ${course.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("|", style: TextStyle(color: Colors.grey, fontSize: 16))),
                          Icon(course.mode == 'Online' ? Icons.wifi : course.mode == "Tutor's Home" ? Icons.location_city : Icons.home, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(course.mode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(course.location.isNotEmpty ? course.location : "Location", style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }
}