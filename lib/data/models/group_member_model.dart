/// Model representing a student's membership in a study group.
///
/// NOTE (Directive #1): Email address is omitted to ensure safe display.
class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String role; // 'creator' | 'member'
  final bool attendanceConfirmed;
  final String
  attendanceStatus; // 'pending' | 'attended' | 'absent' | 'unconfirmed'
  final DateTime? attendanceRecordedAt;
  final DateTime joinedAt;

  // Joined public profile details (safe fields only)
  final String displayName;
  final int reliabilityScore;
  final String? avatarPath;

  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.attendanceConfirmed,
    this.attendanceStatus = 'pending',
    this.attendanceRecordedAt,
    required this.joinedAt,
    this.displayName = 'Étudiant FSEGN',
    this.reliabilityScore = 100,
    this.avatarPath,
  });

  bool get isCreator => role == 'creator';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    String dName = 'Étudiant FSEGN';
    int rScore = 100;
    String? avatarKey;

    if (json['profiles'] is Map<String, dynamic>) {
      final p = json['profiles'] as Map<String, dynamic>;
      dName = p['display_name'] as String? ?? 'Étudiant FSEGN';
      rScore = (p['reliability_score'] as num?)?.toInt() ?? 100;
      avatarKey = p['avatar_path'] as String?;
    } else {
      dName = json['display_name'] as String? ?? 'Étudiant FSEGN';
      rScore = (json['reliability_score'] as num?)?.toInt() ?? 100;
      avatarKey = json['avatar_path'] as String?;
    }

    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      attendanceConfirmed: json['attendance_confirmed'] as bool? ?? false,
      attendanceStatus: json['attendance_status'] as String? ?? 'pending',
      attendanceRecordedAt: json['attendance_recorded_at'] != null
          ? DateTime.parse(json['attendance_recorded_at'] as String)
          : null,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      displayName: dName,
      reliabilityScore: rScore,
      avatarPath: avatarKey,
    );
  }
}
