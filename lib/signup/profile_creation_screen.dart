import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'login_screen.dart';
import 'tutor_verification_screen.dart';
import '../services/auth_service.dart';
import '../widgets/registration_deadline_banner.dart';

// Custom TextInputFormatter to handle emoji character counting properly
class EmojiLimitingTextInputFormatter extends TextInputFormatter {
  final int maxLength;

  EmojiLimitingTextInputFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Count using runes (properly handles emojis)
    if (newValue.text.runes.length <= maxLength) {
      return newValue;
    }

    // If exceeded, truncate to max length
    String truncated = '';
    int count = 0;
    for (var rune in newValue.text.runes) {
      if (count + 1 > maxLength) break;
      truncated += String.fromCharCode(rune);
      count++;
    }

    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}

class ProfileCreationScreen extends StatefulWidget {
  final String role;
  final int userId;
  final DateTime? createdAt;

  const ProfileCreationScreen({
    super.key,
    required this.role,
    required this.userId,
    this.createdAt,
  });

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final TextEditingController _headlineController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _uniController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _workController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _selectedGender;
  bool _showErrors = false;
  bool _isLoading = false;
  bool _isProfileCreated = false;
  int? _profileId;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _checkExistingProfile();

    //  Show the registration deadline popup once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.createdAt != null) {
        RegistrationDeadlinePopup.show(
          context,
          createdAt: widget.createdAt,
        );
      }
    });

    // Add listener for headline controller to update counter
    _headlineController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _checkExistingProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String profileIdKey = 'tutorProfileId_${widget.userId}';
      int? savedProfileId = prefs.getInt(profileIdKey);

      if (savedProfileId != null) {
        final profile = await AuthService.getTutorProfile(savedProfileId);

        if (profile != null && profile['profileId'] != null) {
          setState(() {
            _isProfileCreated = true;
            _profileId = profile['profileId'];
            _currentImageUrl = profile['profilePictureUrl'];
            _firstNameController.text = profile['firstName'] ?? '';
            _lastNameController.text = profile['lastName'] ?? '';
            _locationController.text = profile['location'] ?? '';
            _phoneController.text = _formatPhoneNumber(profile['phoneNumber'] ?? '');
            _selectedGender = profile['gender'];
            _dobController.text = _formatDateForDisplay(profile['dateOfBirth'] ?? '');
            _uniController.text = profile['universityName'] ?? '';
            _schoolController.text = profile['collegeName'] ?? '';
            _workController.text = profile['workExperience'] ?? '';
            _headlineController.text = profile['headline'] ?? '';
          });
        }
      }
    } catch (e) {
      // No existing profile
    }
  }

  int _getCharacterCount(String text) {
    // Split into characters using runes (handles emojis and special characters properly)
    final runes = text.runes.toList();
    return runes.length;
  }

  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('+92')) {
      return phone.substring(3);
    }
    return phone;
  }

  String _formatDateForDisplay(String date) {
    if (date.isEmpty) return '';
    if (date.contains('-') && date.length >= 10) {
      var parts = date.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
    }
    return date;
  }

  String _formatDateForBackend(String date) {
    if (date.isEmpty) return '';
    if (date.contains('-') && date.length == 10) {
      return date;
    }
    if (date.contains('/')) {
      var parts = date.split('/');
      if (parts.length == 3) {
        return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
      }
    }
    return date;
  }

  @override
  void dispose() {
    _headlineController.removeListener(() {});
    _headlineController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _uniController.dispose();
    _schoolController.dispose();
    _workController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('Gallery'),
              onTap: () async {
                final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) setState(() => _image = File(pickedFile.path));
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('Camera'),
              onTap: () async {
                final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) setState(() => _image = File(pickedFile.path));
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    // Parse the current date from the controller if it exists
    DateTime? initialDate;

    if (_dobController.text.isNotEmpty) {
      try {
        // Parse the date from DD/MM/YYYY format
        var parts = _dobController.text.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          initialDate = DateTime(year, month, day);
        }
      } catch (e) {
        // If parsing fails, use default date
        initialDate = DateTime(2000);
      }
    } else {
      initialDate = DateTime(2000);
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dobController.text = "${picked.day}/${picked.month}/${picked.year}");
    }
  }

  Future<void> _validateAndContinue() async {
    setState(() {
      bool isHeadlineValid = widget.role.toUpperCase() == "STUDENT" || _headlineController.text.trim().isNotEmpty;
      bool isPhoneValid = _phoneController.text.length == 10;
      bool isEducationValid = _uniController.text.trim().isNotEmpty || _schoolController.text.trim().isNotEmpty;

      if (!isHeadlineValid ||
          _firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty ||
          _dobController.text.trim().isEmpty ||
          _locationController.text.trim().isEmpty ||
          !isPhoneValid ||
          _selectedGender == null ||
          !isEducationValid) {
        _showErrors = true;
        _showErrorPopup("Please fill in all mandatory fields correctly.");
      } else {
        _showErrors = false;
      }
    });

    if (_showErrors) return;

    setState(() => _isLoading = true);

    try {
      if (widget.role.toUpperCase() == "TUTOR") {
        await _createOrUpdateTutorProfile();
      } else {
        await _createOrUpdateStudentProfile();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorPopup(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createOrUpdateTutorProfile() async {
    try {
      String phoneNumber = '+92${_phoneController.text}';

      Map<String, dynamic> profileData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phoneNumber': phoneNumber,
        'headline': _headlineController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _formatDateForBackend(_dobController.text.trim()),
        'location': _locationController.text.trim(),
        'universityName': _uniController.text.trim(),
        'collegeName': _schoolController.text.trim(),
        'workExperience': _workController.text.trim().isEmpty ? "Not specified" : _workController.text.trim(),
      };

      Map<String, dynamic> response;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String profileIdKey = 'tutorProfileId_${widget.userId}';
      int? savedProfileId = prefs.getInt(profileIdKey);

      if (savedProfileId != null) {
        profileData['profileId'] = savedProfileId;
        _profileId = savedProfileId;
        _isProfileCreated = true;
        response = await AuthService.editTutorProfile(profileData);
      } else {
        profileData['userId'] = widget.userId;
        response = await AuthService.createTutorProfile(profileData);
        _profileId = response['id'];
        _isProfileCreated = true;
        await prefs.setInt(profileIdKey, _profileId!);
      }

      if (_image != null && _profileId != null) {
        try {
          await AuthService.uploadTutorImage(_profileId!, _image!.path, oldImageUrl: _currentImageUrl);
        } catch (e) {
          // Image upload failed, continue
        }
      }

      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TutorVerificationScreen(
            userId: widget.userId,
            createdAt: widget.createdAt,
          ),
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorPopup(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createOrUpdateStudentProfile() async {
    String phoneNumber = '+92${_phoneController.text}';

    Map<String, dynamic> profileData = {
      'userId': widget.userId,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'phoneNumber': phoneNumber,
      'gender': _selectedGender,
      'dateOfBirth': _formatDateForBackend(_dobController.text.trim()),
      'location': _locationController.text.trim(),
      'schoolName': _uniController.text.trim(),
      'collegeName': _schoolController.text.trim(),
      'subjects': '',
    };

    Map<String, dynamic> response;

    if (_isProfileCreated && _profileId != null) {
      response = await AuthService.editStudentProfile(profileData);
    } else {
      response = await AuthService.createStudentProfile(profileData);
      _profileId = response['id'];
      _isProfileCreated = true;
    }

    setState(() => _isLoading = false);

    if (_image != null && _profileId != null) {
      try {
        await AuthService.uploadStudentImage(_profileId!, _image!.path);
      } catch (e) {
        // Image upload failed, continue
      }
    }

    _showCongratulationsDialog();
  }

  void _showCongratulationsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 70,
                backgroundColor: Color(0xFFFFC107),
                child: Icon(Icons.person, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 25),
              const Text("Congratulations", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text("Your account has been successfully\ncreated!", textAlign: TextAlign.center),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.black),
            ],
          ),
        ),
      ),
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

  String getFullImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    final bool isTutor = widget.role.toUpperCase() == "TUTOR";
    final bool isStudent = widget.role.toUpperCase() == "STUDENT";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      resizeToAvoidBottomInset: true,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFFE0E0E0),
                              backgroundImage: _image != null
                                  ? FileImage(_image!)
                                  : (_currentImageUrl != null ? NetworkImage(getFullImageUrl(_currentImageUrl)) : null),
                              child: _image == null && _currentImageUrl == null
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      if (isTutor) ...[
                        _buildSectionHeader("Headline"),
                        _buildTextFieldWithCounter(
                          hint: "e.g., Experienced Math Tutor",
                          controller: _headlineController,
                          maxLength: 30,
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildSectionHeader("Personal Details"),
                      _buildTextField(hint: "First Name", controller: _firstNameController),
                      const SizedBox(height: 12),
                      _buildTextField(hint: "Last Name", controller: _lastNameController),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _selectDate,
                        child: AbsorbPointer(
                          child: _buildTextField(
                            hint: "Date of Birth",
                            icon: Icons.calendar_today_outlined,
                            controller: _dobController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(hint: "Area, City", icon: Icons.location_on_outlined, controller: _locationController),
                      const SizedBox(height: 12),

                      _buildGenderDropdown(),
                      const SizedBox(height: 12),

                      _buildPhoneField(),
                      const SizedBox(height: 20),

                      _buildSectionHeader("Education"),
                      _buildTextField(
                          hint: isStudent ? "School" : "University",
                          icon: Icons.school_outlined,
                          controller: _uniController,
                          isOptionalGroup: true
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                          hint: isStudent ? "College" : "High School",
                          icon: Icons.account_balance_outlined,
                          controller: _schoolController,
                          isOptionalGroup: true
                      ),

                      if (isTutor) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildSectionHeader("Work"),
                            const SizedBox(width: 8),
                            const Text("(Optional)", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                        _buildTextField(hint: "Work Experience", icon: Icons.work_outline, controller: _workController, isOptional: true),
                      ],

                      const SizedBox(height: 40),

                      GestureDetector(
                        onTap: _isLoading ? null : _validateAndContinue,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : Colors.black,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Continue", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  // New method for text field with character counter (for headline)
  Widget _buildTextFieldWithCounter({
    required String hint,
    required TextEditingController controller,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          inputFormatters: maxLength != null
              ? [
            EmojiLimitingTextInputFormatter(maxLength),
          ]
              : null,
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            counterText: "",
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
          ),
        ),
        if (maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_getCharacterCount(controller.text) > maxLength)
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  "${_getCharacterCount(controller.text)}/$maxLength characters",
                  style: TextStyle(
                    fontSize: 11,
                    color: _getCharacterCount(controller.text) > maxLength ? Colors.red : Colors.grey,
                    fontWeight: _getCharacterCount(controller.text) > maxLength ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String hint,
    IconData? icon,
    Widget? prefixWidget,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool isOptional = false,
    bool isOptionalGroup = false,
  }) {
    bool showErrorBorder = false;

    if (_showErrors) {
      if (isOptional) {
        showErrorBorder = false;
      } else if (isOptionalGroup) {
        showErrorBorder = _uniController.text.trim().isEmpty && _schoolController.text.trim().isEmpty;
      } else {
        showErrorBorder = controller.text.trim().isEmpty;
      }
    }

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.black87, size: 20) : prefixWidget,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: showErrorBorder ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _showErrors && _selectedGender == null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          hint: const Text("Gender"),
          isExpanded: true,
          items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return _buildTextField(
      hint: "xxxxxxxxxx",
      controller: _phoneController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
      prefixWidget: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 12),
          Text("🇵🇰", style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text("( +92 ) ", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}