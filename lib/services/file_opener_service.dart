import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import 'api_client.dart';
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

  // ============================================================
// SAVE FILE TO DOWNLOADS FOLDER (user-visible)
// ============================================================
  static Future<bool> saveFileToDownloads(
      String fileUrl,
      String fileName,
      ) async {
    try {
      // ─── 1. Android < 11 permission (API <= 29) ───
      if (Platform.isAndroid) {
        // On Android 11+ this permission is auto-granted for Downloads folder.
        // On Android 10 and below, we need to request it.
        if (await Permission.storage.isDenied) {
          final status = await Permission.storage.request();
          if (status.isDenied || status.isPermanentlyDenied) {
            debugPrint('❌ Storage permission denied');
            return false;
          }
        }
      }

      // ─── 2. Decide destination directory ───
      Directory? targetDir;
      if (Platform.isAndroid) {
        // Visible in Files app → Downloads/Tutr
        targetDir = Directory('/storage/emulated/0/Download/Tutr');
      } else if (Platform.isIOS) {
        // iOS has no Downloads — use app Documents (visible in Files app)
        targetDir = await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getDownloadsDirectory();
      }

      if (targetDir == null) {
        debugPrint('❌ Could not resolve downloads directory');
        return false;
      }

      // ─── 3. Ensure folder exists ───
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final targetFile = File('${targetDir.path}/$fileName');

      // ─── 4. Skip if already saved (no duplicates) ───
      if (await targetFile.exists()) {
        debugPrint('⏭️ Already saved: ${targetFile.path}');
        return true;
      }

      // ─── 5. Download with auth + ngrok headers ───
      final fullUrl = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiConfig.baseUrl}$fileUrl';

      final headers = await ApiClient.mediaDownloadHeaders();
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Download failed: ${response.statusCode}');
        return false;
      }

      // ─── 6. Write to disk ───
      await targetFile.writeAsBytes(response.bodyBytes);
      debugPrint('✅ Saved to ${targetFile.path}');
      return true;
    } catch (e) {
      debugPrint('❌ Save failed: $e');
      return false;
    }
  }

  // ============================================================
// SAVE IMAGE / VIDEO TO GALLERY (album: "Tutr")
// Works with saver_gallery: ^4.1.2
// ============================================================
  static Future<bool> saveToGallery({
    required String fileUrl,
    required String fileName,
    required bool isVideo,
  }) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();

        if (status.isPermanentlyDenied) {
          return false;
        }
      }

      final fullUrl = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiConfig.baseUrl}$fileUrl';

      final headers = await ApiClient.mediaDownloadHeaders();

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Download failed: ${response.statusCode}');
        return false;
      }

      final androidAlbumPath =
      isVideo ? 'Movies/Tutr' : 'Pictures/Tutr';

      SaveResult result;

      if (isVideo) {
        final tempDir = await getTemporaryDirectory();

        final tempFile = File(
          '${tempDir.path}/$fileName',
        );

        await tempFile.writeAsBytes(
          response.bodyBytes,
        );

        result = await SaverGallery.saveFile(
          filePath: tempFile.path,
          fileName: fileName,
          androidRelativePath: androidAlbumPath,
          skipIfExists: true,
        );

        try {
          await tempFile.delete();
        } catch (_) {}
      } else {
        result = await SaverGallery.saveImage(
          response.bodyBytes,
          quality: 100,
          fileName: fileName,
          androidRelativePath: androidAlbumPath,
          skipIfExists: true,
        );
      }

      debugPrint(
        '📸 Save result: isSuccess=${result.isSuccess}, '
            'errorMessage=${result.errorMessage}',
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('❌ Save to gallery failed: $e');
      return false;
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