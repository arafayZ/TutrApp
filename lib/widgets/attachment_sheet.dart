import 'package:flutter/material.dart';

class AttachmentSheet extends StatelessWidget {
  final VoidCallback onDocument;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onLocation;

  const AttachmentSheet({
    super.key,
    required this.onDocument,
    required this.onGallery,
    required this.onCamera,
    required this.onLocation,
  });

  static Future<void> show(
      BuildContext context, {
        required VoidCallback onDocument,
        required VoidCallback onGallery,
        required VoidCallback onCamera,
        required VoidCallback onLocation,
      }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentSheet(
        onDocument: onDocument,
        onGallery: onGallery,
        onCamera: onCamera,
        onLocation: onLocation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildOption(
            icon: Icons.insert_drive_file,
            label: 'Document',
            onTap: () {
              Navigator.pop(context);
              onDocument();
            },
          ),
          _buildOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () {
              Navigator.pop(context);
              onGallery();
            },
          ),
          _buildOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () {
              Navigator.pop(context);
              onCamera();
            },
          ),
          _buildOption(
            icon: Icons.location_on,
            label: 'Location',
            onTap: () {
              Navigator.pop(context);
              onLocation();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0), // silver background
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBFBFBF), // silver border
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.black87, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}