import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import '../tutor/tutor_dashboard.dart';
import '../student/student_dashboard.dart';
import 'forgot_password_screen.dart';
import 'profile_creation_screen.dart';
import 'tutor_verification_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscureText = true;
  bool _showErrors = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLogoutReason();
    });
  }

  Future<void> _checkLogoutReason() async {
    final prefs = await SharedPreferences.getInstance();
    final reason = prefs.getString('logout_reason');
    if (reason == null || reason.isEmpty) return;

    await prefs.remove('logout_reason');

    if (!mounted) return;

    final lower = reason.toLowerCase();

    if (lower.contains('permanently disabled') || lower.contains('banned')) {
      _showInfoDialog(
        title: "Account Permanently Disabled",
        message: reason,
        icon: Icons.block,
        iconColor: Colors.red,
      );
    } else if (lower.contains('suspended')) {
      _showInfoDialog(
        title: "Account Suspended",
        message: reason,
        icon: Icons.block,
        iconColor: Colors.red,
      );
    } else if (lower.contains('verification') || lower.contains('rejected')) {
      _showInfoDialog(
        title: "Documents Rejected",
        message: reason,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
      );
    } else {
      _showErrorPopup(reason);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  Future<void> _validateAndLogin() async {
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _showErrors = true);
      _showErrorPopup("Please enter your email and password to sign in.");
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _showErrors = true);
      _showErrorPopup("Please enter a valid email address.");
      return;
    }

    setState(() {
      _showErrors = false;
      _isLoading = true;
    });

    try {
      final userData = await AuthService.login(email, password);

      if (!mounted) return;

      // ✅ Save user data to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', userData['id']);
      await prefs.setInt('profileId', userData['profileId']);
      await prefs.setString('role', userData['role']);
      await prefs.setString('accountStatus', userData['accountStatus']);
      await prefs.setInt('registrationStep', userData['registrationStep']);

      // ✅ Save email for later use
      await prefs.setString('email', userData['email']);

      // ✅ Save createdAt for later use in dashboards (if backend provides it)
      if (userData['createdAt'] != null) {
        await prefs.setString('createdAt', userData['createdAt'].toString());
      }

      // ✅ Register this device for push notifications
      try {
        await NotificationService.instance.registerToken(userData['id']);
      } catch (e) {
        debugPrint('⚠️ Token registration failed: $e');
      }

      // ✅ For PENDING accounts, we'll fetch name from profile API in dashboard
      // No need to save name here as login response doesn't have it

      setState(() => _isLoading = false);

      // ✅ For PENDING tutor accounts, still navigate to dashboard
      // Dashboard will handle showing pending screen
      if (userData['role'] == 'TUTOR') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TutorDashboard()),
              (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const StudentDashboard()),
              (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMsg = e.toString();
      errorMsg = errorMsg.replaceFirst('Exception: ', '');
      errorMsg = errorMsg.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

      _handleErrorWithNavigation(errorMsg);
    }
  }

  void _handleErrorWithNavigation(String errorMsg) async {
    String lowerMsg = errorMsg.toLowerCase();

    // First check for invalid credentials - don't call getUserByEmail
    if (lowerMsg.contains('invalid') || lowerMsg.contains('incorrect')) {
      _showErrorPopup("Invalid email or password. Please try again.");
      return;
    }

    // Get email from login form
    String email = _emailController.text.trim();

    // Show loading indicator while fetching user
    setState(() => _isLoading = true);

    // Fetch userId, role, AND createdAt from backend using email
    int userId = 0;
    String userRole = "";
    DateTime? createdAt;
    try {
      final userData = await AuthService.getUserByEmail(email);
      userId = userData['id'] ?? 0;
      userRole = userData['role'] ?? "";

      //  Parse createdAt from backend
      createdAt = userData['createdAt'] != null
          ? DateTime.tryParse(userData['createdAt'].toString())
          : null;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      // If we can't fetch user info, show the original error
      _showErrorPopup(errorMsg);
      return;
    }

    // Check if it's a profile completion error
    if (lowerMsg.contains('profile') && lowerMsg.contains('complete')) {
      if (userRole == 'TUTOR') {
        _showActionDialog(
          title: "Complete Your Tutor Profile",
          message: errorMsg,
          buttonText: "Complete Profile",
          destination: ProfileCreationScreen(
            role: 'TUTOR',
            userId: userId,
            createdAt: createdAt,
          ),
        );
      } else {
        _showActionDialog(
          title: "Complete Your Student Profile",
          message: errorMsg,
          buttonText: "Complete Profile",
          destination: ProfileCreationScreen(
            role: 'STUDENT',
            userId: userId,
            createdAt: createdAt,
          ),
        );
      }
    }
    // Verification Documents Required (Tutor only)
    else if (lowerMsg.contains('verification') || lowerMsg.contains('documents')) {
      if (userRole == 'TUTOR') {
        // ✅ If a rejection reason exists, it's a re-submission
        final isResubmission = lowerMsg.contains('rejected');
        _showActionDialog(
          title: isResubmission ? "Documents Rejected" : "Verification Required",
          message: errorMsg,
          buttonText: isResubmission ? "Re-Upload Documents" : "Upload Documents",
          destination: TutorVerificationScreen(
            userId: userId,
            createdAt: createdAt,
            isResubmission: isResubmission,   // ✅ NEW
          ),
        );
      } else {
        _showErrorPopup(errorMsg);
      }
    }
    // Account Pending Approval
    else if (lowerMsg.contains('pending') || lowerMsg.contains('approval')) {
      _showInfoDialog(
        title: "Account Under Review",
        message: errorMsg,
        icon: Icons.hourglass_empty,
      );
    }
    // Account Blocked
    // Account Blocked / Suspended
    else if (lowerMsg.contains('blocked') ||
        lowerMsg.contains('disabled') ||
        lowerMsg.contains('suspended')) {
      _showInfoDialog(
        title: "Account Suspended",
        message: errorMsg,
        icon: Icons.block,
        iconColor: Colors.red,
      );
    }
    // Default Error
    else {
      _showErrorPopup(errorMsg);
    }
  }

  void _showActionDialog({
    required String title,
    required String message,
    required String buttonText,
    required Widget destination,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = Colors.orange,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            //  Only show for Account Under Review
            if (title == "Account Under Review") ...[
              const SizedBox(height: 12),
              const Text(
                "You will be notified once your account is approved.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
        surfaceTintColor: Colors.white,
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
          TextButton(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Text(
                "Welcome back",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "sign in to access your account",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 60),

              _buildInputField(
                controller: _emailController,
                hint: "Enter your email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              _buildInputField(
                controller: _passwordController,
                hint: "Password",
                icon: Icons.lock_outline,
                obscureText: _obscureText,
                suffix: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (_isValidEmail(_emailController.text.trim())) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForgotPasswordScreen(
                            email: _emailController.text.trim(),
                          ),
                        ),
                      );
                    } else {
                      _showErrorPopup("Please enter a valid email address first.");
                    }
                  },
                  child: const Text(
                    "Forget password?",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              GestureDetector(
                onTap: _isLoading ? null : _validateAndLogin,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey : Colors.black,
                    borderRadius: BorderRadius.circular(15),
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
                      "Sign in",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "New member? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Register now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: _showErrors && controller.text.isEmpty
              ? const BorderSide(color: Colors.red, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }
}