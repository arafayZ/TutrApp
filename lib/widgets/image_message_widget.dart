import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/file_opener_service.dart';

class ImageMessageWidget extends StatelessWidget {
  final String imageUrl;
  final bool isMe;

  const ImageMessageWidget({
    super.key,
    required this.imageUrl,
    this.isMe = false,
  });

  // ✅ Long-press menu
  void _showImageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Save to Gallery'),
              subtitle: const Text('Album: Tutr'),
              onTap: () async {
                Navigator.pop(modalContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Saving to gallery...'),
                      ],
                    ),
                    duration: Duration(minutes: 2),
                    backgroundColor: Colors.black87,
                  ),
                );

                final fileName = imageUrl.split('/').last;
                final ok = await FileOpenerService.saveToGallery(
                  fileUrl: imageUrl,
                  fileName: fileName,
                  isVideo: false,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Saved to Gallery → Tutr' : 'Failed to save',
                      ),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(modalContext);
                FileOpenerService.openImageViewer(
                  context,
                  imageUrl: imageUrl,
                  title: null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiConfig.baseUrl}$imageUrl';

    return GestureDetector(
      // ✅ Tap to open fullscreen
      onTap: () {
        FileOpenerService.openImageViewer(
          context,
          imageUrl: imageUrl,
          title: 'Image',
        );
      },
      // ✅ Long-press → menu
      onLongPress: () => _showImageMenu(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: 'image_$imageUrl',
          child: Image.network(
            fullUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade300,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}