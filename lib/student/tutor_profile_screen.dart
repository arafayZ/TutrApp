import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_details_screen.dart';
import 'block_tutor_screen.dart';
import 'chat_details_screen.dart';
import '../services/course_service.dart';
import '../services/report_block_service.dart';
import '../config/api_config.dart';
import 'student_dashboard.dart';

// --- COURSE COLORS (Same as other screens) ---
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

class TutorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> tutorData;

  const TutorProfileScreen({super.key, required this.tutorData});

  @override
  State<TutorProfileScreen> createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  bool showAbout = true;
  String selectedMode = "Online";
  final TextEditingController _reportDescriptionController =
  TextEditingController();
  bool _isSubmittingReport = false;

  // Report state
  String? selectedReportReason;      // display name, e.g. "Harassment"
  String? selectedReportReasonEnum;  // enum name, e.g. "HARASSMENT"
  final List<String> _evidenceUrls = [];
  bool _isUploadingEvidence = false;
  String? _reportInlineError;        // shown inside the report dialog

  // API Data
  List<Map<String, dynamic>> allCourses = [];
  List<Map<String, dynamic>> filteredCourses = [];
  bool _isLoading = true;
  int _studentId = 0;
  int _studentUserId = 0;
  int _tutorId = 0;
  int _tutorUserId = 0;
  bool _isTutorBlocked = false;

  // Tutor Profile Data
  Map<String, dynamic> _tutorProfile = {};
  String _tutorLocation = '';
  String _tutorHeadline = '';
  String _tutorName = '';
  String _tutorImage = '';
  String _universityName = '';
  String _collegeName = '';
  String _workExperience = '';
  String _dateOfBirth = '';
  String _gender = '';
  int _totalCourses = 0;
  int _totalStudents = 0;
  int _totalRatings = 0;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStudentId();
  }

  @override
  void dispose() {
    _reportDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentId = prefs.getInt('profileId') ?? 0;
      _studentUserId = prefs.getInt('userId') ?? 0;
      _tutorId = widget.tutorData['id'] ?? widget.tutorData['tutorId'] ?? 0;
    });

    print('🔍 Student: ID=$_studentId, UserID=$_studentUserId');
    print('🔍 Tutor: ID=$_tutorId');

    await Future.wait([
      _loadTutorProfile(),
      _checkBlockedStatus(),
    ]);
  }

  Future<void> _checkBlockedStatus() async {
    try {
      final isBlocked =
      await ReportBlockService.isTutorBlocked(_studentId, _tutorId);
      debugPrint('Tutor blocked status: $isBlocked');
      if (mounted) {
        setState(() {
          _isTutorBlocked = isBlocked;
        });
      }
    } catch (e) {
      debugPrint('Error checking blocked status: $e');
    }
  }

  Future<void> _loadTutorProfile() async {
    setState(() => _isLoading = true);

    try {
      final response =
      await CourseService.getTutorProfile(_studentId, _tutorId);

      if (!mounted) return;

      _processTutorProfile(response);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processTutorProfile(Map<String, dynamic> profile) {
    _tutorProfile = profile;
    _tutorName = profile['tutorName']?.toString() ??
        widget.tutorData['name'] ??
        'Tutor Name';
    _tutorHeadline = profile['tutorHeadline']?.toString() ??
        widget.tutorData['sub'] ??
        'Tutor';
    _tutorLocation = profile['tutorLocation']?.toString() ?? '';
    _tutorImage = profile['tutorImage']?.toString() ?? '';
    _universityName = profile['universityName']?.toString() ?? '';
    _collegeName = profile['collegeName']?.toString() ?? '';
    _workExperience = profile['workExperience']?.toString() ?? 'Not specified';
    _dateOfBirth = profile['dateOfBirth']?.toString() ?? '';
    _gender = profile['gender']?.toString() ?? '';
    _totalCourses = profile['totalCourses'] ?? 0;
    _totalStudents = profile['totalStudents'] ?? 0;
    _totalRatings = profile['totalRatings'] ?? 0;
    _averageRating = profile['averageRating']?.toDouble() ?? 0.0;

    _tutorUserId = profile['tutorUserId'] ?? 0;

    print('🔍 Tutor User ID from API: $_tutorUserId');

    final List<dynamic> courses = profile['courses'] ?? [];
    allCourses = _transformCoursesResponse(courses);
    _filterCoursesByMode();
  }

  void _filterCoursesByMode() {
    setState(() {
      filteredCourses =
          allCourses.where((c) => c['mode'] == selectedMode).toList();
    });
  }

  List<Map<String, dynamic>> _transformCoursesResponse(List<dynamic> courses) {
    return courses.map((course) {
      double priceValue = 0.0;
      if (course['price'] is int) {
        priceValue = (course['price'] as int).toDouble();
      } else if (course['price'] is double) {
        priceValue = course['price'] as double;
      } else if (course['price'] is String) {
        priceValue = double.tryParse(course['price']) ?? 0.0;
      }

      double ratingValue = 0.0;
      if (course['averageRating'] is int) {
        ratingValue = (course['averageRating'] as int).toDouble();
      } else if (course['averageRating'] is double) {
        ratingValue = course['averageRating'] as double;
      } else if (course['averageRating'] is String) {
        ratingValue = double.tryParse(course['averageRating']) ?? 0.0;
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

      String category = course['category']?.toString() ?? '';
      String categoryDisplay = _getCategoryDisplayName(category);
      Color badgeColor = _getCategoryBadgeColor(category);

      return {
        'id': course['courseId'] ?? course['id'] ?? 0,
        'title': course['subject']?.toString() ?? 'Course',
        'price': '${priceValue.toStringAsFixed(0)} PKR',
        'priceValue': priceValue,
        'level': categoryDisplay,
        'category': category,
        'badgeColor': badgeColor,
        'isLiked': course['isFavorited'] == true,
        'mode': teachingModeText,
        'tutorName': _tutorName,
        'location': course['location']?.toString() ?? _tutorLocation,
        'rating': ratingValue.toStringAsFixed(1),
        'ratingValue': ratingValue,
      };
    }).toList();
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toUpperCase()) {
      case 'MATRIC':
        return 'Matric';
      case 'INTERMEDIATE':
        return 'Intermediate';
      case 'O_LEVEL':
        return 'O Level';
      case 'A_LEVEL':
        return 'A Level';
      case 'ENTRY_TEST':
        return 'Entrance Test';
      default:
        return category;
    }
  }

  Color _getCategoryBadgeColor(String category) {
    switch (category.toUpperCase()) {
      case 'MATRIC':
        return Colors.orange.shade800;
      case 'INTERMEDIATE':
        return Colors.teal.shade800;
      case 'O_LEVEL':
        return Colors.blue.shade800;
      case 'A_LEVEL':
        return Colors.green.shade800;
      case 'ENTRY_TEST':
        return Colors.purple.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Future<void> _toggleFavorite(int indexInFiltered) async {
    if (indexInFiltered >= filteredCourses.length) return;

    final filteredCourse = filteredCourses[indexInFiltered];
    final int courseId = filteredCourse['id'];
    final String courseTitle = filteredCourse['title'];

    final int actualIndex = allCourses.indexWhere((c) => c['id'] == courseId);
    if (actualIndex == -1) return;

    final bool isCurrentlyLiked = allCourses[actualIndex]['isLiked'] == true;

    setState(() {
      allCourses[actualIndex]['isLiked'] = !isCurrentlyLiked;
      if (indexInFiltered < filteredCourses.length) {
        filteredCourses[indexInFiltered]['isLiked'] = !isCurrentlyLiked;
      }
    });

    try {
      if (!isCurrentlyLiked) {
        await CourseService.addToFavorites(_studentId, courseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$courseTitle added to favorites'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await CourseService.removeFromFavorites(_studentId, courseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$courseTitle removed from favorites'),
              backgroundColor: Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        allCourses[actualIndex]['isLiked'] = isCurrentlyLiked;
        if (indexInFiltered < filteredCourses.length) {
          filteredCourses[indexInFiltered]['isLiked'] = isCurrentlyLiked;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ============================================================
  // BLOCK
  // ============================================================
  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Block Tutor",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C43)),
          ),
          content: const Text(
            "Are you sure you want to block this tutor? You won't see their courses or receive messages from them.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL",
                  style: TextStyle(
                      color: Color(0xFF1A1C43), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _blockTutor();
              },
              child: const Text("BLOCK",
                  style:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockTutor() async {
    try {
      await ReportBlockService.blockTutor(_studentId, _tutorId);
      setState(() {
        _isTutorBlocked = true;
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BlockTutorScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showUnblockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Unblock Tutor",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C43)),
          ),
          content: const Text(
            "Are you sure you want to unblock this tutor? You will see their courses again.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL",
                  style: TextStyle(
                      color: Color(0xFF1A1C43), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _unblockTutor();
              },
              child: const Text("UNBLOCK",
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unblockTutor() async {
    try {
      await ReportBlockService.unblockTutor(_studentId, _tutorId);
      setState(() {
        _isTutorBlocked = false;
      });
      if (mounted) {
        _showSuccessPopupAndNavigate(context, "Tutor Unblocked",
            "This tutor will now appear in your searches.");
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSuccessPopupAndNavigate(
      BuildContext context, String title, String subtitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C43))),
              const SizedBox(height: 10),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                  const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const StudentDashboard()),
                          (route) => false,
                    );
                  },
                  child:
                  const Text("OK", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // REPORT — Inline error version
  // ============================================================
  void _showReportDialog(BuildContext context) {
    selectedReportReason = null;
    selectedReportReasonEnum = null;
    _reportDescriptionController.clear();
    _evidenceUrls.clear();
    _reportInlineError = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void setError(String? msg) {
              setDialogState(() => _reportInlineError = msg);
              if (mounted) setState(() => _reportInlineError = msg);
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Report Tutor",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C43),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Select a reason and describe what happened. "
                          "Our team will review it within 48 hours.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),

                    // ---- REASONS ----
                    _buildReportOption(
                        setDialogState, "Harassment", "HARASSMENT"),
                    _buildReportOption(setDialogState, "Abusive Language",
                        "ABUSIVE_LANGUAGE"),
                    _buildReportOption(
                        setDialogState, "Fraud or Scam", "FRAUD_OR_SCAM"),
                    _buildReportOption(setDialogState, "No-Show", "NO_SHOW"),
                    _buildReportOption(
                        setDialogState, "Poor Teaching", "POOR_TEACHING"),
                    _buildReportOption(setDialogState,
                        "Unprofessional Conduct", "UNPROFESSIONAL_CONDUCT"),
                    _buildReportOption(
                        setDialogState, "Fake Credentials", "FAKE_CREDENTIALS"),
                    _buildReportOption(setDialogState, "Payment Dispute",
                        "PAYMENT_DISPUTE"),
                    _buildReportOption(setDialogState, "Other", "OTHER"),

                    // ---- DESCRIPTION ----
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 15),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Details (min 10 characters)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _reportDescriptionController,
                        maxLines: 4,
                        maxLength: 1000,
                        onChanged: (_) {
                          if (_reportInlineError != null) setError(null);
                        },
                        decoration: const InputDecoration(
                          hintText: "Describe what happened...",
                          hintStyle:
                          TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                          counterText: "",
                        ),
                      ),
                    ),

                    // ---- EVIDENCE ----
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isUploadingEvidence
                              ? null
                              : () async {
                            final picked = await ImagePicker()
                                .pickMultiImage(imageQuality: 80);
                            if (picked.isEmpty) return;

                            for (final x in picked) {
                              setDialogState(() =>
                              _isUploadingEvidence = true);
                              try {
                                final url = await ReportBlockService
                                    .uploadReportEvidence(
                                    File(x.path), _studentId);
                                setDialogState(() {
                                  _evidenceUrls.add(url);
                                  _isUploadingEvidence = false;
                                });
                              } catch (e) {
                                setDialogState(
                                        () => _isUploadingEvidence = false);
                                setError(
                                    "Upload failed: ${e.toString().replaceFirst('Exception: ', '')}");
                              }
                            }
                          },
                          icon: const Icon(Icons.attach_file,
                              color: Color(0xFF1A1C43)),
                          tooltip: "Attach evidence",
                        ),
                        Expanded(
                          child: Text(
                            _evidenceUrls.isEmpty
                                ? "Attach evidence (optional)"
                                : "${_evidenceUrls.length} file${_evidenceUrls.length > 1 ? 's' : ''} attached",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        if (_isUploadingEvidence)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),

                    // ============================================================
                    // INLINE ERROR BOX
                    // ============================================================
                    if (_reportInlineError != null &&
                        _reportInlineError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            border: Border.all(
                                color: const Color(0xFFFCA5A5), width: 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _reportInlineError!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ---- BUTTONS ----
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(
                                color: Color(0xFF1A1C43),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isSubmittingReport ||
                                _isUploadingEvidence)
                                ? null
                                : () async {
                              // ---- Validate reason ----
                              if (selectedReportReason == null) {
                                setError(
                                    "Please select a reason for the report.");
                                return;
                              }

                              // ---- Validate description ----
                              final desc =
                              _reportDescriptionController.text
                                  .trim();
                              if (desc.length < 10) {
                                setError(
                                    "Please describe the issue in at least 10 characters.");
                                return;
                              }

                              // Clear previous error
                              setError(null);

                              setDialogState(
                                      () => _isSubmittingReport = true);
                              if (mounted) {
                                setState(() => _isSubmittingReport = true);
                              }

                              try {
                                await ReportBlockService.createReport(
                                  studentId: _studentId,
                                  tutorId: _tutorId,
                                  reason:
                                  selectedReportReasonEnum ?? 'OTHER',
                                  description: desc,
                                  evidenceUrls: _evidenceUrls,
                                );

                                setDialogState(
                                        () => _isSubmittingReport = false);
                                if (mounted) {
                                  setState(
                                          () => _isSubmittingReport = false);
                                }
                                Navigator.pop(dialogContext);

                                if (mounted) {
                                  _showSuccessPopup(
                                    context,
                                    "Report Submitted",
                                    "Thank you for letting us know. We will review this within 48 hours.",
                                    false,
                                  );
                                }
                              } catch (e) {
                                final msg = e
                                    .toString()
                                    .replaceFirst('Exception: ', '')
                                    .replaceFirst('Error: ', '')
                                    .trim();

                                setDialogState(
                                        () => _isSubmittingReport = false);
                                if (mounted) {
                                  setState(
                                          () => _isSubmittingReport = false);
                                }

                                // Friendly message for common cases
                                String friendly = msg;
                                final lower = msg.toLowerCase();
                                if (lower.contains('review') ||
                                    lower.contains('already') ||
                                    lower.contains('pending')) {
                                  friendly =
                                  "You have already reported this tutor."
                                      " You can submit another report for this tutor after 7 days.";
                                } else if (lower.contains('block')) {
                                  friendly =
                                  "You have blocked this tutor. Please unblock them before reporting.";
                                } else if (friendly.isEmpty) {
                                  friendly =
                                  "Something went wrong. Please try again.";
                                }

                                setError(friendly);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmittingReport
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                                : const Text(
                              "REPORT",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      },
    );
  }

  Widget _buildReportOption(
      StateSetter setDialogState, String displayName, String enumName) {
    return InkWell(
      onTap: () => setDialogState(() {
        selectedReportReason = displayName;
        selectedReportReasonEnum = enumName;
      }),
      child: Row(
        children: [
          Radio<String>(
            value: displayName,
            groupValue: selectedReportReason,
            activeColor: const Color(0xFF1A1C43),
            onChanged: (value) => setDialogState(() {
              selectedReportReason = value;
              selectedReportReasonEnum = enumName;
            }),
          ),
          Text(displayName,
              style:
              const TextStyle(fontSize: 14, color: Color(0xFF1A1C43))),
        ],
      ),
    );
  }

  void _showSuccessPopup(BuildContext context, String title, String subtitle,
      bool shouldExitProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C43))),
              const SizedBox(height: 10),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                  const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (shouldExitProfile) Navigator.pop(context);
                  },
                  child:
                  const Text("OK", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateOfBirth(String? dob) {
    if (dob == null || dob.isEmpty) return 'Not specified';
    final parts = dob.split('-');
    if (parts.length == 3) {
      final year = parts[0];
      final month = int.parse(parts[1]);
      final day = parts[2];
      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '$day ${monthNames[month - 1]} $year';
    }
    return dob;
  }

  void _navigateToChat() {
    if (_isTutorBlocked) {
      _showErrorDialog(
          "You have blocked this tutor. Unblock them to send messages.");
      return;
    }

    if (_tutorId == 0 || _studentId == 0 || _tutorUserId == 0) {
      _showErrorDialog("Unable to open chat. Please try again.");
      return;
    }

    print('🔍 Navigating to chat:');
    print('   Tutor: $_tutorName');
    print('   Tutor ID: $_tutorId');
    print('   Tutor User ID: $_tutorUserId');
    print('   Student ID: $_studentId');
    print('   Student User ID: $_studentUserId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentChatDetailsScreen(
          userName: _tutorName,
          userImage: _tutorImage.isNotEmpty ? _tutorImage : null,
          tutorId: _tutorId,
          tutorUserId: _tutorUserId,
          studentId: _studentId,
          studentUserId: _studentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildConsistentHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: Colors.black))
                : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildTopActions(),
                  _buildProfileIdentity(),
                  const SizedBox(height: 25),
                  _buildStatsSection(),
                  const SizedBox(height: 25),
                  _buildMessageButton(),
                  const SizedBox(height: 30),
                  _buildInfoCard(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistentHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(35),
            bottomRight: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Colors.black, shape: BoxShape.circle),
                child:
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
          ),
          const Text("Tutor Profile",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'Block') _showBlockDialog(context);
              if (value == 'Unblock') _showUnblockDialog(context);
              if (value == 'Report') _showReportDialog(context);
            },
            itemBuilder: (context) => [
              if (!_isTutorBlocked)
                const PopupMenuItem(
                    value: 'Block',
                    child: Row(children: [
                      Icon(Icons.block, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Block')
                    ])),
              if (_isTutorBlocked)
                const PopupMenuItem(
                    value: 'Unblock',
                    child: Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 10),
                      Text('Unblock')
                    ])),
              const PopupMenuItem(
                  value: 'Report',
                  child: Row(children: [
                    Icon(Icons.report_problem_outlined,
                        color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('Report')
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileIdentity() {
    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.black,
          backgroundImage: _tutorImage.isNotEmpty
              ? NetworkImage('${ApiConfig.baseUrl}$_tutorImage')
              : null,
          child: _tutorImage.isEmpty
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 15),
        Text(_tutorName,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        Text(_tutorHeadline,
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        if (_tutorLocation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_tutorLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(value: _totalCourses.toString(), label: "Courses"),
        _StatItem(value: _totalStudents.toString(), label: "Students"),
        _StatItem(value: _totalRatings.toString(), label: "Ratings"),
      ],
    );
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: _navigateToChat,
      child: Container(
        width: 160,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Center(
            child: Text("Message",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            children: [
              _buildMainTab(
                  "About", showAbout, () => setState(() => showAbout = true)),
              _buildMainTab("Courses", !showAbout,
                      () => setState(() => showAbout = false)),
            ],
          ),
          Padding(
              padding: const EdgeInsets.all(20),
              child: showAbout ? _buildAboutContent() : _buildCoursesContent()),
        ],
      ),
    );
  }

  Widget _buildMainTab(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.only(
              topLeft:
              title == "About" ? const Radius.circular(25) : Radius.zero,
              topRight:
              title == "Courses" ? const Radius.circular(25) : Radius.zero,
            ),
          ),
          child: Center(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black))),
        ),
      ),
    );
  }

  Widget _buildAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Personal Details",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 15),
        _buildAboutRow(Icons.location_on_outlined, "Location",
            _tutorLocation.isNotEmpty ? _tutorLocation : 'Not specified'),
        if (_dateOfBirth.isNotEmpty)
          _buildAboutRow(Icons.calendar_month_outlined, "Date of birth",
              _formatDateOfBirth(_dateOfBirth)),
        if (_gender.isNotEmpty)
          _buildAboutRow(Icons.wc_outlined, "Gender", _gender),
        const SizedBox(height: 25),
        const Text("Education",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 15),
        _buildAboutRow(Icons.school_outlined, "University",
            _universityName.isNotEmpty ? _universityName : 'Not specified'),
        _buildAboutRow(Icons.account_balance_outlined, "College",
            _collegeName.isNotEmpty ? _collegeName : 'Not specified'),
        const SizedBox(height: 25),
        const Text("Work Experience",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 15),
        _buildAboutRow(Icons.work_outline, "Experience", _workExperience),
      ],
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.black54),
          const SizedBox(width: 15),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black),
                children: [
                  TextSpan(
                      text: "$label: ",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                  TextSpan(
                      text: value, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesContent() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModeChip("Online"),
              const SizedBox(width: 10),
              _buildModeChip("Student's Home"),
              const SizedBox(width: 10),
              _buildModeChip("Tutor's Home"),
            ],
          ),
        ),
        const SizedBox(height: 25),
        if (filteredCourses.isEmpty)
          _buildEmptyStateView()
        else
          Column(
            children: filteredCourses.asMap().entries.map((entry) {
              int index = entry.key;
              var course = entry.value;
              return _buildCourseCard(course, index);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildModeChip(String title) {
    bool isSelected = selectedMode == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = title;
          _filterCoursesByMode();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateView() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD1D5DB), width: 8),
          ),
          child: const Icon(Icons.close, size: 80, color: Color(0xFFD1D5DB)),
        ),
        const SizedBox(height: 20),
        const Text(
          "No Courses Available",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        Text(
          "No ${selectedMode.toLowerCase()} courses available",
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    final int courseId = course['id'];
    final Color courseColor = CourseColors.getCourseColor(courseId);
    final bool isLiked = course['isLiked'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(
              courseData: {
                'id': courseId,
                'sub': course['title'],
                'price': course['price'],
                'category': course['level'],
                'color': courseColor,
                'tutorName': course['tutorName'],
                'rating': course['rating'],
                'totalRatings': 28,
                'location': course['location'],
                'teachingMode': course['mode'],
                'about':
                'This is an excellent ${course['title']} course taught by ${course['tutorName']}.',
                'classesPerMonth': '12',
                'fromDay': 'Monday',
                'toDay': 'Friday',
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 120,
              decoration: BoxDecoration(
                color: courseColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  height: 35,
                  width: 35,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      course['title'][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            course['tutorName'],
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFavorite(index),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: course['badgeColor'].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course['level'],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: course['badgeColor'],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['title'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          course['price'],
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: Colors.orange, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          course['rating'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          course['mode'] == 'Online'
                              ? Icons.wifi
                              : (course['mode'] == "Student's Home"
                              ? Icons.home
                              : Icons.location_city),
                          size: 9,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            course['location'],
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stat Item Widget
class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A1C43))),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}