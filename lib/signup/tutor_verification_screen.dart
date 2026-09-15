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

  const TutorVerificationScreen({
    super.key,
    required this.userId,
    this.createdAt,
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

  @override
  void initState() {
    super.initState();

    //  Show the registration deadline popup once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.createdAt != null) {
        RegistrationDeadlinePopup.show(
          context,
          createdAt: widget.createdAt,
        );
      }
    });
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                const SizedBox(height: 20),
                const Text(
                  "Documents Submitted!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Your documents have been submitted successfully. We're reviewing them and will notify you once approved.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(color: Color(0xFF0D1B3E)),
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
              // Header with shadow
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  // Added shadow
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
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileCreationScreen(
                                role: 'TUTOR',
                                userId: widget.userId,
                                createdAt: widget.createdAt, // 👈 pass back so it stays consistent
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

                      const Text(
                        "Verify Your Identity",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "To maintain a safe and trusted learning environment, all tutors are required to complete identity verification before starting.",
                        style: TextStyle(color: Colors.grey),
                      ),
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
                                : const Text(
                              "Submit",
                              style: TextStyle(
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