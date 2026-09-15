import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_verfication_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

/// Blocks paste in a TextField by rejecting any change that adds
/// more than one character at a time (typing adds 1, paste adds many).
/// Works reliably on Android and iOS.
class NoPasteTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final delta = newValue.text.length - oldValue.text.length;
    // Allow deletions and single-character typing
    if (delta <= 1) {
      return newValue;
    }
    // Block: more than one character added at once = paste
    return oldValue;
  }
}

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _showErrors = false;
  bool _isLoading = false;

  // Password strength tracking
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordStrength);
  }

  void _validatePasswordStrength() {
    String password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get isPasswordValid {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecialChar;
  }

  int get passwordStrength {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUppercase) strength++;
    if (_hasLowercase) strength++;
    if (_hasDigit) strength++;
    if (_hasSpecialChar) strength++;
    return strength;
  }

  String get passwordStrengthText {
    int strength = passwordStrength;
    if (strength <= 2) return 'Weak';
    if (strength <= 4) return 'Medium';
    return 'Strong';
  }

  Color get passwordStrengthColor {
    int strength = passwordStrength;
    if (strength <= 2) return Colors.red;
    if (strength <= 4) return Colors.orange;
    return Colors.green;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordStrength);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showTermsPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Condition & Attending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("By signing up, you confirm that you are at least 18 years old and that all the information you provide is accurate and up-to-date. Both students and tutors agree to communicate respectfully and follow all guidelines provided within the app. Tutors are responsible for the correctness of their course details, schedules, and availability."),
              const SizedBox(height: 20),
              const Text("Terms & Use", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("All payments and fees made through the app are final. The platform is not responsible for any content or interactions shared between users. By creating an account, you acknowledge and accept these terms and conditions."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    // Validation
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _showErrors = true);
      _showDialogPopup("Please fill in all mandatory fields to continue.");
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showDialogPopup("Please enter a valid email address.");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showDialogPopup("Passwords do not match.");
      return;
    }

    // Password strength validation
    if (!isPasswordValid) {
      _showDialogPopup(
          "Password must contain:\n"
              "• At least 8 characters\n"
              "• One uppercase letter\n"
              "• One lowercase letter\n"
              "• One number\n"
              "• One special character (!@#%^&*)"
      );
      return;
    }

    if (!_agreeToTerms) {
      _showDialogPopup("You must agree to the terms and conditions to sign up.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ========== Use registerTemp instead of register ==========
      final tempData = await AuthService.registerTemp(
        _emailController.text.trim(),
        _passwordController.text,
        widget.role,
      );
      // ==========================================================

      if (!mounted) return;
      setState(() => _isLoading = false);

      //  Read createdAt from backend response
      final DateTime? createdAt = tempData != null && tempData['createdAt'] != null
          ? DateTime.tryParse(tempData['createdAt'].toString())
          : DateTime.now(); // fallback if backend hasn't been redeployed yet

      // ========== Pass only email and role (no userId yet) ==========
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: _emailController.text.trim(),
            role: widget.role,
            createdAt: createdAt,
            // No userId passed - user not saved in DB yet
          ),
        ),
      );
      // ===============================================================
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      _showDialogPopup(errorMsg);
    }
  }

  void _showDialogPopup(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          // Header with shadow
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30)
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const Text("Get Started", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("as a ${widget.role}", style: const TextStyle(fontSize: 18, color: Colors.black54)),
                  const SizedBox(height: 40),

                  _buildTextField(label: "Valid email", icon: Icons.email_outlined, controller: _emailController),
                  const SizedBox(height: 16),

                  // Password field with strength indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        label: "Strong password", icon: Icons.lock_outline,
                        isPassword: true, controller: _passwordController,
                        obscure: _obscurePassword,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Password Strength: ",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Text(
                                    passwordStrengthText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: passwordStrengthColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: passwordStrength / 5,
                                backgroundColor: Colors.grey[200],
                                color: passwordStrengthColor,
                                minHeight: 4,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Requirements:",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                              ),
                              _buildRequirementTile("At least 8 characters", _hasMinLength),
                              _buildRequirementTile("Uppercase letter (A-Z)", _hasUppercase),
                              _buildRequirementTile("Lowercase letter (a-z)", _hasLowercase),
                              _buildRequirementTile("Number (0-9)", _hasDigit),
                              _buildRequirementTile("Special character (!@#\$%^&*)", _hasSpecialChar),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),
                  _buildTextField(
                    label: "Confirm password", icon: Icons.lock_outline,
                    isPassword: true, controller: _confirmPasswordController,
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    blockPaste: true, // ✅ Blocks paste on Confirm Password only
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        activeColor: Colors.black,
                        onChanged: (val) => setState(() => _agreeToTerms = val!),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 11),
                            children: [
                              const TextSpan(text: "By checking the box you agree to our "),
                              TextSpan(
                                text: "Terms and Conditions",
                                style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = _showTermsPopup,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: _isLoading ? null : _handleSignup,
                    child: Container(
                      width: double.infinity, height: 60,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.grey : Colors.black,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text(
                          "Continue",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                    child: const Text.rich(
                      TextSpan(
                        text: "Already a member? ",
                        children: [
                          TextSpan(text: "Login", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementTile(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 12,
          color: isMet ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: isMet ? Colors.green : Colors.grey[600],
            decoration: isMet ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool? obscure,
    VoidCallback? onToggle,
    bool blockPaste = false,
  }) {
    TextInputType keyboardType = TextInputType.text;
    if (label.toLowerCase().contains("email")) {
      keyboardType = TextInputType.emailAddress;
    }

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? (obscure ?? true) : false,
      enableInteractiveSelection: !blockPaste, // disables long-press menu
      inputFormatters: blockPaste
          ? [NoPasteTextInputFormatter()] // engine-level paste block
          : null,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon((obscure ?? true)
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: onToggle,
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _showErrors && controller.text.isEmpty
              ? const BorderSide(color: Colors.red, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }
}