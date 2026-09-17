import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import 'api_headers.dart';

class FileOpenerService {
  /// ✅ Open a file from a URL
  /// Downloads it first, then opens with the OS default app
  static Future<void> openFileFromUrl(
      BuildContext context, {
        required String fileUrl,
        required String fileName,
      }) async {
    try {
      // Build full URL
      final fullUrl = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiConfig.baseUrl}$fileUrl';

      print('📂 Opening file: $fullUrl');

      // Show loading
      if (context.mounted) {
        _showLoadingDialog(context, 'Opening file...');
      }

      // ✅ Download to temp folder
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/$fileName');

      // Download if not exists
      if (!await localFile.exists()) {
        final response = await http.get(Uri.parse(fullUrl),
          headers: await ApiHeaders.json(),);

        if (response.statusCode != 200) {
          throw Exception('Failed to download file');
        }

        await localFile.writeAsBytes(response.bodyBytes);
      }

      print('✅ File downloaded to: ${localFile.path}');

      // Close loading
      if (context.mounted) Navigator.pop(context);

      // ✅ Open with OS default app
      final result = await OpenFilex.open(localFile.path);

      if (result.type != ResultType.done) {
        // Fallback: try opening with browser
        await _openInBrowser(fullUrl);
      }
    } catch (e) {
      print('❌ Error opening file: $e');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Open image in fullscreen viewer
  static void openImageViewer(
      BuildContext context, {
        required String imageUrl,
        required String? title,
      }) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiConfig.baseUrl}$imageUrl';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImage(
          imageUrl: fullUrl,
          title: title,
        ),
      ),
    );
  }

  /// ✅ Open URL in browser as fallback
  static Future<void> _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Cannot open in browser: $e');
    }
  }

  /// ✅ Loading dialog
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// ✅ Fullscreen image viewer
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const _FullScreenImage({
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? 'Image',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white54, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}