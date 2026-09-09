class NotificationModel {
  final int id;
  final String title;
  final String content;
  final int? targetUserId;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    this.targetUserId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? 'Notice',
      content: json['content'] ?? '',
      targetUserId: json['target_user_id'] != null ? int.parse(json['target_user_id'].toString()) : null,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] ?? '',
    );
  }
}
