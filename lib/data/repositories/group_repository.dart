import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../core/env/app_config.dart';
import '../models/study_group_model.dart';
import '../models/group_member_model.dart';
import '../models/study_session_model.dart';
import '../services/supabase_service.dart';
import '../services/local_demo_service.dart';
import '../services/media_storage_service.dart';
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
      if (userGroupsOnly && uid == null) {
        _cachedGroups = [];
        return _cachedGroups;
      }
      List<String>? memberGroupIds;
      if (userGroupsOnly) {
        final memberships = await SupabaseService.client
            .from('group_members')
            .select('group_id')
            .eq('user_id', uid!);
        memberGroupIds = (memberships as List<dynamic>)
            .map((row) => row['group_id'] as String)
            .toSet()
            .toList();
        if (memberGroupIds.isEmpty) {
          _cachedGroups = [];
          return _cachedGroups;
        }
      }

      var query = SupabaseService.client
          .from('study_groups')
          .select('''
        id, creator_id, name, cover_image_path, subject, topic, description,
        capacity, status, cohort_key, created_at,
        profiles!study_groups_creator_id_fkey(display_name),
        group_members(id, user_id),
        study_sessions(id, group_id, topic, description, meeting_location, start_time, end_time, status, study_session_members(user_id, attendance_confirmed, attendance_status))
      ''')
          .eq('cohort_key', 'fsegn_l1_bc')
          .neq('status', 'cancelled');

      if (memberGroupIds != null) {
        query = query.inFilter('id', memberGroupIds);
      }

      if (subject != null && subject.isNotEmpty) {
        query = query.eq('subject', subject);
      }

      final data = await query.order('created_at', ascending: false);

      final list = (data as List<dynamic>).map((item) {
        return StudyGroupModel.fromJson(
          item as Map<String, dynamic>,
          currentUserId: uid,
        );
      }).toList();

      // In-memory post-filters for complex conditions
      _cachedGroups = list.where((g) {
        if (topicQuery != null && topicQuery.trim().isNotEmpty) {
          final q = topicQuery.trim().toLowerCase();
          if (!g.name.toLowerCase().contains(q) &&
              !g.subject.toLowerCase().contains(q) &&
              !g.topic.toLowerCase().contains(q) &&
              !(g.description?.toLowerCase().contains(q) ?? false))
            return false;
        }
        if (availableOnly && g.isFull) return false;
        if (userGroupsOnly && !g.isUserMember) return false;
        if (date != null &&
            !g.sessions.any(
              (s) =>
                  s.startTime.year == date.year &&
                  s.startTime.month == date.month &&
                  s.startTime.day == date.day,
            ) &&
            !(g.sessions.isEmpty &&
                g.startTime.year == date.year &&
                g.startTime.month == date.month &&
                g.startTime.day == date.day))
          return false;
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
      id, creator_id, name, cover_image_path, subject, topic, description,
      capacity, status, cohort_key, created_at,
      profiles!study_groups_creator_id_fkey(display_name),
      group_members(id, user_id),
      study_sessions(id, group_id, topic, description, meeting_location, start_time, end_time, status, study_session_members(user_id, attendance_confirmed, attendance_status))
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
      profiles!group_members_user_id_fkey(display_name, reliability_score, avatar_path)
    ''')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return (data as List<dynamic>).map((item) {
      return GroupMemberModel.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  /// Returns study groups the specified student has joined, for their profile.
  Future<List<StudyGroupModel>> getGroupsForStudent(String studentId) async {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.getGroupsForStudent(studentId);
    }

    final memberships = await SupabaseService.client
        .from('group_members')
        .select('group_id')
        .eq('user_id', studentId);
    final groupIds = (memberships as List<dynamic>)
        .map((row) => row['group_id'] as String)
        .toSet()
        .toList();
    if (groupIds.isEmpty) return [];

    final data = await SupabaseService.client
        .from('study_groups')
        .select('''
          id, creator_id, name, cover_image_path, subject, topic, description,
          capacity, status, cohort_key, created_at,
          profiles!study_groups_creator_id_fkey(display_name),
          group_members(id, user_id),
          study_sessions(id, group_id, topic, description, meeting_location, start_time, end_time, status, study_session_members(user_id, attendance_confirmed, attendance_status))
        ''')
        .inFilter('id', groupIds)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => StudyGroupModel.fromJson(row as Map<String, dynamic>))
        .toList();
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
    required String name,
    String? coverImagePath,
    required String subject,
    required String topic,
    String? description,
    required int capacity,
  }) async {
    if (AppConfig.isDemoMode) {
      final g = await LocalDemoService.instance.createGroup(
        name: name,
        subject: subject,
        topic: topic,
        description: description,
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
          'name': name.trim(),
          'cover_image_path': coverImagePath,
          'subject': subject,
          'topic': topic.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'capacity': capacity,
          'status': 'active',
          'cohort_key': 'fsegn_l1_bc',
        })
        .select('''
      id, creator_id, name, cover_image_path, subject, topic, description,
      capacity, status, cohort_key, created_at,
      profiles!study_groups_creator_id_fkey(display_name)
    ''')
        .single();

    final model = StudyGroupModel.fromJson(inserted, currentUserId: uid);
    notifyListeners();
    return model;
  }

  Future<void> uploadGroupCover({
    required String groupId,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (AppConfig.isDemoMode) return;
    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) throw Exception('Non connecté');
    final key = await MediaStorageService.instance.uploadGroupCover(
      groupId: groupId,
      userId: uid,
      bytes: bytes,
      extension: extension,
    );
    await SupabaseService.client
        .from('study_groups')
        .update({'cover_image_path': key})
        .eq('id', groupId);
    notifyListeners();
  }

  Future<void> createSession({
    required String groupId,
    required String topic,
    required String location,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.createSession(
        groupId: groupId,
        topic: topic,
        location: location,
        start: start,
        end: end,
        description: description,
      );
    } else {
      await SupabaseService.client.rpc(
        'create_study_session',
        params: {
          'p_group_id': groupId,
          'p_topic': topic.trim(),
          'p_description': description,
          'p_meeting_location': location.trim(),
          'p_start_time': start.toIso8601String(),
          'p_end_time': end.toIso8601String(),
        },
      );
    }
    notifyListeners();
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String subject,
    required String topic,
    required String? description,
    required int capacity,
  }) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.updateGroup(
        groupId: groupId,
        name: name,
        subject: subject,
        topic: topic,
        description: description,
        capacity: capacity,
      );
    } else {
      await SupabaseService.client
          .from('study_groups')
          .update({
            'name': name.trim(),
            'subject': subject,
            'topic': topic.trim(),
            'description': description,
            'capacity': capacity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', groupId);
    }
    notifyListeners();
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
