import 'package:flutter/foundation.dart';
import '../../core/env/app_config.dart';
import '../models/study_group_model.dart';
import '../models/group_member_model.dart';
import '../services/supabase_service.dart';
import '../services/local_demo_service.dart';
import 'auth_repository.dart';

class GroupRepository extends ChangeNotifier {
  static final GroupRepository instance = GroupRepository._();
  GroupRepository._();

  List<StudyGroupModel> _cachedGroups = [];
  List<StudyGroupModel> get cachedGroups => _cachedGroups;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<List<StudyGroupModel>> fetchGroups({
    String? subject,
    String? topicQuery,
    DateTime? date,
    bool availableOnly = false,
    bool userGroupsOnly = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (AppConfig.isDemoMode) {
        _cachedGroups = LocalDemoService.instance.getGroups(
          subject: subject,
          topicQuery: topicQuery,
          date: date,
          availableOnly: availableOnly,
          userGroupsOnly: userGroupsOnly,
        );
        return _cachedGroups;
      }

      final uid = AuthRepository.instance.currentUserId;
      var query = SupabaseService.client
          .from('study_groups')
          .select('''
        id, creator_id, subject, topic, description, meeting_location,
        start_time, end_time, capacity, status, cohort_key, created_at,
        profiles!study_groups_creator_id_fkey(display_name),
        group_members(id, user_id, attendance_confirmed, attendance_status)
      ''')
          .eq('cohort_key', 'fsegn_l1_bc')
          .neq('status', 'cancelled');

      if (subject != null && subject.isNotEmpty) {
        query = query.eq('subject', subject);
      }

      if (topicQuery != null && topicQuery.trim().isNotEmpty) {
        query = query.ilike('topic', '%${topicQuery.trim()}%');
      }

      final data = await query.order('start_time', ascending: true);

      final list = (data as List<dynamic>).map((item) {
        return StudyGroupModel.fromJson(
          item as Map<String, dynamic>,
          currentUserId: uid,
        );
      }).toList();

      // In-memory post-filters for complex conditions
      _cachedGroups = list.where((g) {
        if (availableOnly && g.isFull) return false;
        if (userGroupsOnly && !g.isUserMember) return false;
        if (date != null) {
          final gDate = DateTime(
            g.startTime.year,
            g.startTime.month,
            g.startTime.day,
          );
          final fDate = DateTime(date.year, date.month, date.day);
          if (gDate != fDate) return false;
        }
        return true;
      }).toList();

      return _cachedGroups;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<StudyGroupModel?> getGroupById(String groupId) async {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.getGroupById(groupId);
    }

    final uid = AuthRepository.instance.currentUserId;
    final data = await SupabaseService.client
        .from('study_groups')
        .select('''
      id, creator_id, subject, topic, description, meeting_location,
      start_time, end_time, capacity, status, cohort_key, created_at,
      profiles!study_groups_creator_id_fkey(display_name),
      group_members(id, user_id, attendance_confirmed, attendance_status)
    ''')
        .eq('id', groupId)
        .maybeSingle();

    if (data == null) return null;
    return StudyGroupModel.fromJson(data, currentUserId: uid);
  }

  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.getGroupMembers(groupId);
    }

    final data = await SupabaseService.client
        .from('group_members')
        .select('''
      id, group_id, user_id, role, attendance_confirmed,
      attendance_status, attendance_recorded_at, joined_at,
      profiles!group_members_user_id_fkey(display_name, reliability_score)
    ''')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return (data as List<dynamic>).map((item) {
      return GroupMemberModel.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  /// DIRECTIVE #2: Join group via transactional Postgres function
  /// to eliminate race conditions.
  Future<void> joinGroup(String groupId) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.joinGroup(groupId);
      notifyListeners();
      return;
    }

    // Call secure Postgres RPC function with FOR UPDATE locking
    final res = await SupabaseService.client.rpc(
      'join_study_group',
      params: {'p_group_id': groupId},
    );

    if (res is Map && res['success'] != true) {
      throw Exception(res['message'] ?? 'Impossible de rejoindre le groupe.');
    }
    notifyListeners();
  }

  Future<void> leaveGroup(String groupId) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.leaveGroup(groupId);
      notifyListeners();
      return;
    }

    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) throw Exception('Non connecté');

    await SupabaseService.client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', uid);

    notifyListeners();
  }

  /// DIRECTIVE #3: Create group. Database trigger handles member insertion
  /// with attendance_confirmed = false by default.
  Future<StudyGroupModel> createGroup({
    required String subject,
    required String topic,
    String? description,
    required String meetingLocation,
    required DateTime startTime,
    required DateTime endTime,
    required int capacity,
  }) async {
    if (startTime.isBefore(DateTime.now())) {
      throw Exception('La date de début doit être dans le futur.');
    }
    if (endTime.isBefore(startTime)) {
      throw Exception(
        'L’heure de fin doit être postérieure à l’heure de début.',
      );
    }

    if (AppConfig.isDemoMode) {
      final g = await LocalDemoService.instance.createGroup(
        subject: subject,
        topic: topic,
        description: description,
        meetingLocation: meetingLocation,
        startTime: startTime,
        endTime: endTime,
        capacity: capacity,
      );
      notifyListeners();
      return g;
    }

    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) throw Exception('Non connecté');

    final inserted = await SupabaseService.client
        .from('study_groups')
        .insert({
          'creator_id': uid,
          'subject': subject,
          'topic': topic.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'meeting_location': meetingLocation.trim(),
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'capacity': capacity,
          'status': 'active',
          'cohort_key': 'fsegn_l1_bc',
        })
        .select('''
      id, creator_id, subject, topic, description, meeting_location,
      start_time, end_time, capacity, status, cohort_key, created_at,
      profiles!study_groups_creator_id_fkey(display_name)
    ''')
        .single();

    final model = StudyGroupModel.fromJson(inserted, currentUserId: uid);
    notifyListeners();
    return model;
  }

  Future<void> cancelGroup(String groupId) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.cancelGroup(groupId);
      notifyListeners();
      return;
    }

    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) throw Exception('Non connecté');

    await SupabaseService.client
        .from('study_groups')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', groupId)
        .eq('creator_id', uid);

    notifyListeners();
  }
}
