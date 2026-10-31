class StudySessionModel {
  final String id;
  final String groupId;
  final String topic;
  final String? description;
  final String meetingLocation;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final bool isConfirmed;
  final String attendanceStatus;

  const StudySessionModel({
    required this.id,
    required this.groupId,
    required this.topic,
    this.description,
    required this.meetingLocation,
    required this.startTime,
    required this.endTime,
    this.status = 'scheduled',
    this.isConfirmed = false,
    this.attendanceStatus = 'pending',
  });

  bool get isEnded => DateTime.now().isAfter(endTime) || status == 'completed';

  StudySessionModel copyWith({bool? isConfirmed, String? attendanceStatus}) =>
      StudySessionModel(
        id: id,
        groupId: groupId,
        topic: topic,
        description: description,
        meetingLocation: meetingLocation,
        startTime: startTime,
        endTime: endTime,
        status: status,
        isConfirmed: isConfirmed ?? this.isConfirmed,
        attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      );

  factory StudySessionModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final participants =
        json['study_session_members'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? mine;
    for (final item in participants) {
      if (item is Map<String, dynamic> && item['user_id'] == currentUserId) {
        mine = item;
        break;
      }
    }
    return StudySessionModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      topic: json['topic'] as String,
      description: json['description'] as String?,
      meetingLocation: json['meeting_location'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: json['status'] as String? ?? 'scheduled',
      isConfirmed: mine?['attendance_confirmed'] as bool? ?? false,
      attendanceStatus: mine?['attendance_status'] as String? ?? 'pending',
    );
  }
}
