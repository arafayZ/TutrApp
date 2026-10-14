import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/rating_service.dart';
import '../config/api_config.dart';

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

class WriteReviewScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;

  const WriteReviewScreen({super.key, required this.courseData});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 5;
  final TextEditingController _reviewController = TextEditingController();
  final int _maxCharacters = 100;
  bool _isSubmitting = false;
  String? _reviewError;
  int _studentId = 0;
  int _courseId = 0;

  // Course details from widget.courseData
  String _tutorName = '';
  String _courseTitle = '';
  String _tutorImage = '';
  Color _courseColor = const Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _loadStudentId();
    _loadCourseData();
  }

  void _loadCourseData() {
    final tutorName = widget.courseData['tutorName'] ??
        widget.courseData['name'] ??
        'Tutor Name';

    final courseTitle = widget.courseData['subject'] ??
        widget.courseData['sub'] ??
        widget.courseData['title'] ??
        widget.courseData['courseSubject'] ??
        'Course Title';

    final tutorImage = widget.courseData['tutorImage'] ??
        widget.courseData['profilePictureUrl'] ??
        '';

    setState(() {
      _tutorName = tutorName;
      _courseTitle = courseTitle;
      _tutorImage = tutorImage;
    });
  }

  Future<void> _loadStudentId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentId = prefs.getInt('profileId') ?? 0;
      _courseId = widget.courseData['id'] ?? widget.courseData['courseId'] ?? 0;
      _courseColor = CourseColors.getCourseColor(_courseId);
    });
  }

  Future<void> _submitReview() async {
    final String reviewText = _reviewController.text.trim();

    if (reviewText.isEmpty) {
      setState(() {
        _reviewError = "Please enter your review";
      });
      return;
    }

    setState(() {
      _reviewError = null;
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final result = await RatingService.submitRating(
        studentId: _studentId,
        courseId: _courseId,
        rating: _rating,
        review: reviewText,
      );

      if (mounted) {
        _showReviewSuccessPopup(context);
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final rawMessage = e.toString().replaceFirst('Exception: ', '').trim();
      final lower = rawMessage.toLowerCase();

      //  Connection-related failures → snackbar (not dialog)
      final isConnectionError = lower.contains('connected with') ||
          lower.contains('connection') ||
          lower.contains('confirmed or completed');

      if (isConnectionError) {
        _showConnectionSnackBar(
          'You can only review a tutor you have connected with.',
        );
      } else {
        _showErrorDialog(rawMessage);
      }
    }
  }

  void _showConnectionSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
              child: const Text("OK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewSuccessPopup(BuildContext context) {
    if (Navigator.canPop(context)) {
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            if (mounted) {
              Navigator.pop(context, true);
            }
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22AD19),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 60),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Review Submitted",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C43),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Thank you for your feedback!\nYour review helps others learn better.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      //  Reset submitting state after dialog closes
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    });
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(context),
          // Fixed Course Card Section (does NOT scroll)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildTutorCard(),
                const SizedBox(height: 30),
              ],
            ),
          ),
          // Scrollable Content (Rating, Review Field)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Rating ($_rating/5)",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C43),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildStarRating(),
                  const SizedBox(height: 40),
                  const Text(
                    "Write your Review",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C43),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildReviewTextField(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          // ✅ Fixed Submit Button at Bottom (does NOT scroll)
          Container(
            padding: EdgeInsets.fromLTRB(25, 12, 25, bottomPadding + 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _buildSubmitButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
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
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const Text(
            "Write a Review",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C43),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: _courseColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                'assets/icon/app_icon.png',
                height: 45,
                width: 45,
                color: Colors.white,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.school,
                    size: 40,
                    color: Colors.white.withOpacity(0.8),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tutorName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _courseTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C43),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => setState(() => _rating = index + 1),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.star_rounded,
              size: 50,
              color: index < _rating ? Colors.amber : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReviewTextField() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: _reviewError != null
            ? Border.all(color: Colors.red, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _reviewController,
            maxLines: 5,
            onChanged: (value) {
              setState(() {
                if (_reviewError != null) {
                  _reviewError = null;
                }
              });
            },
            maxLength: _maxCharacters,
            decoration: InputDecoration(
              hintText: "Would you like to write anything about this Course?",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              counterText: "",
              errorText: _reviewError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          Text(
            "${_maxCharacters - _reviewController.text.length} characters remaining",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitReview,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: _isSubmitting ? Colors.grey : Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Center(
          child: Text(
            _isSubmitting ? "Submitting..." : "Submit Review",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}