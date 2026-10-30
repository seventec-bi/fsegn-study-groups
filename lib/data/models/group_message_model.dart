/// Model representing a group chat text message.
class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String senderName;
  final String? senderAvatarPath;

  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.senderName = 'Étudiant FSEGN',
    this.senderAvatarPath,
  });

  factory GroupMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    String name = 'Étudiant FSEGN';
    String? avatarPath;
    final profile = json['profiles'];
    if (profile is Map<String, dynamic>) {
      name = profile['display_name'] as String? ?? name;
      avatarPath = profile['avatar_path'] as String?;
    } else {
      name = json['sender_name'] as String? ?? name;
      avatarPath = json['sender_avatar_path'] as String?;
    }

    return GroupMessageModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: name,
      senderAvatarPath: avatarPath,
    );
  }
}
