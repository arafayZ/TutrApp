class RegistrationConfig {
  /// Must match backend `UserCleanupScheduler` — currently 10 days.
  /// Warning email is sent at Day 9 on backend.
  static const int totalDaysBeforeDeletion = 10;

  /// When the warning turns "urgent" (red instead of orange)
  static const int urgentThresholdDays = 2;

  /// When the warning turns "medium" (darker orange)
  static const int mediumThresholdDays = 5;
}