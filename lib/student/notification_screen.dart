import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/status_bar_config.dart';
import '../models/notification_item.dart';
import '../services/notification_api_service.dart';
import '../services/notification_navigator.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _items = [];
  bool _isLoading = true;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    StatusBarConfig.setLightStatusBar();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;

    try {
      final list = await NotificationApiService.getUserNotifications(_userId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTapItem(NotificationItem item) async {
    if (!item.isRead) {
      try {
        await NotificationApiService.markAsRead(item.id, _userId);
        if (mounted) {
          setState(() {
            final i = _items.indexWhere((e) => e.id == item.id);
            if (i >= 0) _items[i] = _items[i].copyWith(isRead: true);
          });
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await NotificationNavigator.open(context, item);
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationApiService.markAllAsRead(_userId);
      setState(() {
        _items = _items.map((e) => e.copyWith(isRead: true)).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark all as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, List<NotificationItem>> _group() {
    final map = <String, List<NotificationItem>>{};
    for (final n in _items) {
      map.putIfAbsent(n.dateGroup, () => []).add(n);
    }
    return map;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'connection_request':
        return Icons.person_add_alt_1_outlined;
      case 'connection_accepted':
        return Icons.check;
      case 'connection_declined':
        return Icons.cancel_outlined;
      case 'new_bid':
        return Icons.sync;
      case 'bid_accepted':
        return Icons.check;
      case 'bid_declined':
        return Icons.cancel_outlined;
      case 'signup_welcome':
        return Icons.celebration_outlined;
      case 'account_approved':
        return Icons.lock_open_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final entry in _group().entries) ...[
                    _SectionHeader(title: entry.key),
                    ...entry.value.map(_buildNotificationItem),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("No notifications yet",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 6),
          Text("You're all caught up!",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // Same header style + 3-dot menu on the right
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 25, 10, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
          ),
          const Text(
            "Notifications",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'read_all') _markAllRead();
              },
              icon: const Icon(Icons.more_vert, color: Colors.black, size: 26),
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
                  value: 'read_all',
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Icon(Icons.done_all, color: Colors.black87, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Mark all as read',
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
          ),
        ],
      ),
    );
  }

  // Same card UI as your original NotificationTile
  Widget _buildNotificationItem(NotificationItem item) {
    final unread = !item.isRead;

    return GestureDetector(
      onTap: () => _onTapItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: unread
              ? Border.all(color: Colors.blue.shade200, width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Icon(_iconFor(item.type), size: 22, color: Colors.black87),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.timeLabel,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}