import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/course_service.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  bool _isSubmitting = false;

  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _classesController = TextEditingController();

  static const List<String> _dayList = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  String? _selectedCategory;
  String? _selectedMode;
  bool _isLocationEditable = true;
  bool _isClassesManuallyEdited = false; // Track if user manually edited classes

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  String _startDay = "Monday";
  String _endDay = "Friday";

  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // Initialize with calculated value
    _updateClassesPerMonth();
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _subjectController.dispose();
    _locationController.dispose();
    _feeController.dispose();
    _classesController.dispose();
    super.dispose();
  }

  // Calculate number of classes per month based on selected days
  int _calculateDaysInRange(String fromDay, String toDay) {
    const List<String> daysOrder = [
      "Monday", "Tuesday", "Wednesday", "Thursday",
      "Friday", "Saturday", "Sunday"
    ];

    int startIndex = daysOrder.indexOf(fromDay);
    int endIndex = daysOrder.indexOf(toDay);

    // Same day = 1 day
    if (startIndex == endIndex) {
      return 1;
    }

    // Normal range (from day comes before to day)
    if (startIndex < endIndex) {
      return endIndex - startIndex + 1;
    }

    // Wraparound (from day after to day, crossing weekend)
    // Example: Friday (4) to Monday (0) = (7-4) + (0+1) = 3 + 1 = 4 days
    return (7 - startIndex) + (endIndex + 1);
  }

  int _calculateClassesPerMonth(String fromDay, String toDay) {
    int daysInRange = _calculateDaysInRange(fromDay, toDay);
    // Using exactly 4 weeks per month
    return daysInRange * 4;
  }

  // Update classes field with calculated value (only if not manually edited)
  void _updateClassesPerMonth() {
    if (!_isClassesManuallyEdited) {
      int calculatedClasses = _calculateClassesPerMonth(_startDay, _endDay);
      _classesController.text = calculatedClasses.toString();
    }
  }

  // Reset manual edit flag when days change
  void _onDayChanged() {
    // If days change, reset the manual edit flag and auto-calculate
    _isClassesManuallyEdited = false;
    _updateClassesPerMonth();
  }

  void _updateLocationBasedOnMode(String? mode) {
    if (mode == "Online") {
      setState(() {
        _isLocationEditable = false;
        _locationController.text = "Online";
      });
    } else if (mode == "Student Home") {
      setState(() {
        _isLocationEditable = true;
        _locationController.text = "";
      });
    } else if (mode == "Tutor Home") {
      setState(() {
        _isLocationEditable = true;
        _locationController.text = "";
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.transparent),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.black),
              dayPeriodBorderSide: const BorderSide(color: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 80,
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
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: 20,
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        "Add Course",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _buildFormView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("About", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildAboutField(),
          const SizedBox(height: 25),
          const Text("What You Provide",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildField("Subject", _subjectController, "e.g. Maths"),
          _buildDropdown(
              "Category",
              const ["Matric", "Intermediate", "O Level", "A Level", "Entrance Test"],
              _selectedCategory,
                  (v) => setState(() => _selectedCategory = v)),
          _buildDropdown(
              "Teaching Mode",
              const ["Online", "Student Home", "Tutor Home"],
              _selectedMode,
                  (v) {
                setState(() {
                  _selectedMode = v;
                  _updateLocationBasedOnMode(v);
                });
              }),
          _buildField(
            "Area, City",
            _locationController,
            _isLocationEditable ? "e.g. Nazimabad, Karachi" : "",
            readOnly: !_isLocationEditable,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildTimeSelector(
                      "Start Time", _startTime, () => _pickTime(true))),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildTimeSelector(
                      "End Time", _endTime, () => _pickTime(false))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildSmallDropdown("From", _dayList, _startDay,
                          (v) {
                        setState(() {
                          _startDay = v!;
                          _onDayChanged(); // Auto-calculate classes
                        });
                      })),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Text("To")),
              Expanded(
                  child: _buildSmallDropdown("To", _dayList, _endDay,
                          (v) {
                        setState(() {
                          _endDay = v!;
                          _onDayChanged(); // Auto-calculate classes
                        });
                      })),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  "Classes (Month)",
                  _classesController,
                  "Auto-calculated (editable)",
                  isNumeric: true,
                  maxValue: 31,
                  onChanged: () {
                    // Mark as manually edited when user types
                    _isClassesManuallyEdited = true;
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildField("Tuition Fee (PKR)", _feeController,
                    "Max 50,000",
                    isNumeric: true, maxValue: 50000),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                  child: _buildButton("Cancel", const Color(0xFFEEEEEE),
                      Colors.black, () => Navigator.pop(context))),
              const SizedBox(width: 15),
              Expanded(
                  child: _isSubmitting
                      ? SizedBox(
                    height: 55,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                      : _buildButton(
                      "Add", Colors.black, Colors.white, _validateAndSubmit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTimeOfDay(time), style: const TextStyle(fontSize: 12)),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint,
      {bool isNumeric = false, int? maxValue, bool readOnly = false, VoidCallback? onChanged}) {
    int? val = int.tryParse(controller.text);
    bool hasError = _showErrors &&
        (controller.text.trim().isEmpty ||
            (isNumeric && val == null) ||
            (maxValue != null && val != null && val > maxValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          inputFormatters:
          isNumeric ? [FilteringTextInputFormatter.digitsOnly] : [],
          onChanged: (value) {
            setState(() {});
            if (onChanged != null) onChanged();
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey[30] : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildAboutField() {
    bool hasError = _showErrors && _aboutController.text.trim().isEmpty;
    int wordCount = _aboutController.text.trim().isEmpty
        ? 0
        : _aboutController.text.trim().split(RegExp(r'\s+')).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: hasError ? Colors.red : const Color(0xFFEEEEEE)),
          ),
          child: TextField(
            controller: _aboutController,
            maxLines: 4,
            onChanged: (v) => setState(() {}),
            decoration: const InputDecoration(
              hintText: "Describe your course...",
              hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: Text("$wordCount/30 words",
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      Function(String?) onChanged) {
    bool hasError = _showErrors && value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: hasError ? Colors.red : Colors.transparent),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Select",
                  style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildSmallDropdown(String label, List<String> items, String value,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(
                  value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
      String text, Color bg, Color textColor, VoidCallback onTap) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    String hour = (time.hour % 12 == 0 ? 12 : (time.hour % 12)).toString();
    String minute = time.minute.toString().padLeft(2, '0');
    String period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  Future<void> _validateAndSubmit() async {
    int? fee = int.tryParse(_feeController.text);
    int? classes = int.tryParse(_classesController.text);
    int wordCount = _aboutController.text.trim().isEmpty
        ? 0
        : _aboutController.text.trim().split(RegExp(r'\s+')).length;

    double startDouble = _startTime.hour + _startTime.minute / 60.0;
    double endDouble = _endTime.hour + _endTime.minute / 60.0;

    if ((classes != null && classes > 31) || (fee != null && fee > 50000)) {
      String errorTitle = (classes ?? 0) > 31 ? "Invalid Class Count" : "Invalid Fee";
      String errorMsg = (classes ?? 0) > 31
          ? "You cannot add more than 31 classes per month."
          : "The tuition fee cannot exceed 50,000 PKR.";
      _showErrorPopup(errorTitle, errorMsg);
      setState(() => _showErrors = true);
      return;
    }

    if (endDouble <= startDouble) {
      _showErrorPopup("Invalid Time", "The end time must be strictly after the start time.");
      setState(() => _showErrors = true);
      return;
    }

    if (wordCount > 30) {
      _showErrorPopup("Text Too Long", "The 'About' section cannot exceed 30 words.");
      setState(() => _showErrors = true);
      return;
    }

    // Check for location field - only required if "Tutor Home" is selected
    bool isLocationValid = true;
    if (_selectedMode == "Tutor Home" && _locationController.text.trim().isEmpty) {
      isLocationValid = false;
    } else if (_selectedMode != "Tutor Home" && _locationController.text.trim().isEmpty) {
      // For Online and Student Home, location is auto-filled, so should not be empty
      isLocationValid = false;
    }

    if (_aboutController.text.isEmpty ||
        _subjectController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedMode == null ||
        fee == null ||
        classes == null ||
        !isLocationValid) {
      setState(() => _showErrors = true);
      _showErrorPopup("Missing Info", "Please fill in all the required fields.");
    } else {
      setState(() => _showErrors = false);
      await _submitCourse();
    }
  }

  Future<void> _submitCourse() async {
    setState(() => _isSubmitting = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int tutorProfileId = prefs.getInt('profileId') ?? 0;

      if (tutorProfileId == 0) {
        throw Exception('Tutor profile not found. Please login again.');
      }

      String startTimeStr = _formatTimeOfDay(_startTime);
      String endTimeStr = _formatTimeOfDay(_endTime);

      Map<String, dynamic> courseData = {
        'tutorProfileId': tutorProfileId,
        'about': _aboutController.text.trim(),
        'subject': _subjectController.text.trim(),
        'category': _selectedCategory,
        'teachingMode': _selectedMode,
        'location': _locationController.text.trim(),
        'fromDay': _startDay.toUpperCase(),
        'toDay': _endDay.toUpperCase(),
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'classesPerMonth': int.parse(_classesController.text),
        'price': double.parse(_feeController.text),
      };

      await CourseService.createCourse(courseData);

      setState(() => _isSubmitting = false);
      _showSuccessPopup();

    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorPopup("Error", e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showErrorPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("⚠️", style: TextStyle(fontSize: 50)),
              const SizedBox(height: 15),
              Text(title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),
              _buildButton("Try Again", Colors.black, Colors.white,
                      () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("🎉", style: TextStyle(fontSize: 50)),
              SizedBox(height: 15),
              Text("Congratulations",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("Course added successfully!",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.black),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    });
  }
}