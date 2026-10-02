import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/file_opener_service.dart';

class FileMessageWidget extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final String? fileType;
  final bool isMe;

  const FileMessageWidget({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    this.fileType,
    this.isMe = false,
  });

  IconData _getFileIcon() {
    final type = fileType?.toLowerCase() ?? '';
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'doc' || type == 'docx') return Icons.description;
    if (type == 'xls' || type == 'xlsx') return Icons.table_chart;
    if (type == 'ppt' || type == 'pptx') return Icons.slideshow;
    if (type == 'zip' || type == 'rar') return Icons.folder_zip;
    if (type == 'txt') return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    final type = fileType?.toLowerCase() ?? '';
    if (type == 'pdf') return Colors.red;
    if (type == 'doc' || type == 'docx') return Colors.blue;
    if (type == 'xls' || type == 'xlsx') return Colors.green;
    if (type == 'ppt' || type == 'pptx') return Colors.orange;
    return Colors.grey;
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ✅ Long-press menu
  void _showFileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        child: Wrap(
          children: [
            // ── Save to Downloads ──
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Save to Downloads'),
              onTap: () async {
                Navigator.pop(modalContext);

                // Show progress snackbar
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
                        Text('Saving...'),
                      ],
                    ),
                    duration: Duration(minutes: 2),
                    backgroundColor: Colors.black87,
                  ),
                );

                final ok = await FileOpenerService.saveFileToDownloads(
                  fileUrl,
                  fileName,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Saved to Downloads/Tutr'
                            : 'Failed to save file',
                      ),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),

            // ── Open ──
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(modalContext);
                FileOpenerService.openFileFromUrl(
                  context,
                  fileUrl: fileUrl,
                  fileName: fileName,
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
    final textColor = isMe ? Colors.white : Colors.black87;

    return GestureDetector(
      // ✅ Tap → open
      onTap: () {
        FileOpenerService.openFileFromUrl(
          context,
          fileUrl: fileUrl,
          fileName: fileName,
        );
      },
      // ✅ Long-press → menu
      onLongPress: () => _showFileMenu(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getFileColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFileIcon(),
                color: _getFileColor(),
                size: 24,
              ),
            ),

            const SizedBox(width: 10),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSize(fileSize),
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}