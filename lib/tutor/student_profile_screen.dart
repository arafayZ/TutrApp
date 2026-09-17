import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_details_screen.dart';
import '../services/connection_service.dart';
import '../config/api_config.dart';

// --- COURSE COLORS (Same as dashboard) ---
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

class StudentDetails {
  final String id;
  final String connectionId;
  final String name;
  final String profilePic;
  final String location;
  final String dob;
  final String gender;
  final String college;
  final String school;
  final String phone;
  final String email;

  StudentDetails({
    required this.id,
    required this.connectionId,
    required this.name,
    required this.profilePic,
    required this.location,
    required this.dob,
    required this.gender,
    required this.college,
    required this.school,
    required this.phone,
    required this.email,
  });
}

class StudentProfileScreen extends StatefulWidget {
  final StudentDetails student;
  final Function(String) onDisconnect;

  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.onDisconnect,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String? activeBtn;
  bool _isLoading = false;
  Map<String, dynamic>? _studentData;
  bool _isFetching = true;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _fetchStudentDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchStudentDetails() async {
    setState(() => _isFetching = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int tutorProfileId = prefs.getInt('profileId') ?? 0;

      final studentData = await ConnectionService.getStudentDetail(
        int.parse(widget.student.connectionId),
      );

      List<Map<String, dynamic>> allConnections =
      await ConnectionService.getTutorConfirmedConnections(tutorProfileId);

      List<Map<String, dynamic>> studentCourses = allConnections
          .where((conn) => conn['studentId'].toString() == widget.student.id)
          .toList();

      List<Map<String, dynamic>> courses = [];
      int courseIndex = 0;
      for (var conn in studentCourses) {
        int courseId = conn['courseId'] ?? courseIndex;
        courses.add({
          'courseId': courseId,
          'courseName': conn['courseName'] ?? conn['subject'] ?? 'Course',
          'agreedPrice': conn['agreedPrice'] ?? 0,
          'originalPrice': conn['originalPrice'] ?? 0,
          'connectionId': conn['connectionId'],
          'studentUserId': conn['studentUserId'],
        });
        courseIndex++;
      }

      setState(() {
        _studentData = studentData;
        _courses = courses;
        _isFetching = false;
      });
    } catch (e) {
      print('Error fetching student details: $e');
      setState(() => _isFetching = false);
    }
  }

