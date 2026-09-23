import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'login_screen.dart';
import 'profile_creation_screen.dart';
import '../services/auth_service.dart';
import '../widgets/registration_deadline_banner.dart';

class TutorVerificationScreen extends StatefulWidget {
  final int userId;
  final DateTime? createdAt;
  final bool isResubmission;

  const TutorVerificationScreen({
    super.key,
    required this.userId,
    this.createdAt,
    this.isResubmission = false,   // ✅ default false
  });

  @override
  State<TutorVerificationScreen> createState() => _TutorVerificationScreenState();
}

class _TutorVerificationScreenState extends State<TutorVerificationScreen> {
  String? _idFileName;
  String? _degreeFileName;
  File? _idFile;
  File? _degreeFile;
  bool _showErrors = false;
  bool _isLoading = false;

  // ✅ NEW — previous rejection reason (only on re-submission)
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();

    // ✅ Only show deadline popup on FIRST upload
    if (!widget.isResubmission && widget.createdAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RegistrationDeadlinePopup.show(
          context,
          createdAt: widget.createdAt!,
        );
      });
    }

    // ✅ Fetch rejection reason for re-submissions
    if (widget.isResubmission) {
      _loadRejectionReason();
    }
  }

  Future<void> _loadRejectionReason() async {
    try {
      final docs = await AuthService.getDocumentsByUser(widget.userId);
      final reason = docs['rejectionReason'];
      if (mounted && reason != null && reason.toString().isNotEmpty) {
        setState(() => _rejectionReason = reason.toString());
      }
    } catch (e) {
      debugPrint('Failed to load rejection reason: $e');
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        if (type == "ID") {
          _idFileName = result.files.single.name;
          _idFile = File(result.files.single.path!);
        } else {
          _degreeFileName = result.files.single.name;
          _degreeFile = File(result.files.single.path!);
        }
      });
    }
  }

  void _showErrorPopup(String message) {
    String cleanMessage = message
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'[{}[\]"\\]'), '')
        .trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        content: Text(
          cleanMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDocuments() async {
    if (_idFile == null || _degreeFile == null) {
      setState(() => _showErrors = true);
      _showErrorPopup("Please upload both ID Card and Degree Certificate.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.uploadDocuments(
        widget.userId,
        _idFile!,
        _degreeFile!,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessPopup();

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorPopup(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---- Centered image ----
                Center(
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/success_user.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Centered heading ----
                Center(
                  child: Text(
                    widget.isResubmission
                        ? "Documents Resubmitted!"
                        : "Documents Submitted!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1B3E),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // ---- Centered body text ----
                Center(
                  child: Text(
                    widget.isResubmission
                        ? "Your new documents have been submitted. We'll review them and notify you once approved."
                        : "Your documents have been submitted successfully. We're reviewing them and will notify you once approved.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ---- Centered spinner ----
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D1B3E),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          // On re-submission, go back to login
                          if (widget.isResubmission) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                                  (route) => false,
                            );
                            return;
                          }
                          // On first-time, go back to profile creation
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileCreationScreen(
                                role: 'TUTOR',
                                userId: widget.userId,
                                createdAt: widget.createdAt,
                              ),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          backgroundColor: Colors.black,
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      Text(
                        widget.isResubmission
                            ? "Re-Upload Documents"
                            : "Verify Your Identity",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.isResubmission
                            ? "Your previous submission was rejected. Please review the reason below and upload corrected documents."
                            : "To maintain a safe and trusted learning environment, all tutors are required to complete identity verification before starting.",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      // ✅ Rejection reason banner
                      if (_rejectionReason != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Previous Submission Rejected",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _rejectionReason!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF78350F),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                      _buildUploadField(
                        label: _idFileName ?? "+ Identity Card (ID)",
                        onTap: () => _pickFile("ID"),
                        isUploaded: _idFileName != null,
                      ),
                      const SizedBox(height: 20),
                      _buildUploadField(
                        label: _degreeFileName ?? "+ Degree / Certificate",
                        onTap: () => _pickFile("Degree"),
                        isUploaded: _degreeFileName != null,
                      ),
                      const SizedBox(height: 100),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontFamily: 'sans-serif',
                              ),
                              children: [
                                const TextSpan(text: "By clicking Submit, you agree to our "),
                                TextSpan(
                                  text: "identity verification process",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const TextSpan(
                                  text: " and confirm that all provided information is correct and complete.",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isLoading ? null : _submitDocuments,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : Colors.black,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              widget.isResubmission
                                  ? "Resubmit"
                                  : "Submit",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadField({
    required String label,
    required VoidCallback onTap,
    required bool isUploaded,
  }) {
    Color borderColor = Colors.black.withOpacity(0.2);
    if (isUploaded) {
      borderColor = Colors.green;
    } else if (_showErrors) {
      borderColor = Colors.red;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: borderColor,
            width: (_showErrors && !isUploaded) ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: isUploaded ? Colors.black : (_showErrors ? Colors.red : Colors.grey),
                ),
              ),
            ),
            Icon(
              isUploaded ? Icons.check_circle : Icons.note_add_outlined,
              color: isUploaded ? Colors.green : (_showErrors ? Colors.red : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}