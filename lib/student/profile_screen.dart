import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../tutor/terms_conditions_screen.dart';
import 'student_community_guidelines_screen.dart';
import 'edit_profile_screen.dart';
import '../tutor/security_screen.dart';
import 'block_tutor_screen.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/status_bar_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "";
  String userEmail = "";
  String? profileImageUrl;
  int profileId = 0;
  bool isLoading = true;

  // Store the original image URL without timestamp
  String? _originalImageUrl;
  String? _displayImageUrl;

  @override
  void initState() {
    super.initState();
    StatusBarConfig.setLightStatusBar();
    _loadProfileData();
  }

  @override
  void dispose() {
    StatusBarConfig.resetStatusBar();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      profileId = prefs.getInt('profileId') ?? 0;

      print(' Loading student profile for ID: $profileId');

      if (profileId != 0) {
        final profileData = await AuthService.getStudentProfile(profileId);

        String firstName = profileData['firstName'] ?? '';
        String lastName = profileData['lastName'] ?? '';

        setState(() {
          userName = "$firstName $lastName".trim();
          userEmail = profileData['email'] ?? '';
          _originalImageUrl = profileData['profilePictureUrl'];
          _displayImageUrl = _originalImageUrl;
          isLoading = false;
        });

        print(' Student profile loaded - Name: $userName');
        print(' Image URL: $_originalImageUrl');
      } else {
        print(' No profileId found in SharedPreferences');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print(' Error loading student profile: $e');
      setState(() => isLoading = false);

      // Show error dialog if needed
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // Refresh profile after editing
  Future<void> _refreshProfileAfterEdit() async {
    setState(() => isLoading = true);

    try {
      final profileData = await AuthService.getStudentProfile(profileId);

      String firstName = profileData['firstName'] ?? '';
      String lastName = profileData['lastName'] ?? '';

      setState(() {
        userName = "$firstName $lastName".trim();
        userEmail = profileData['email'] ?? '';
        _originalImageUrl = profileData['profilePictureUrl'];

        // Add timestamp to force image refresh when image actually changed
        if (_originalImageUrl != null && _originalImageUrl!.isNotEmpty) {
          String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          _displayImageUrl = '${ApiConfig.baseUrl}$_originalImageUrl?t=$timestamp';
        } else {
          _displayImageUrl = _originalImageUrl;
        }
        isLoading = false;
      });

      print(' Student profile refreshed - Name: $userName');
    } catch (e) {
      print(' Error refreshing student profile: $e');
      setState(() => isLoading = false);
    }
  }

  String getFullImageUrl() {
    if (_displayImageUrl == null || _displayImageUrl!.isEmpty) return '';
    if (_displayImageUrl!.startsWith('http')) return _displayImageUrl!;
    return '${ApiConfig.baseUrl}$_displayImageUrl';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    setState(() => isLoading = true);

    try {
      // ✅ Remove FCM token so this device stops receiving pushes
      try {
        await NotificationService.instance.removeToken();
      } catch (e) {
        debugPrint('⚠️ Token removal failed: $e');
      }
      await AuthService.logout();

      // Navigate to login screen and remove all previous screens
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
              (route) => false,
        );
      }
    } catch (e) {
      print(' Logout error: $e');
      setState(() => isLoading = false);

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Failed to logout. Please try again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                        onPressed: () => Navigator.pop(context),
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
                          Navigator.pop(context);
                          await _performLogout();
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    margin: const EdgeInsets.only(top: 60),
                    padding: const EdgeInsets.fromLTRB(20, 75, 20, 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName.isEmpty ? "Student" : userName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userEmail.isEmpty ? "No email" : userEmail,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 35),

                        _buildProfileOption(
                          Icons.person_outline,
                          "Edit Profile",
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(profileId: profileId),
                              ),
                            );
                            if (result == true) {
                              await _refreshProfileAfterEdit();
                            }
                          },
                        ),

                        _buildProfileOption(
                          Icons.security_outlined,
                          "Security",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SecurityScreen()),
                            );
                          },
                        ),

                        _buildProfileOption(
                          Icons.description_outlined,
                          "Terms & Conditions",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TermsConditionsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildProfileOption(
                          Icons.gavel_outlined,
                          "Community Guidelines",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StudentCommunityGuidelinesScreen(),
                              ),
                            );
                          },
                        ),

                        _buildProfileOption(
                          Icons.block_outlined,
                          "Block Tutor",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BlockTutorScreen(),
                              ),
                            );
                          },
                        ),

                        _buildProfileOption(
                          Icons.logout,
                          "Logout",
                          onTap: () => _showLogoutDialog(context),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: ClipOval(
                        child: _buildProfileImage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    String fullUrl = getFullImageUrl();
    print(' Displaying image from URL: $fullUrl');

    if (fullUrl.isNotEmpty) {
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print(' Image load error: $error');
          return const Icon(Icons.person, size: 60, color: Colors.grey);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
      );
    } else {
      return const Icon(Icons.person, size: 60, color: Colors.grey);
    }
  }

  Widget _buildProfileOption(IconData icon, String label, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, size: 24, color: Colors.black87),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}