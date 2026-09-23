import 'package:flutter/material.dart';
import '../widgets/custom_tab_header.dart';

class TutorCommunityGuidelinesScreen extends StatelessWidget {
  const TutorCommunityGuidelinesScreen({super.key});

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
                    "Welcome to TUTR. As a tutor, you play a central role in shaping a safe and "
                        "trusted learning environment. These guidelines explain your responsibilities, "
                        "what can be reported against you, and how reports are handled. By using TUTR, "
                        "you agree to follow these rules.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("1. Your Responsibilities"),
                  _buildContentText(
                    "Provide accurate information about your qualifications, experience, and "
                        "courses. Attend every scheduled session on time. Communicate respectfully "
                        "with students. Deliver teaching that meets reasonable expectations. "
                        "Never harass, threaten, or mistreat a student.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("2. What Can Be Reported Against You"),
                  _buildContentText(
                    "Students who have been connected with you (currently confirmed or previously "
                        "connected) may file a report for any of the following:",
                  ),
                  const SizedBox(height: 12),
                  _buildBulletText("Harassment — physical, verbal, or written"),
                  _buildBulletText("Abusive Language — offensive or threatening speech"),
                  _buildBulletText("Fraud or Scam — any deceptive conduct"),
                  _buildBulletText("Fake Credentials — misrepresented degrees or experience"),
                  _buildBulletText("No-Show — missing a scheduled session without notice"),
                  _buildBulletText("Poor Teaching — quality below expectations"),
                  _buildBulletText("Unprofessional Conduct — inappropriate behaviour"),
                  _buildBulletText("Payment Dispute — disagreement over fees"),
                  _buildBulletText("Other — anything not covered above"),

                  const SizedBox(height: 32),

                  _buildSectionTitle("3. How Reports Are Handled"),
                  _buildNumberedText("1", "Submitted — the student's report is recorded as Pending."),
                  _buildNumberedText("2", "Under Review — our trust and safety team examines the evidence."),
                  _buildNumberedText("3", "Resolved — a decision is made and both parties are notified."),

                  const SizedBox(height: 32),

                  _buildSectionTitle("4. Possible Outcomes"),
                  _buildContentText(
                    "Depending on the severity and evidence, a report against you may result in:",
                  ),
                  const SizedBox(height: 12),
                  _buildBulletText(
                    "Official Warning — sent to your email with the reason and a formal caution. "
                        "Warnings remain permanently on your account.",
                  ),
                  _buildBulletText(
                    "Suspension — your account is temporarily disabled. All active student "
                        "connections are cancelled, and you cannot log in until reactivated by an admin.",
                  ),
                  _buildBulletText(
                    "Dismissal — no violation was found. No action is taken.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("5. Warning Policy"),
                  _buildContentText(
                    "Warnings are cumulative and never expire. Multiple warnings indicate a "
                        "pattern of behaviour and may lead directly to suspension. There is no "
                        "fixed number that triggers automatic suspension — every case is reviewed "
                        "individually by our trust and safety team.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("6. Consequences of Suspension"),
                  _buildContentText(
                    "When suspended, you cannot log in, your courses are hidden from students, "
                        "and all your active connections are terminated. Reactivation is possible "
                        "only after review by an admin. Any suspended connections are not restored.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("7. Appeals"),
                  _buildContentText(
                    "If you believe a warning or suspension was issued in error, you may appeal by "
                        "contacting us at tutr.verify@gmail.com. Include your account email and any "
                        "supporting evidence. All appeals are reviewed fairly by our team.",
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle("8. Reporting Students"),
                  _buildContentText(
                    "If a student violates these guidelines, you can report them through the same "
                        "system. The same review process applies.",
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