  // ============================================================
  // ✅ DISCONNECT — now shows a course picker when > 1 course
  // ============================================================
  void _showDisconnectDialog() {
    // If no courses, nothing to disconnect
    if (_courses.isEmpty) {
      _showErrorDialog("No courses found for this student.");
      return;
    }

    // Only one course — go straight to confirmation
    if (_courses.length == 1) {
      final course = _courses[0];
      _confirmAndDisconnect(
        widget.student.name,
        course['connectionId'],
        course['courseName'] ?? 'Course',
      );
      return;
    }

    // Multiple courses — show picker
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            "Disconnect ${widget.student.name}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select which course to disconnect from:",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ..._courses.map((course) {
                final String courseName = course['courseName'] ?? 'Course';
                final int connectionId = course['connectionId'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _confirmAndDisconnect(
                          widget.student.name,
                          connectionId,
                          courseName,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.book_outlined,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courseName,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDisconnect(
      String studentName,
      int connectionId,
      String courseName,
      ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Disconnect Student",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to disconnect $studentName from \"$courseName\"?\n\nThis action cannot be undone.",
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              "Disconnect",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await ConnectionService.disconnect(
        connectionId,
        disconnectedBy: "TUTOR",
      );

      widget.onDisconnect(widget.student.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Disconnected from $courseName"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(
        "Failed to disconnect: ${e.toString().replaceFirst('Exception: ', '')}",
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  String _getFullImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  // ✅ Open chat with proper parameters
  void _openChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int tutorId = prefs.getInt('profileId') ?? 0;
    int tutorUserId = prefs.getInt('userId') ?? 0;

    String studentId = widget.student.id;

    // Try primary source
    int studentUserId = _studentData?['studentUserId'] ?? 0;

    // Fallback: get from courses list
    if (studentUserId == 0 && _courses.isNotEmpty) {
      studentUserId = _courses.first['studentUserId'] ?? 0;
    }

    // Fallback: refetch fresh from API
    if (studentUserId == 0) {
      try {
        final fresh = await ConnectionService.getStudentDetail(
          int.parse(widget.student.connectionId),
        );
        studentUserId = fresh['studentUserId'] ?? 0;
        print('🔍 Refetched studentUserId: $studentUserId');
      } catch (e) {
        print('❌ Refetch failed: $e');
      }
    }

    String displayName =
        _studentData?['studentName'] as String? ?? widget.student.name;
    String displayImage =
        _studentData?['studentImage'] as String? ?? widget.student.profilePic;
    int connectionId = int.parse(widget.student.connectionId);

    print('🔍 Chat open — studentUserId: $studentUserId, connectionId: $connectionId');

    if (studentUserId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open chat — student user ID missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorChatDetailsScreen(
          userName: displayName,
          userImage: displayImage,
          studentId: int.tryParse(studentId) ?? 0,
          studentUserId: studentUserId,
          tutorId: tutorId,
          tutorUserId: tutorUserId,
          connectionId: connectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String displayName =
        _studentData?['studentName'] as String? ?? widget.student.name;
    final String displayLocation =
        _studentData?['location'] as String? ?? widget.student.location;
    final String displayPhone =
        _studentData?['phoneNumber'] as String? ?? widget.student.phone;
    final String displayGender =
        _studentData?['gender'] as String? ?? widget.student.gender;
    final String displayEmail =
        _studentData?['studentEmail'] as String? ?? widget.student.email;
    final String displayImage =
        _studentData?['studentImage'] as String? ?? widget.student.profilePic;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(25, 85, 25, 25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => activeBtn = "message");
                                      _openChat();
                                    },
                                    child: _buildAdaptiveButton(
                                      label: "Message",
                                      id: "message",
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => activeBtn = "disconnect");
                                      _showDisconnectDialog();
                                    },
                                    child: _buildAdaptiveButton(
                                      label: "Disconnect",
                                      id: "disconnect",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),

                              _buildSectionHeader("Personal Details"),
                              _buildDetailRow(
                                Icons.location_on_outlined,
                                "Location",
                                displayLocation,
                              ),
                              _buildDetailRow(
                                Icons.person_outline,
                                "Gender",
                                displayGender,
                              ),
                              const SizedBox(height: 35),

                              _buildSectionHeader("Contact Info"),
                              _buildDetailRow(
                                Icons.phone_android_outlined,
                                "Phone",
                                displayPhone,
                              ),
                              _buildDetailRow(
                                Icons.mail_outline,
                                "Email",
                                displayEmail,
                              ),
                              const SizedBox(height: 35),

                              _buildSectionHeader("Enrolled Courses"),
                              _buildCoursesList(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Positioned(top: 15, child: _buildAvatar(65, displayImage)),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "No courses enrolled",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final String courseName = course['courseName'] ?? 'Unknown Course';
        final int agreedPrice = course['agreedPrice'] is double
            ? (course['agreedPrice'] as double).toInt()
            : (course['agreedPrice'] ?? 0);
        final int originalPrice = course['originalPrice'] is double
            ? (course['originalPrice'] as double).toInt()
            : (course['originalPrice'] ?? 0);

        final int courseId = course['courseId'] ?? index;
        final Color courseColor = CourseColors.getCourseColor(courseId);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: courseColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.school, color: Colors.white, size: 24);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text(
                          "Rs $agreedPrice",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (originalPrice > 0 && originalPrice != agreedPrice)
                          Text(
                            "Rs $originalPrice",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const Text(
            "Student Profile",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveButton({required String label, required String id}) {
    bool isSelected = activeBtn == id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.black : Colors.white,
        border: isSelected ? null : Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(30),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAvatar(double radius, String imgPath) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: imgPath.isNotEmpty
            ? NetworkImage(_getFullImageUrl(imgPath))
            : null,
        child: imgPath.isEmpty
            ? const Icon(Icons.person, size: 40, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}