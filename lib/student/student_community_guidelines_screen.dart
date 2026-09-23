import 'package:flutter/material.dart';
import '../widgets/custom_tab_header.dart';

class StudentCommunityGuidelinesScreen extends StatelessWidget {
  const StudentCommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      extendBody: true,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: const CustomTabHeader(
              title: Text(
                "Community Guidelines",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContentText(
                    "Welcome to TUTR. These guidelines explain how we expect students to behave, "
                        "how to report issues with a tutor, and what happens after you report. "
                        "By using TUTR, you agree to follow these rules.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("1. Your Behaviour as a Student"),
                  _buildContentText(
                    "Treat every tutor with respect. Engage honestly, communicate politely, and "
                        "pay agreed fees on time. Do not send abusive messages, make threats, or "
                        "share false information about a tutor.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("2. What You Can Report"),
                  _buildContentText(
                    "You can file a report against a tutor you have been connected with "
                        "(currently confirmed or previously connected). Reportable issues include:",
                  ),
                  const SizedBox(height: 12),
                  _buildBulletText("Harassment — physical, verbal, or written"),
                  _buildBulletText("Abusive Language — offensive or threatening speech"),
                  _buildBulletText("Fraud or Scam — attempts to deceive for money"),
                  _buildBulletText("Fake Credentials — falsified degrees or experience"),
                  _buildBulletText("No-Show — missed scheduled sessions without notice"),
                  _buildBulletText("Poor Teaching — quality far below expectations"),
                  _buildBulletText("Unprofessional Conduct — inappropriate behaviour"),
                  _buildBulletText("Payment Dispute — disagreement over fees"),
                  _buildBulletText("Other — anything not covered above"),

                  const SizedBox(height: 32),

                  _buildSectionTitle("3. How to File a Report"),
                  _buildContentText(
                    "Open the tutor's profile, tap the menu at the top right, and select Report. "
                        "Choose a reason, describe what happened (at least 10 characters), and attach "
                        "any evidence such as screenshots or chat records.",
                  ),
                  const SizedBox(height: 12),
                  _buildContentText(
                    "You can only file one report against a tutor every 7 days, and only if you "
                        "have been connected with them.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("4. What Happens After You Report"),
                  _buildNumberedText("1", "Submitted — your report is recorded and marked Pending."),
                  _buildNumberedText("2", "Under Review — our trust and safety team examines it."),
                  _buildNumberedText("3", "Resolved — a decision is made; you are notified."),
                  const SizedBox(height: 12),
                  _buildContentText(
                    "You will receive a notification when your report is submitted, when it "
                        "enters review, and when it is resolved.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("5. Outcomes You May See"),
                  _buildBulletText("Warning Issued — recorded on the tutor's account"),
                  _buildBulletText("Suspension — tutor's account is temporarily disabled"),
                  _buildBulletText("Dismissed — no violation was found"),

                  const SizedBox(height: 32),

                  _buildSectionTitle("6. False Reports"),
                  _buildContentText(
                    "Reporting is serious. Filing deliberately false reports to harm a tutor's "
                        "reputation is itself a violation. Accounts that repeatedly submit unfounded "
                        "reports may face restrictions or removal.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("7. Confidentiality"),
                  _buildContentText(
                    "Your identity as a reporter is kept confidential. The tutor is never told "
                        "who filed a report against them. Only our trust and safety team can see "
                        "your report details.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("8. Support"),
                  _buildContentText(
                    "For help with reporting, or if you disagree with a decision, contact us at "
                        "tutr.verify@gmail.com. We review every appeal fairly.",
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: Text(
                      "Last updated: January 2025",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }

  Widget _buildContentText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.6),
    );
  }

  Widget _buildBulletText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8.0, right: 8.0),
            child: Icon(Icons.circle, size: 4, color: Colors.black),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedText(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              number + ".",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.5)),
          ),
        ],
      ),
    );
  }
}