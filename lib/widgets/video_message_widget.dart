// lib/widgets/video_message_widget.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/file_opener_service.dart';   // ✅ NEW

// ============================================================
// CHAT BUBBLE — thumbnail + play button
// ============================================================
class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final bool isMe;
  final MessageStatus? localStatus;

  const VideoMessageWidget({
    super.key,
    required this.videoUrl,
    required this.isMe,
    this.localStatus,
  });

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  Uint8List? _thumbnailBytes;
  bool _loadingThumb = true;

  String get _fullUrl => widget.videoUrl.startsWith('http')
      ? widget.videoUrl
      : '${ApiConfig.baseUrl}${widget.videoUrl}';

  bool get _isUploading =>
      widget.localStatus == MessageStatus.sending ||
          widget.localStatus == MessageStatus.uploading;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final localPath =
          '${tempDir.path}/thumb_${widget.videoUrl.hashCode}.mp4';
      final localFile = File(localPath);

      if (!await localFile.exists()) {
        final headers = await ApiClient.mediaDownloadHeaders();
        final response = await http
            .get(Uri.parse(_fullUrl), headers: headers)
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          debugPrint('Thumbnail download failed: ${response.statusCode}');
          if (mounted) setState(() => _loadingThumb = false);
          return;
        }
      }

      final bytes = await VideoThumbnail.thumbnailData(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
      );

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _loadingThumb = false;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      if (mounted) setState(() => _loadingThumb = false);
    }
  }

  void _openFullScreen() async {
    if (_isUploading) return;

    final headers = await ApiClient.videoHeaders();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(
          videoUrl: _fullUrl,
          headers: headers,
        ),
      ),
    );
  }

  // ✅ NEW — Long-press menu
  void _showVideoMenu(BuildContext context) {
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

                final fileName = widget.videoUrl.split('/').last;
                final ok = await FileOpenerService.saveToGallery(
                  fileUrl: widget.videoUrl,
                  fileName: fileName,
                  isVideo: true,
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
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Play'),
              onTap: () {
                Navigator.pop(modalContext);
                _openFullScreen();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullScreen,
      // ✅ NEW — Long-press → menu
      onLongPress: () => _showVideoMenu(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 220,
          height: 220,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_thumbnailBytes != null)
                Image.memory(
                  _thumbnailBytes!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                )
              else if (_loadingThumb)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                )
              else
                const Icon(Icons.videocam, color: Colors.white54, size: 48),

              Container(color: Colors.black.withValues(alpha: 0.25)),

              if (!_isUploading)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),

              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.localStatus == MessageStatus.sending
                              ? 'Preparing...'
                              : 'Uploading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (widget.localStatus == MessageStatus.failed)
                Positioned.fill(
                  child: Container(
                    color: Colors.red.withValues(alpha: 0.55),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 36,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Failed to send',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_isUploading)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, color: Colors.white, size: 12),
                        SizedBox(width: 3),
                        Text(
                          'Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

// ============================================================
// FULLSCREEN PLAYER — unchanged
// ============================================================
class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Map<String, String>? headers;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.headers,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _player.stream.error.listen((error) {
      debugPrint('❌ media_kit error: $error');
      if (mounted) setState(() => _error = error);
    });

    _player.stream.duration.listen((d) {
      if (d.inMilliseconds > 0 && !_initialized && mounted) {
        setState(() => _initialized = true);
      }
    });

    _openVideo();
  }

  Future<void> _openVideo() async {
    try {
      debugPrint('🎥 [media_kit] Loading: ${widget.videoUrl}');
      await _player.open(
        Media(widget.videoUrl, httpHeaders: widget.headers),
        play: true,
      );
      debugPrint('✅ [media_kit] opened');
    } catch (e) {
      debugPrint('❌ [media_kit] open failed: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 60,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cannot play video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
                  : Video(
                controller: _controller,
                controls: AdaptiveVideoControls,
              ),
            ),

            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            if (!_initialized && _error == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}