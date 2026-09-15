import 'package:flutter/material.dart';
import '../config/registration_config.dart';

/// Shows a one-time popup warning about the registration deadline.
///
/// Usage — call inside `initState`:
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     RegistrationDeadlinePopup.show(
///       context,
///       createdAt: widget.createdAt,
///     );
///   });
/// }
/// ```
///
/// The popup only appears once per app session. After the user taps OK,
/// it won't show again until the app is fully restarted.
class RegistrationDeadlinePopup {
  /// In-memory flag so the popup only appears once per app session.
  static bool _shownThisSession = false;

  /// Show the popup if applicable. Does nothing if already shown this session.
  static Future<void> show(
      BuildContext context, {
        DateTime? createdAt,
        int totalDays = RegistrationConfig.totalDaysBeforeDeletion,
      }) async {
    // Only show once per session
    if (_shownThisSession) return;

    // ---- No createdAt → generic warning ----
    if (createdAt == null) {
      _shownThisSession = true;
      if (!context.mounted) return;
      _presentDialog(
        context,
        color: Colors.orange.shade700,
        icon: Icons.info_outline_rounded,
        title: "Complete your registration within $totalDays days",
        subtitle:
        "Your account will be permanently deleted if you don't finish all steps. You'll need to sign up again.",
      );
      return;
    }

    // ---- Compute days remaining ----
    final deadline = createdAt.add(Duration(days: totalDays));
    final now = DateTime.now();
    final hoursLeft = deadline.difference(now).inHours;
    final daysLeft = (hoursLeft / 24).ceil(); // round up partial days

    Color color;
    IconData icon;
    String title;
    String subtitle;

    // ---- Expired ----
    if (hoursLeft <= 0) {
      color = Colors.red.shade700;
      icon = Icons.error_outline_rounded;
      title = "Registration window expired";
      subtitle =
      "Your account is scheduled for deletion. Please contact support immediately.";
    }
    // ---- Urgent: ≤ 2 days ----
    else if (daysLeft <= RegistrationConfig.urgentThresholdDays) {
      final dayLabel = daysLeft == 1 ? "1 day" : "$daysLeft days";
      color = Colors.red.shade600;
      icon = Icons.warning_amber_rounded;
      title = "⚠️ Only $dayLabel left!";
      subtitle =
      "Finish registration now or your account will be permanently deleted and you'll need to sign up again.";
    }
    // ---- Medium: ≤ 5 days ----
    else if (daysLeft <= RegistrationConfig.mediumThresholdDays) {
      color = Colors.orange.shade700;
      icon = Icons.warning_amber_rounded;
      title = "$daysLeft days left to complete registration";
      subtitle =
      "Complete all steps within $totalDays days or your account will be deleted and you'll need to sign up again.";
    }
    // ---- Low urgency: > 5 days ----
    else {
      color = Colors.orange.shade600;
      icon = Icons.info_outline_rounded;
      title = "$daysLeft days left to complete registration";
      subtitle =
      "Complete all steps within $totalDays days or your account will be deleted and you'll need to sign up again.";
    }

    _shownThisSession = true;
    if (!context.mounted) return;

    _presentDialog(
      context,
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Reset the session flag (useful for testing).
  static void resetSession() => _shownThisSession = false;

  /// Internal: builds and shows the dialog.
  static void _presentDialog(
      BuildContext context, {
        required Color color,
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false, // user must tap OK
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---- Icon in colored circle ----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 44),
              ),
              const SizedBox(height: 20),

              // ---- Title ----
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),

              // ---- Subtitle ----
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ---- OK Button ----
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}