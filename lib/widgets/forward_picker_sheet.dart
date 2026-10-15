import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../config/api_config.dart';

class ForwardPickerSheet extends StatefulWidget {
  final List<Message> messages;

  const ForwardPickerSheet({super.key, required this.messages});

  static Future<bool?> show(BuildContext context, List<Message> messages) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardPickerSheet(messages: messages),
    );
  }

  @override
  State<ForwardPickerSheet> createState() => _ForwardPickerSheetState();
}

class _ForwardPickerSheetState extends State<ForwardPickerSheet> {
  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  bool _isForwarding = false;
  int _userId = 0;

  // ✅ Multi-select chats
  final Set<int> _selectedRoomIds = {};

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    if (_userId == 0) {
      _userId = prefs.getInt('profileId') ?? 0;
    }

    try {
      final rooms = await ChatService.getUserChatRooms(_userId);
      setState(() {
        _chatRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rooms: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleRoomSelection(ChatRoom room) {
    setState(() {
      if (_selectedRoomIds.contains(room.id)) {
        _selectedRoomIds.remove(room.id);
      } else {
        _selectedRoomIds.add(room.id);
      }
    });
  }

  // ✅ Forward all selected messages to all selected chats
  Future<void> _forwardToSelectedChats() async {
    if (_selectedRoomIds.isEmpty) return;

    setState(() => _isForwarding = true);

    try {
      int totalSent = 0;

      // Loop through selected chat rooms
      for (final roomId in _selectedRoomIds) {
        final room = _chatRooms.firstWhere((r) => r.id == roomId);
        final recipientId = room.studentUserId == _userId
            ? (room.tutorUserId ?? 0)
            : (room.studentUserId ?? 0);

        // Loop through all messages being forwarded
        for (final message in widget.messages) {
          final request = SendMessageRequest(
            chatRoomId: room.id,
            senderId: _userId,
            recipientId: recipientId,
            content: message.content,
            audioUrl: message.audioUrl,
            audioDuration: message.audioDuration,
            fileUrl: message.fileUrl,
            fileName: message.fileName,
            fileSize: message.fileSize,
            fileType: message.fileType,
            latitude: message.latitude,
            longitude: message.longitude,
          );

          await ChatService.sendMessage(request);
          totalSent++;
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Forward error: $e');
      setState(() => _isForwarding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: ${e.toString()}'),
            backgroundColor: Colors.red,   // ✅ Red for error
          ),
        );
      }
    }
  }

  String _getMessagePreview() {
    if (widget.messages.length == 1) {
      final m = widget.messages.first;
      if (m.audioUrl != null && m.audioUrl!.isNotEmpty) {
        return '🎵 Audio message';
      }
      if (m.fileUrl != null && m.fileUrl!.isNotEmpty) {
        return '📎 ${m.fileName ?? "File"}';
      }
      return m.content;
    }
    return '${widget.messages.length} messages';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedRoomIds.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ✅ HEADER with Send button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Title
                    const Icon(Icons.forward, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      widget.messages.length == 1
                          ? 'Forward message'
                          : 'Forward ${widget.messages.length} messages',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),

                    // ✅ Send button (top right)
                    if (selectedCount > 0 && !_isForwarding)
                      TextButton.icon(
                        onPressed: _forwardToSelectedChats,
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          'Send (${selectedCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                    // Loading
                    if (_isForwarding)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Message preview
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forward, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getMessagePreview(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ✅ Chat list with multi-select
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _chatRooms.isEmpty
                    ? const Center(
                  child: Text(
                    'No chats available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.separated(
                  controller: scrollController,
                  itemCount: _chatRooms.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final room = _chatRooms[index];
                    final isMeStudent = room.studentUserId == _userId;
                    final name =
                    isMeStudent ? room.tutorName : room.studentName;
                    final image =
                    isMeStudent ? room.tutorImage : room.studentImage;

                    final isSelected = _selectedRoomIds.contains(room.id);

                    return ListTile(
                      // ✅ Checkbox instead of send icon
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.black,
                            backgroundImage:
                            image != null && image.isNotEmpty
                                ? NetworkImage(
                                '${ApiConfig.baseUrl}$image')
                                : null,
                            child: image == null || image.isEmpty
                                ? const Icon(Icons.person,
                                color: Colors.white)
                                : null,
                          ),
                          // Selection checkmark
                          if (isSelected)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        isMeStudent
                            ? (room.courseName ?? '')
                            : (room.courseName ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // ✅ Selection indicator (checkbox)
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                            : null,
                      ),

                      onTap: _isForwarding
                          ? null
                          : () => _toggleRoomSelection(room),
                    );
                  },
                ),
              ),

              // ✅ Bottom selected count
              if (selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Text(
                          '$selectedCount chat${selectedCount > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedRoomIds.clear());
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}