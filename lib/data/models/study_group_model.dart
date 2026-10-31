import 'study_session_model.dart';

/// A persistent study community. Meetings are separate StudySessionModel rows.
class StudyGroupModel {
  final String id;
  final String creatorId;
  final String name;
  final String iconEmoji;
  final String subject;
  final String topic;
  final String? description;
  final int capacity;
  final String status;
  final String cohortKey;
  final DateTime createdAt;
  final String creatorName;
  final int memberCount;
  final bool isUserMember;
  final String userAttendanceStatus;
  final List<StudySessionModel> sessions;
  final String? legacyMeetingLocation;
  final DateTime? legacyStartTime;
  final DateTime? legacyEndTime;
  final bool isUserConfirmed;

  const StudyGroupModel({
    required this.id,
    required this.creatorId,
    this.name = '',
    this.iconEmoji = '📚',
    required this.subject,
    required this.topic,
    this.description,
    this.capacity = 5,
    this.status = 'active',
    this.cohortKey = 'fsegn_l1_bc',
    required this.createdAt,
    this.creatorName = 'Étudiant FSEGN',
    this.memberCount = 1,
    this.isUserMember = false,
    this.userAttendanceStatus = 'pending',
    this.sessions = const [],
    String? meetingLocation,
    DateTime? startTime,
    DateTime? endTime,
    this.isUserConfirmed = false,
  }) : legacyMeetingLocation = meetingLocation,
       legacyStartTime = startTime,
       legacyEndTime = endTime;

  String get meetingLocation =>
      nextSession?.meetingLocation ?? legacyMeetingLocation ?? '';
  DateTime get startTime =>
      nextSession?.startTime ?? legacyStartTime ?? createdAt;
  DateTime get endTime => nextSession?.endTime ?? legacyEndTime ?? createdAt;
  bool get isEnded =>
      nextSession?.isEnded ??
      (legacyEndTime != null && DateTime.now().isAfter(legacyEndTime!));
  bool get hasStarted =>
      nextSession != null && DateTime.now().isAfter(nextSession!.startTime);

  StudySessionModel? get nextSession {
    final upcoming =
        sessions.where((s) => s.status == 'scheduled' && !s.isEnded).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  bool get isFull => memberCount >= capacity;
  int get remainingSpots => (capacity - memberCount).clamp(0, capacity);

  factory StudyGroupModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final members = json['group_members'] as List<dynamic>?;
    final userMember =
        members?.any((m) => m is Map && m['user_id'] == currentUserId) ??
        (json['is_user_member'] as bool? ??
            json['creator_id'] == currentUserId);
    var creatorName = 'Étudiant FSEGN';
    if (json['profiles'] is Map<String, dynamic>) {
      creatorName =
          (json['profiles'] as Map<String, dynamic>)['display_name']
              as String? ??
          creatorName;
    }
    final rawSessions = json['study_sessions'] as List<dynamic>? ?? const [];
    return StudyGroupModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name:
          json['name'] as String? ??
          (json['topic'] as String? ?? 'Groupe de révision'),
      iconEmoji: json['icon_emoji'] as String? ?? '📚',
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      description: json['description'] as String?,
      capacity: (json['capacity'] as num?)?.toInt() ?? 5,
      status: json['status'] as String? ?? 'active',
      cohortKey: json['cohort_key'] as String? ?? 'fsegn_l1_bc',
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      creatorName: creatorName,
      memberCount:
          members?.length ?? (json['member_count'] as num?)?.toInt() ?? 1,
      isUserMember: userMember,
      userAttendanceStatus: 'pending',
      sessions: rawSessions
          .whereType<Map<String, dynamic>>()
          .map(
            (row) =>
                StudySessionModel.fromJson(row, currentUserId: currentUserId),
          )
          .toList(),
      meetingLocation: json['meeting_location'] as String?,
      startTime: json['start_time'] == null
          ? null
          : DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      isUserConfirmed: false,
    );
  }

  StudyGroupModel copyWith({
    int? memberCount,
    bool? isUserMember,
    int? capacity,
    String? name,
    String? iconEmoji,
    List<StudySessionModel>? sessions,
    bool? isUserConfirmed,
    String? userAttendanceStatus,
    String? status,
  }) => StudyGroupModel(
    id: id,
    creatorId: creatorId,
    name: name ?? this.name,
    iconEmoji: iconEmoji ?? this.iconEmoji,
    subject: subject,
    topic: topic,
    description: description,
    capacity: capacity ?? this.capacity,
    status: status ?? this.status,
    cohortKey: cohortKey,
    createdAt: createdAt,
    creatorName: creatorName,
    memberCount: memberCount ?? this.memberCount,
    isUserMember: isUserMember ?? this.isUserMember,
    userAttendanceStatus: userAttendanceStatus ?? this.userAttendanceStatus,
    sessions: sessions ?? this.sessions,
    meetingLocation: legacyMeetingLocation,
    startTime: legacyStartTime,
    endTime: legacyEndTime,
    isUserConfirmed: isUserConfirmed ?? this.isUserConfirmed,
  );
}
