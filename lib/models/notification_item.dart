class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? referenceId;
  final int? courseId;
  final int? senderId;
  final String? senderName;
  final String? senderImage;
  final bool isRead;
  final DateTime createdAt;
  final String dateGroup;
  final String timeLabel;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    this.courseId,
    this.senderId,
    this.senderName,
    this.senderImage,
    required this.isRead,
    required this.createdAt,
    required this.dateGroup,
    required this.timeLabel,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    // ✅ Try referenceId first, then chatRoomId, then connectionId
    final resolvedRef = _parseInt(json['referenceId'])
        ?? _parseInt(json['chatRoomId'])
        ?? _parseInt(json['connectionId']);

    return NotificationItem(
      id: _parseInt(json['id']) ?? 0,
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      referenceId: resolvedRef,
      courseId: _parseInt(json['courseId']),
      senderId: _parseInt(json['senderId']),
      senderName: json['senderName']?.toString(),
      senderImage: json['senderImage']?.toString(),
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dateGroup: json['dateGroup']?.toString() ?? 'Earlier',
      timeLabel: json['timeLabel']?.toString() ?? '',
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      courseId: courseId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      dateGroup: dateGroup,
      timeLabel: timeLabel,
    );
  }

  /// Helper — accepts int, String, double, or null → int?
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}