// lib/tutor/chat_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../services/unread_count_service.dart';
import '../models/chat_models.dart';
import '../config/api_config.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/file_preview_widget.dart';
import '../widgets/reply_preview_widget.dart';
import '../widgets/forward_picker_sheet.dart';
import '../widgets/video_message_widget.dart';

class TutorChatDetailsScreen extends StatefulWidget {
  final String userName;
  final String? userImage;
  final int? studentId;
  final int? studentUserId;
  final int? tutorId;
  final int? tutorUserId;
  final int? chatRoomId;
  final int? connectionId;

  const TutorChatDetailsScreen({
    super.key,
    required this.userName,
    this.userImage,
    this.studentId,
    this.studentUserId,
    this.tutorId,
    this.tutorUserId,
    this.chatRoomId,
    this.connectionId,
  });

  @override
  State<TutorChatDetailsScreen> createState() => _TutorChatDetailsScreenState();
}

class _TutorChatDetailsScreenState extends State<TutorChatDetailsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  Set<int> _messageIds = {};
  int _chatRoomId = 0;
  int _senderId = 0;
  int _recipientId = 0;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAudioRecorder = false;

  List<FilePreview> _pendingFiles = [];
  bool _isUploadingFile = false;

  Message? _replyingTo;

  bool _isSelectionMode = false;
  final Set<int> _selectedMessageIds = {};

  int? _highlightedMessageId;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _senderId = prefs.getInt('userId') ?? 0;
    if (_senderId == 0) {
      _senderId = prefs.getInt('profileId') ?? 0;
    }

    _recipientId = widget.studentUserId ?? 0;

    debugPrint('🔍 Tutor Chat Init:');
    debugPrint('   Sender (Tutor) User ID: $_senderId');
    debugPrint('   Recipient (Student) User ID: $_recipientId');

    await _getOrCreateChatRoom();
    await _loadMessages();
    _connectWebSocket();
  }

  Future<void> _getOrCreateChatRoom() async {
    try {
      if (widget.chatRoomId != null && widget.chatRoomId! > 0) {
        _chatRoomId = widget.chatRoomId!;
        return;
      }

      if (widget.studentUserId != null &&
          widget.studentUserId! > 0 &&
          _senderId > 0) {
        final chatRoom = await ChatService.getOrCreateSharedChatRoom(
          widget.studentUserId!,
          _senderId,
          _senderId,
        );
        _chatRoomId = chatRoom.id;

        if (chatRoom.studentUserId != null &&
            chatRoom.studentUserId != _senderId) {
          _recipientId = chatRoom.studentUserId!;
        } else if (chatRoom.tutorUserId != null &&
            chatRoom.tutorUserId != _senderId) {
          _recipientId = chatRoom.tutorUserId!;
        }
      } else {
        if (widget.connectionId != null && widget.connectionId! > 0) {
          final chatRoom = await ChatService.getOrCreateChatRoom(
            widget.connectionId!,
            _senderId,
          );
          _chatRoomId = chatRoom.id;
          if (chatRoom.studentUserId != null &&
              chatRoom.studentUserId != _senderId) {
            _recipientId = chatRoom.studentUserId!;
          } else if (chatRoom.tutorUserId != null &&
              chatRoom.tutorUserId != _senderId) {
            _recipientId = chatRoom.tutorUserId!;
          }
        } else {
          throw Exception('No studentUserId or connectionId provided');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting chat room: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to open chat: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMessages() async {
    if (_chatRoomId == 0) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final messages = await ChatService.getMessages(_chatRoomId, _senderId);

      setState(() {
        _messages = messages.reversed.toList();
        _messageIds = _messages.map((m) => m.id).toSet();
        _isLoading = false;
      });
      _scrollToBottom();

      await _markRoomAsRead();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRoomAsRead() async {
    try {
      await ChatService.markAllAsRead(_chatRoomId, _senderId);
      await NotificationApiService.markRoomNotificationsRead(
          _chatRoomId, _senderId);
      await NotificationService.instance.refreshBadge();
      final newCount = await ChatService.getUnreadCount(_senderId);
      UnreadCountService().updateUnreadCount(newCount);
      debugPrint('✅ Marked room $_chatRoomId as read — unread now $newCount');
    } catch (e) {
      debugPrint('❌ markAsRead failed: $e');
    }
  }

  void _connectWebSocket() {
    WebSocketService.instance.connect(_senderId);
    WebSocketService.instance.removeListener(_onNewMessage);
    WebSocketService.instance.addListener(_onNewMessage);
  }

  // ============================================================
  // WS handler — bulletproof dedupe
  // ============================================================
  void _onNewMessage(Message message) {
    if (message.chatRoomId != _chatRoomId && _chatRoomId != 0) return;

    debugPrint('🔔 [WS] id=${message.id}, isOwn=${message.isOwn}, '
        'content=${message.content}, fileUrl=${message.fileUrl}');

    setState(() {
      // 1. Real id already present → skip
      if (message.id > 0 && _messageIds.contains(message.id)) {
        debugPrint('⏭️ Skip WS echo id=${message.id}');
        return;
      }

      // 2. Own message → find the MATCHING optimistic (not just any)
      if (message.isOwn) {
        final optIdx = _messages.indexWhere((m) =>
        m.id < 0 &&
            m.content == message.content &&                    // ✅ content match
            m.fileName == message.fileName);                   // ✅ name match

        if (optIdx != -1) {
          debugPrint('🔄 Replace optimistic id=${message.id}');
          _messages[optIdx] = message..localStatus = MessageStatus.sent;
          _messageIds.removeWhere((id) => id < 0);
          _messageIds.add(message.id);
          return;
        }

        // ✅ If no matching optimistic found → the sender's own optimistic
        //    hasn't been added yet (race). Just add the real message.
      }

      // 3. Brand new → add
      debugPrint('➕ Add WS message id=${message.id}');
      _messageIds.add(message.id);
      _messages.add(message);
    });

    _scrollToBottom();
  }

  // ============================================
  // TEXT MESSAGE
  // ============================================
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    debugPrint('💬 [TEXT] starting, '
        'messages=${_messages.map((m) => "${m.id}:${m.localStatus}").toList()}');
    setState(() => _isSending = true);

    try {
      if (_chatRoomId > 0 && _recipientId > 0) {
        final request = SendMessageRequest(
          chatRoomId: _chatRoomId,
          senderId: _senderId,
          recipientId: _recipientId,
          content: text,
          replyToMessageId: _replyingTo?.id,
        );
        final message = await ChatService.sendMessage(request);

        setState(() {
          if (!_messageIds.contains(message.id)) {
            _messageIds.add(message.id);
            _messages.add(message);
          }
          _messageController.clear();
          _isSending = false;
          _replyingTo = null;
        });

        WebSocketService.instance.sendMessage(message);

        final unreadCount = await ChatService.getUnreadCount(_senderId);
        UnreadCountService().updateUnreadCount(unreadCount);
      } else {
        setState(() => _isSending = false);
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ============================================
  // AUDIO MESSAGE
  // ============================================
  Future<void> _sendAudioMessage(File audioFile, int duration) async {
    try {
      setState(() {
        _isSending = true;
        _showAudioRecorder = false;
      });

      final audioUrl = await ChatService.uploadAudio(audioFile, _senderId);

      if (_chatRoomId > 0 && _recipientId > 0) {
        final request = SendMessageRequest(
          chatRoomId: _chatRoomId,
          senderId: _senderId,
          recipientId: _recipientId,
          content: '🎵 Audio message',
          audioUrl: audioUrl,
          audioDuration: duration,
          replyToMessageId: _replyingTo?.id,
        );
        final message = await ChatService.sendMessage(request);

        setState(() {
          if (!_messageIds.contains(message.id)) {
            _messageIds.add(message.id);
            _messages.add(message);
          }
          _isSending = false;
          _replyingTo = null;
        });

        WebSocketService.instance.sendMessage(message);

        final unreadCount = await ChatService.getUnreadCount(_senderId);
        UnreadCountService().updateUnreadCount(unreadCount);

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Error sending audio: $e');
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send audio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================
  // FILE / DOCUMENT
  // ============================================
  void _showAttachmentSheet() {
    AttachmentSheet.show(
      context,
      onDocument: _pickDocument,
      onGallery: _pickFromGallery,
      onCamera: _pickFromCamera,
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final files = <FilePreview>[];
      for (final pf in result.files) {
        if (pf.path == null) continue;
        final file = File(pf.path!);
        final size = await file.length();
        if (size > 20 * 1024 * 1024) continue;

        String ext = 'file';
        if (pf.name.contains('.')) {
          ext = pf.name.split('.').last.toLowerCase();
        }
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

        files.add(FilePreview(
          file: file,
          fileName: pf.name,
          fileSize: size,
          fileType: ext,
          isImage: isImage,
          status: FilePreviewStatus.ready,
        ));
      }

      if (files.isEmpty) return;
      setState(() => _pendingFiles = files);
    } catch (e) {
      debugPrint('❌ Document pick error: $e');
    }
  }

  // ============================================================
  // GALLERY — instant preview + background compression
  // ============================================================
  Future<void> _pickFromGallery() async {
    debugPrint('🚨 _pickFromGallery CALLED');

    try {
      final List<XFile> picked = await _imagePicker.pickMultipleMedia(
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      // ────────────────────────────────────────────────
      // STEP 1: Add all files to preview INSTANTLY
      // ────────────────────────────────────────────────
      final initialFiles = <FilePreview>[];
      for (final xFile in picked) {
        final name = xFile.name.toLowerCase();
        final isVideo = name.endsWith('.mp4') ||
            name.endsWith('.mov') ||
            name.endsWith('.webm') ||
            name.endsWith('.mkv') ||
            name.endsWith('.avi') ||
            name.endsWith('.3gp');
        final isImage = name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png') ||
            name.endsWith('.gif') ||
            name.endsWith('.webp');

        final file = File(xFile.path);
        final size = await file.length();

        String ext = isVideo ? 'mp4' : 'jpg';
        if (name.contains('.')) ext = name.split('.').last.toLowerCase();

        initialFiles.add(FilePreview(
          file: file,
          fileName: xFile.name,
          fileSize: size,
          fileType: ext,
          isImage: isImage,
          status: isVideo
              ? FilePreviewStatus.processing
              : FilePreviewStatus.ready,
        ));
      }

      setState(() => _pendingFiles = initialFiles);

      // ────────────────────────────────────────────────
      // STEP 2: Compress videos in the background
      // ────────────────────────────────────────────────
      for (int i = 0; i < picked.length; i++) {
        final xFile = picked[i];
        final name = xFile.name.toLowerCase();
        final isVideo = name.endsWith('.mp4') ||
            name.endsWith('.mov') ||
            name.endsWith('.webm') ||
            name.endsWith('.mkv') ||
            name.endsWith('.avi') ||
            name.endsWith('.3gp');

        if (!isVideo) continue;

        File file = File(xFile.path);
        int size = await file.length();
        final sizeMB = size / 1024 / 1024;

        // Skip small videos
        if (sizeMB <= 15) {
          debugPrint('✅ Small video ($sizeMB MB) — skipped');
          _markPreviewReady(xFile.name);
          continue;
        }

        // Cap duration at 3 minutes
        try {
          final videoController = VideoPlayerController.file(file);
          await videoController.initialize().timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw Exception('Video probe timeout'),
          );
          final duration = videoController.value.duration;
          await videoController.dispose();

          if (duration.inMinutes >= 3) {
            debugPrint('⚠️ Video too long — refusing');
            _removePreview(xFile.name);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video too long (max 3 minutes)'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            continue;
          }
        } catch (e) {
          debugPrint('⚠️ Duration probe failed: $e — proceeding');
        }

        // Compress
        debugPrint('🎬 Compressing ${xFile.name} '
            '(${sizeMB.toStringAsFixed(1)} MB)...');

        try {
          final tempDir = await getTemporaryDirectory();
          final outputPath =
              '${tempDir.path}/ffmpeg_${DateTime.now().millisecondsSinceEpoch}.mp4';

          final session = await FFmpegKit.execute(
            '-y -i "${xFile.path}" '
                '-vf "scale=360:-2,format=yuv420p" '
                '-c:v libx264 '
                '-profile:v baseline '
                '-level 3.0 '
                '-preset ultrafast '
                '-crf 30 '
                '-pix_fmt yuv420p '
                '-r 24 '
                '-c:a aac '
                '-b:a 64k '
                '-ar 44100 '
                '-ac 2 '
                '-movflags +faststart '
                '"$outputPath"',
          );

          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            final compressedFile = File(outputPath);
            if (await compressedFile.exists()) {
              final newSize = await compressedFile.length();
              if (newSize > 0) {
                debugPrint('✅ FFMPEG OK (${newSize ~/ 1024} KB)');
                _updatePreviewWithCompressed(
                    xFile.name, compressedFile, newSize);
                continue;
              }
            }
          }

          debugPrint('❌ FFMPEG FAILED — using original');
          _markPreviewReady(xFile.name);
        } catch (e) {
          debugPrint('❌ FFMPEG EXCEPTION: $e');
          _markPreviewReady(xFile.name);
        }
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
    }
  }

  // ✅ Helper: update preview with compressed file
  void _updatePreviewWithCompressed(
      String originalName, File compressed, int newSize) {
    setState(() {
      final idx = _pendingFiles.indexWhere((p) => p.fileName == originalName);
      if (idx != -1) {
        _pendingFiles[idx] = FilePreview(
          file: compressed,
          fileName:
          'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          fileSize: newSize,
          fileType: 'mp4',
          isImage: false,
          status: FilePreviewStatus.ready,
        );
      }
    });
  }

  // ✅ Helper: mark preview ready
  void _markPreviewReady(String fileName) {
    setState(() {
      final idx = _pendingFiles.indexWhere((p) => p.fileName == fileName);
      if (idx != -1) {
        _pendingFiles[idx].status = FilePreviewStatus.ready;
      }
    });
  }

  // ✅ Helper: remove a preview
  void _removePreview(String fileName) {
    setState(() {
      _pendingFiles.removeWhere((p) => p.fileName == fileName);
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) return;

      String ext = 'jpg';
      if (picked.name.contains('.')) {
        ext = picked.name.split('.').last.toLowerCase();
      }

      setState(() {
        _pendingFiles = [
          FilePreview(
            file: file,
            fileName: picked.name,
            fileSize: size,
            fileType: ext,
            isImage: true,
            status: FilePreviewStatus.ready,
          ),
        ];
      });
    } catch (e) {
      debugPrint('❌ Camera pick error: $e');
    }
  }

  // ============================================
  // SEND FILES — optimistic + no duplicate
  // ============================================
  Future<void> _sendPendingFiles() async {
    if (_pendingFiles.isEmpty) return;

    // Guard: block if any file is still processing
    if (_pendingFiles.any((p) => p.status == FilePreviewStatus.processing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait — files are being prepared'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final toSend = List<FilePreview>.from(_pendingFiles);
    final replyTo = _replyingTo;

    setState(() {
      _pendingFiles = [];
      _replyingTo = null;
    });

    for (final preview in toSend) {
      await _sendFileOptimistically(preview, replyTo);
    }
  }

  Future<void> _sendFileOptimistically(
      FilePreview preview, Message? replyTo) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final optimistic = Message.optimistic(
      id: tempId,
      chatRoomId: _chatRoomId,
      senderId: _senderId,
      senderName: 'You',
      recipientId: _recipientId,
      content: '📎 ${preview.fileName}',
      fileUrl: preview.file.path,
      fileName: preview.fileName,
      fileSize: preview.fileSize,
      fileType: preview.fileType,
      replyToMessageId: replyTo?.id,
      localStatus: MessageStatus.uploading,
    );

    setState(() {
      _messageIds.add(tempId);
      _messages.add(optimistic);
    });
    debugPrint('📁 [FILE] optimistic added id=$tempId, '
        'messages=${_messages.map((m) => "${m.id}:${m.localStatus}").toList()}');

    _scrollToBottom();

    try {
      final uploadData = await ChatService.uploadFile(
        preview.file,
        _senderId,
      );

      if (_chatRoomId <= 0 || _recipientId <= 0) return;

      final request = SendMessageRequest(
        chatRoomId: _chatRoomId,
        senderId: _senderId,
        recipientId: _recipientId,
        content: '📎 ${uploadData['fileName']}',
        fileUrl: uploadData['fileUrl'],
        fileName: uploadData['fileName'],
        fileSize: uploadData['fileSize'],
        fileType: uploadData['fileType'],
        replyToMessageId: replyTo?.id,
      );
      final real = await ChatService.sendMessage(request);

      debugPrint('📁 [FILE] real message id=${real.id}, '
          'current=${_messages.map((m) => "${m.id}:${m.localStatus}").toList()}');


      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        debugPrint('📁 [FILE] replace: tempId=$tempId, idx=$idx');
        if (idx != -1) {
          _messages[idx] = real..localStatus = MessageStatus.sent;
          _messageIds.remove(tempId);
          _messageIds.add(real.id);
          debugPrint('📁 [FILE] replaced OK, '
              'messages=${_messages.map((m) => "${m.id}:${m.localStatus}").toList()}');
        } else {
          debugPrint('⏭️ Optimistic already replaced by WS');
        }
      });

      WebSocketService.instance.sendMessage(real);

      final unread = await ChatService.getUnreadCount(_senderId);
      UnreadCountService().updateUnreadCount(unread);
    } catch (e) {
      debugPrint('❌ Send file failed: $e');
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx].localStatus = MessageStatus.failed;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send ${preview.fileName}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelPendingFile() {
    setState(() => _pendingFiles = []);
  }

  // ============================================
  // MULTI-SELECT
  // ============================================
  void _onMessageLongPress(Message message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(message.id);
    });
  }

  void _onMessageTap(Message message) {
    if (!_isSelectionMode) return;
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _replyToSelectedMessage() {
    if (_selectedMessageIds.length != 1) return;
    final id = _selectedMessageIds.first;
    final message = _messages.firstWhere((m) => m.id == id);
    setState(() {
      _replyingTo = message;
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _copySelectedMessage() async {
    if (_selectedMessageIds.length != 1) return;

    final id = _selectedMessageIds.first;
    final message = _messages.firstWhere((m) => m.id == id);

    await Clipboard.setData(ClipboardData(text: message.content));

    // Exit selection mode
    _cancelSelection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final selectedMessages = _messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    final success = await ForwardPickerSheet.show(context, selectedMessages);
    if (success == true && mounted) {
      final count = selectedMessages.length;
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forwarded $count message${count > 1 ? 's' : ''}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final count = _selectedMessageIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Delete Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Delete $count message${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selectedMessageIds.toList()) {
        await ChatService.deleteMessage(id, _senderId);
      }
      setState(() {
        _messages.removeWhere((m) => _selectedMessageIds.contains(m.id));
        _messageIds.removeAll(_selectedMessageIds);
        _isSelectionMode = false;
        _selectedMessageIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count message${count > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  Future<void> _deleteAllMessages() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Messages'),
        content: Text(
          'Are you sure you want to delete all messages in this chat with ${widget.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      for (var message in _messages) {
        await ChatService.deleteMessage(message.id, _senderId);
      }
      setState(() {
        _messages.clear();
        _messageIds.clear();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All messages deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting all messages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _scrollToMessage(int? messageId) async {
    if (messageId == null) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    final estimatedOffset = index * 80.0;
    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final target = estimatedOffset.clamp(0.0, maxExtent);

    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    setState(() => _highlightedMessageId = messageId);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _highlightedMessageId = null);
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final diff = today.difference(date).inDays;

    int hour = time.hour;
    final minute = time.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final timeStr = "$hour12:${minute.toString().padLeft(2, '0')} $amPm";

    if (diff == 0) return timeStr;
    if (diff == 1) return "Yesterday $timeStr";
    if (diff < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return "${weekdays[time.weekday - 1]} $timeStr";
    }
    return "${date.day}/${date.month}/${date.year} $timeStr";
  }

  @override
  void dispose() {
    WebSocketService.instance.removeListener(_onNewMessage);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userImageUrl =
    widget.userImage != null && widget.userImage!.isNotEmpty
        ? '${ApiConfig.baseUrl}${widget.userImage}'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(userImageUrl),
            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Colors.black))
                  : _messages.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("No messages yet",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 16)),
                    Text("Start the conversation!",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final bool isMe = message.senderId == _senderId;
                  final bool isSelected =
                  _selectedMessageIds.contains(message.id);
                  final bool isHighlighted =
                      message.id == _highlightedMessageId;

                  return GestureDetector(
                    onLongPress: () => _onMessageLongPress(message),
                    onTap: () => _onMessageTap(message),
                    child: _buildMessageBubble(
                      message,
                      isMe,
                      isSelected,
                      isHighlighted,
                    ),
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String? userImageUrl) {
    if (_isSelectionMode) {
      final count = _selectedMessageIds.length;
      final canReply = count == 1;

      // ✅ Can copy only when exactly ONE text message is selected
      final selectedMsgs = _messages
          .where((m) => _selectedMessageIds.contains(m.id))
          .toList();
      final canCopy = selectedMsgs.length == 1 &&
          (selectedMsgs.first.fileUrl == null ||
              selectedMsgs.first.fileUrl!.isEmpty) &&
          (selectedMsgs.first.audioUrl == null ||
              selectedMsgs.first.audioUrl!.isEmpty) &&
          selectedMsgs.first.content.trim().isNotEmpty;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _cancelSelection,
              child: Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.black, size: 20),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                count == 1 ? '1 selected' : '$count selected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // ✅ NEW — Copy icon (only when one text message selected)
            if (canCopy)
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 24),
                onPressed: _copySelectedMessage,
                tooltip: 'Copy',
              ),

            if (canReply)
              IconButton(
                icon: const Icon(Icons.reply, color: Colors.white, size: 26),
                onPressed: _replyToSelectedMessage,
                tooltip: 'Reply',
              ),
            IconButton(
              icon: const Icon(Icons.forward, color: Colors.white, size: 26),
              onPressed: _forwardSelectedMessages,
              tooltip: 'Forward',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white, size: 26),
              onPressed: _deleteSelectedMessages,
              tooltip: 'Delete',
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 40,
              width: 40,
              decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle),
              child:
              const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage:
            userImageUrl != null ? NetworkImage(userImageUrl) : null,
            child: userImageUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.userName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete_all') _deleteAllMessages();
            },
            icon: const Icon(Icons.more_vert, color: Colors.black, size: 28),
            color: Colors.white,
            elevation: 8,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'delete_all',
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.delete_sweep_outlined,
                        color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Delete All Messages',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Message message,
      bool isMe,
      bool isSelected,
      bool isHighlighted,
      ) {
    final bool isAudio =
        message.audioUrl != null && message.audioUrl!.isNotEmpty;

    final bool isVideo = message.fileUrl != null &&
        message.fileUrl!.isNotEmpty &&
        (message.fileType?.toLowerCase() == 'mp4' ||
            message.fileType?.toLowerCase() == 'mov' ||
            message.fileType?.toLowerCase() == 'webm' ||
            message.fileType?.toLowerCase() == 'mkv' ||
            message.fileType?.toLowerCase() == 'avi');

    final bool isImage = message.fileUrl != null &&
        message.fileUrl!.isNotEmpty &&
        (message.fileType?.toLowerCase() == 'jpg' ||
            message.fileType?.toLowerCase() == 'jpeg' ||
            message.fileType?.toLowerCase() == 'png' ||
            message.fileType?.toLowerCase() == 'gif' ||
            message.fileType?.toLowerCase() == 'webp');

    final bool isFile = message.fileUrl != null &&
        message.fileUrl!.isNotEmpty &&
        !isImage &&
        !isVideo;

    final bool isSpecial = isAudio || isImage || isVideo || isFile;
    final bool hasReply = message.replyToMessageId != null;

    return Container(
      color: isSelected
          ? Colors.black.withOpacity(0.08)
          : (isHighlighted
          ? Colors.yellow.withOpacity(0.25)
          : Colors.transparent),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child:
                const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSpecial || hasReply ? 8 : 14,
                    vertical: isSpecial || hasReply ? 6 : 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.black : Colors.grey.shade300,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasReply)
                        GestureDetector(
                          onTap: () =>
                              _scrollToMessage(message.replyToMessageId),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe ? Colors.white : Colors.blue,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.replyToSenderName ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.white : Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.replyToContent ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (isAudio)
                        AudioPlayerWidget(
                          audioUrl: message.audioUrl!,
                          isMe: isMe,
                          durationInSeconds: message.audioDuration,
                          messageId: message.id,
                        )
                      else if (isImage)
                        ImageMessageWidget(
                          imageUrl: message.fileUrl!,
                          isMe: isMe,
                        )
                      else if (isVideo)
                          VideoMessageWidget(
                            videoUrl: message.fileUrl!,
                            isMe: isMe,
                            localStatus: message.localStatus,
                          )
                        else if (isFile)
                            FileMessageWidget(
                              fileUrl: message.fileUrl!,
                              fileName: message.fileName ?? 'file',
                              fileSize: message.fileSize,
                              fileType: message.fileType,
                              isMe: isMe,
                            )
                          else
                            Linkify(
                              onOpen: (link) async {
                                final uri = Uri.tryParse(link.url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              text: message.content,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                              linkStyle: TextStyle(
                                color: isMe ? Colors.lightBlueAccent : Colors.blue,
                                decoration: TextDecoration.underline,
                                decorationColor: isMe ? Colors.lightBlueAccent : Colors.blue,
                              ),
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.sentAt),
                        style:
                        const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Message message) {
    switch (message.localStatus) {
      case MessageStatus.sending:
      case MessageStatus.uploading:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.blue,
          ),
        );
      case MessageStatus.failed:
        return const Icon(Icons.error, size: 14, color: Colors.red);
      case MessageStatus.sent:
        return Icon(
          message.isRead ? Icons.done_all : Icons.done,
          size: 14,
          color: message.isRead ? Colors.blue : Colors.grey,
        );
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
    }
  }

  Widget _buildMessageInput() {
    if (_isSelectionMode) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null)
          ReplyPreviewWidget(
            message: _replyingTo!,
            onCancel: _cancelReply,
          ),
        if (_pendingFiles.isNotEmpty)
          FilePreviewWidget(
            previews: _pendingFiles,
            isUploading: _isUploadingFile,
            onCancel: _cancelPendingFile,
            onSend: _sendPendingFiles,
            onRemove: (index) {
              setState(() {
                _pendingFiles.removeAt(index);
                if (_pendingFiles.isEmpty) _pendingFiles = [];
              });
            },
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.only(
                  bottom:
                  MediaQuery.of(context).viewInsets.bottom == 0 ? 10 : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _showAudioRecorder
                    ? AudioRecorderWidget(
                  onSend: (file, duration) async {
                    await _sendAudioMessage(file, duration);
                  },
                  onCancel: () {
                    setState(() => _showAudioRecorder = false);
                  },
                )
                    : Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file,
                          color: Colors.black),
                      onPressed: _showAttachmentSheet,
                      tooltip: 'Attach',
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: Colors.black),
                      onPressed: () {
                        setState(() => _showAudioRecorder = true);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isSending,
                        decoration: const InputDecoration(
                          hintText: "Type message...",
                          border: InputBorder.none,
                          contentPadding:
                          EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}