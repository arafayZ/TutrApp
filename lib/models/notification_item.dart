class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? referenceId;
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
    this.senderId,
    this.senderName,
    this.senderImage,
    required this.isRead,
    required this.createdAt,
    required this.dateGroup,
    required this.timeLabel,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      referenceId: json['referenceId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderImage: json['senderImage'],
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      dateGroup: json['dateGroup'] ?? 'Earlier',
      timeLabel: json['timeLabel'] ?? '',
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      dateGroup: dateGroup,
      timeLabel: timeLabel,
    );
  }
}