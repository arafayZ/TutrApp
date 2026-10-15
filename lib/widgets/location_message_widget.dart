import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMessageWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isMe;

  const LocationMessageWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isMe,
  });

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMaps,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 40,
              color: isMe ? Colors.white : Colors.red,
            ),
            const SizedBox(height: 8),
            Text(
              'Shared location',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to open in Maps',
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}