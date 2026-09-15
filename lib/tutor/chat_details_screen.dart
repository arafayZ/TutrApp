// lib/tutor/chat_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
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

  // File preview state
  List<FilePreview> _pendingFiles = [];
  bool _isUploadingFile = false;

  // Reply state
  Message? _replyingTo;

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<int> _selectedMessageIds = {};

  // ✅ Highlight state (for tap-to-scroll on reply)
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

    print('🔍 Tutor Chat Init:');
    print('   Sender (Tutor) User ID: $_senderId');
    print('   Recipient (Student) User ID: $_recipientId');

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

      if (widget.studentUserId != null && widget.studentUserId! > 0 && _senderId > 0) {
        final chatRoom = await ChatService.getOrCreateSharedChatRoom(
          widget.studentUserId!,
          _senderId,
          _senderId,
        );
        _chatRoomId = chatRoom.id;

        if (chatRoom.studentUserId != null && chatRoom.studentUserId != _senderId) {
          _recipientId = chatRoom.studentUserId!;
        } else if (chatRoom.tutorUserId != null && chatRoom.tutorUserId != _senderId) {
          _recipientId = chatRoom.tutorUserId!;
        }
      } else {
        if (widget.connectionId != null && widget.connectionId! > 0) {
          final chatRoom = await ChatService.getOrCreateChatRoom(
            widget.connectionId!,
            _senderId,
          );
          _chatRoomId = chatRoom.id;
          if (chatRoom.studentUserId != null && chatRoom.studentUserId != _senderId) {
            _recipientId = chatRoom.studentUserId!;
          } else if (chatRoom.tutorUserId != null && chatRoom.tutorUserId != _senderId) {
            _recipientId = chatRoom.tutorUserId!;
          }
        } else {
          throw Exception('No studentUserId or connectionId provided');
        }
      }
    } catch (e) {
      print('❌ Error getting chat room: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: ${e.toString().replaceFirst('Exception: ', '')}'),
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

      // Mark as read (fixes unread badge when opened via notification)
      await _markRoomAsRead();
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Marks current room as read + refreshes global badge
  Future<void> _markRoomAsRead() async {
    try {
      await ChatService.markAllAsRead(_chatRoomId, _senderId);

      final newCount = await ChatService.getUnreadCount(_senderId);
      UnreadCountService().updateUnreadCount(newCount);
      await NotificationService.instance.updateBadge(newCount);

      print('✅ Marked room $_chatRoomId as read — unread now $newCount');
    } catch (e) {
      print('❌ markAsRead failed: $e');
    }
  }

  void _connectWebSocket() {
    WebSocketService.instance.connect(_senderId);
    WebSocketService.instance.addListener(_onNewMessage);
  }

  void _onNewMessage(Message message) {
    if (message.chatRoomId == _chatRoomId || _chatRoomId == 0) {
      setState(() {
        if (!_messageIds.contains(message.id)) {
          _messageIds.add(message.id);
          _messages.add(message);
        }
      });
      _scrollToBottom();
    }
  }

  // ============================================
  // TEXT MESSAGE
  // ============================================
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

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
      print('Error sending message: $e');
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red),
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
      print('❌ Error sending audio: $e');
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
        ));
      }

      if (files.isEmpty) return;
      setState(() => _pendingFiles = files);
    } catch (e) {
      print('❌ Document pick error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (picked.isEmpty) return;

      final files = <FilePreview>[];
      for (final xFile in picked) {
        final file = File(xFile.path);
        final size = await file.length();
        if (size > 20 * 1024 * 1024) continue;

        String ext = 'jpg';
        if (xFile.name.contains('.')) {
          ext = xFile.name.split('.').last.toLowerCase();
        }

        files.add(FilePreview(
          file: file,
          fileName: xFile.name,
          fileSize: size,
          fileType: ext,
          isImage: true,
        ));
      }

      if (files.isEmpty) return;
      setState(() => _pendingFiles = files);
    } catch (e) {
      print('❌ Gallery pick error: $e');
    }
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
          ),
        ];
      });
    } catch (e) {
      print('❌ Camera pick error: $e');
    }
  }

  Future<void> _sendPendingFiles() async {
    if (_pendingFiles.isEmpty) return;

    setState(() => _isUploadingFile = true);

    try {
      for (final preview in _pendingFiles) {
        final uploadData = await ChatService.uploadFile(
          preview.file,
          _senderId,
        );

        if (_chatRoomId > 0 && _recipientId > 0) {
          final request = SendMessageRequest(
            chatRoomId: _chatRoomId,
            senderId: _senderId,
            recipientId: _recipientId,
            content: '📎 ${uploadData['fileName']}',
            fileUrl: uploadData['fileUrl'],
            fileName: uploadData['fileName'],
            fileSize: uploadData['fileSize'],
            fileType: uploadData['fileType'],
            replyToMessageId: _replyingTo?.id,
          );

          final message = await ChatService.sendMessage(request);

          setState(() {
            if (!_messageIds.contains(message.id)) {
              _messageIds.add(message.id);
              _messages.add(message);
            }
          });

          WebSocketService.instance.sendMessage(message);
        }
      }

      final unreadCount = await ChatService.getUnreadCount(_senderId);
      UnreadCountService().updateUnreadCount(unreadCount);

      setState(() {
        _pendingFiles = [];
        _isUploadingFile = false;
        _replyingTo = null;
      });

      _scrollToBottom();
    } catch (e) {
      print('❌ File send error: $e');
      setState(() => _isUploadingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send files: ${e.toString()}'),
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
  // MULTI-SELECT LOGIC
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
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
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
      print('Error deleting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // DELETE ALL
  // ============================================
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
      print('Error deleting all messages: $e');
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

  // ✅ Scroll to a specific message by ID + briefly highlight it
  Future<void> _scrollToMessage(int? messageId) async {
    if (messageId == null) return;

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0) {
      debugPrint('⚠️ Message $messageId not in current list');
      return;
    }

    // Estimate offset: each bubble ~80px tall on average
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

    // Brief highlight
    setState(() => _highlightedMessageId = messageId);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _highlightedMessageId = null);
    }
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
    final userImageUrl = widget.userImage != null && widget.userImage!.isNotEmpty
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
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _messages.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("No messages yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    Text("Start the conversation!", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  final bool isSelected = _selectedMessageIds.contains(message.id);
                  final bool isHighlighted = message.id == _highlightedMessageId;

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

  // HEADER — normal or selection mode
  Widget _buildHeader(String? userImageUrl) {
    if (_isSelectionMode) {
      final count = _selectedMessageIds.length;
      final canReply = count == 1;

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
                '$count message${count > 1 ? 's' : ''} selected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: userImageUrl != null ? NetworkImage(userImageUrl) : null,
            child: userImageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete_all') {
                _deleteAllMessages();
              }
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
                    Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20),
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

  // MESSAGE BUBBLE with selection highlight + reply-tap-to-scroll + highlighted message
  Widget _buildMessageBubble(
      Message message,
      bool isMe,
      bool isSelected,
      bool isHighlighted,
      ) {
    final bool isAudio = message.audioUrl != null && message.audioUrl!.isNotEmpty;

    final bool isImage = message.fileUrl != null &&
        message.fileUrl!.isNotEmpty &&
        (message.fileType?.toLowerCase() == 'jpg' ||
            message.fileType?.toLowerCase() == 'jpeg' ||
            message.fileType?.toLowerCase() == 'png' ||
            message.fileType?.toLowerCase() == 'gif' ||
            message.fileType?.toLowerCase() == 'webp');

    final bool isFile = message.fileUrl != null &&
        message.fileUrl!.isNotEmpty &&
        !isImage;

    final bool isSpecial = isAudio || isImage || isFile;
    final bool hasReply = message.replyToMessageId != null;

    return Container(
      color: isSelected
          ? Colors.black.withOpacity(0.08)
          : (isHighlighted
          ? Colors.yellow.withOpacity(0.25)
          : Colors.transparent),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasReply)
                      // ✅ Tap the reply preview → scroll to the original message
                        GestureDetector(
                          onTap: () => _scrollToMessage(message.replyToMessageId),
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
                                    color: isMe ? Colors.white70 : Colors.black54,
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
                      else if (isFile)
                          FileMessageWidget(
                            fileUrl: message.fileUrl!,
                            fileName: message.fileName ?? 'file',
                            fileSize: message.fileSize,
                            fileType: message.fileType,
                            isMe: isMe,
                          )
                        else
                          Text(
                            message.content,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
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
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead ? Colors.blue : Colors.grey,
                        ),
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

  // MESSAGE INPUT
  Widget _buildMessageInput() {
    if (_isSelectionMode) {
      return const SizedBox.shrink();
    }

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
                if (_pendingFiles.isEmpty) {
                  _pendingFiles = [];
                }
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
                  bottom: MediaQuery.of(context).viewInsets.bottom == 0 ? 10 : 0,
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
                      icon: const Icon(Icons.attach_file, color: Colors.black),
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
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
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