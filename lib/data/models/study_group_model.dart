/// Domain model for a study group session.
class StudyGroupModel {
  final String id;
  final String creatorId;
  final String subject;
  final String topic; // Free-text chapter, lesson, or study topic
  final String? description;
  final String meetingLocation;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final String status;
  final String cohortKey;
  final DateTime createdAt;

  // Joined / aggregated attributes for UI convenience
  final String creatorName;
  final int memberCount;
  final bool isUserMember;
  final bool isUserConfirmed;
  final String userAttendanceStatus;

  const StudyGroupModel({
    required this.id,
    required this.creatorId,
    required this.subject,
    required this.topic,
    this.description,
    required this.meetingLocation,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    this.status = 'active',
    this.cohortKey = 'fsegn_l1_bc',
    required this.createdAt,
    this.creatorName = 'Étudiant FSEGN',
    this.memberCount = 1,
    this.isUserMember = false,
    this.isUserConfirmed = false,
    this.userAttendanceStatus = 'pending',
  });

  bool get isEnded => DateTime.now().isAfter(endTime);
  bool get hasStarted => DateTime.now().isAfter(startTime);
  bool get isUpcoming => !isEnded;
  bool get isFull => memberCount >= capacity;
  int get remainingSpots => (capacity - memberCount).clamp(0, capacity);

  factory StudyGroupModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    // Check if member data was joined
    final membersList = json['group_members'] as List<dynamic>?;
    int calculatedMemberCount = json['member_count'] as int? ?? 0;
    bool userMember = false;
    bool userConfirmed = false;
    String userStatus = 'pending';

    if (membersList != null) {
      calculatedMemberCount = membersList.length;
      if (currentUserId != null) {
        for (final m in membersList) {
          if (m is Map<String, dynamic> && m['user_id'] == currentUserId) {
            userMember = true;
            userConfirmed = m['attendance_confirmed'] as bool? ?? false;
            userStatus = m['attendance_status'] as String? ?? 'pending';
            break;
          }
        }
      }
    } else if (currentUserId != null && json['creator_id'] == currentUserId) {
      userMember = json['is_user_member'] as bool? ?? true;
      userConfirmed = json['is_user_confirmed'] as bool? ?? false;
      userStatus = json['user_attendance_status'] as String? ?? 'pending';
    } else {
      userMember = json['is_user_member'] as bool? ?? false;
      userConfirmed = json['is_user_confirmed'] as bool? ?? false;
      userStatus = json['user_attendance_status'] as String? ?? 'pending';
    }

    // Creator name from joined profile
    String cName = 'Étudiant FSEGN';
    if (json['profiles'] is Map<String, dynamic>) {
      cName = json['profiles']['display_name'] as String? ?? 'Étudiant FSEGN';
    } else if (json['creator_name'] is String) {
      cName = json['creator_name'] as String;
    }

    return StudyGroupModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      description: json['description'] as String?,
      meetingLocation: json['meeting_location'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      capacity: (json['capacity'] as num?)?.toInt() ?? 5,
      status: json['status'] as String? ?? 'active',
      cohortKey: json['cohort_key'] as String? ?? 'fsegn_l1_bc',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      creatorName: cName,
      memberCount: calculatedMemberCount > 0
          ? calculatedMemberCount
          : (json['member_count'] as int? ?? 1),
      isUserMember: userMember,
      isUserConfirmed: userConfirmed,
      userAttendanceStatus: userStatus,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'creator_id': creatorId,
      'subject': subject,
      'topic': topic.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'meeting_location': meetingLocation.trim(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'capacity': capacity,
      'status': status,
      'cohort_key': cohortKey,
    };
  }

  StudyGroupModel copyWith({
    String? subject,
    String? topic,
    String? description,
    String? meetingLocation,
    DateTime? startTime,
    DateTime? endTime,
    int? capacity,
    String? status,
    int? memberCount,
    bool? isUserMember,
    bool? isUserConfirmed,
    String? userAttendanceStatus,
  }) {
    return StudyGroupModel(
      id: id,
      creatorId: creatorId,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      cohortKey: cohortKey,
      createdAt: createdAt,
      creatorName: creatorName,
      memberCount: memberCount ?? this.memberCount,
      isUserMember: isUserMember ?? this.isUserMember,
      isUserConfirmed: isUserConfirmed ?? this.isUserConfirmed,
      userAttendanceStatus: userAttendanceStatus ?? this.userAttendanceStatus,
    );
  }
}
