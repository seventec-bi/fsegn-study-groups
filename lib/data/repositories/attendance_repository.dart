import 'package:flutter/foundation.dart';
import '../../core/env/app_config.dart';
import '../models/attendance_record_model.dart';
import '../services/supabase_service.dart';
import '../services/local_demo_service.dart';
import 'auth_repository.dart';

class AttendanceRepository extends ChangeNotifier {
  static final AttendanceRepository instance = AttendanceRepository._();
  AttendanceRepository._();

  static const String disclaimerText =
      'Système d’honneur étudiant (Beta FSEGN) : L’assiduité est autodéclarée par chaque étudiant après la fin de la séance et n’est pas vérifiée de manière indépendante.';

  /// Toggles pre-session attendance confirmation.
  Future<void> setConfirmation(String groupId, bool confirmed) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.setAttendanceConfirmation(
        groupId,
        confirmed,
      );
      notifyListeners();
      return;
    }

    final res = await SupabaseService.client.rpc(
      'set_attendance_confirmation',
      params: {'p_group_id': groupId, 'p_confirmed': confirmed},
    );

    if (res is Map && res['success'] != true) {
      throw Exception(
        res['message'] ?? 'Impossible de modifier la confirmation.',
      );
    }
    notifyListeners();
  }

  Future<void> setSessionConfirmation(String sessionId, bool confirmed) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.setSessionConfirmation(
        sessionId,
        confirmed,
      );
      notifyListeners();
      return;
    }
    final res = await SupabaseService.client.rpc(
      'set_study_session_confirmation',
      params: {'p_session_id': sessionId, 'p_confirmed': confirmed},
    );
    if (res is Map && res['success'] != true)
      throw Exception(
        res['message'] ?? 'Impossible de modifier la confirmation.',
      );
    notifyListeners();
  }

  Future<Map<String, dynamic>> recordSessionAttendance(
    String sessionId,
    bool attended,
  ) async {
    if (AppConfig.isDemoMode) {
      final result = await LocalDemoService.instance.recordSessionAttendance(
        sessionId,
        attended,
      );
      await AuthRepository.instance.loadProfile();
      notifyListeners();
      return result;
    }
    final res = await SupabaseService.client.rpc(
      'record_study_session_attendance',
      params: {'p_session_id': sessionId, 'p_attended': attended},
    );
    if (res is Map && res['success'] != true)
      throw Exception(
        res['message'] ?? 'Impossible d’enregistrer la présence.',
      );
    await AuthRepository.instance.loadProfile();
    notifyListeners();
    return Map<String, dynamic>.from(res as Map);
  }

  /// DIRECTIVE #4: Idempotent post-session attendance recording.
  /// Prevents double scoring and clamps score between 0 and 100.
  Future<Map<String, dynamic>> recordAttendance(
    String groupId,
    bool attended,
  ) async {
    if (AppConfig.isDemoMode) {
      final res = await LocalDemoService.instance.recordMyAttendance(
        groupId,
        attended,
      );
      await AuthRepository.instance.loadProfile();
      notifyListeners();
      return res;
    }

    final res = await SupabaseService.client.rpc(
      'record_my_attendance',
      params: {'p_group_id': groupId, 'p_attended': attended},
    );

    if (res is Map && res['success'] != true) {
      throw Exception(
        res['message'] ?? 'Impossible d’enregistrer l’assiduité.',
      );
    }

    // Refresh profile to update reliability score
    await AuthRepository.instance.loadProfile();
    notifyListeners();

    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<AttendanceRecordModel>> fetchAttendanceHistory() async {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.getAttendanceHistory();
    }

    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) return [];

    final data = await SupabaseService.client
        .from('study_session_members')
        .select('''
          attendance_confirmed, attendance_status, attendance_recorded_at, session_id,
          study_sessions!study_session_members_session_id_fkey(id, group_id, topic, start_time,
            study_groups!study_sessions_group_id_fkey(subject))
        ''')
        .eq('user_id', uid)
        .neq('attendance_status', 'pending')
        .order('attendance_recorded_at', ascending: false);

    return (data as List<dynamic>).map((item) {
      final s = item['study_sessions'] as Map<String, dynamic>;
      final g = s['study_groups'] as Map<String, dynamic>;
      final confirmed = item['attendance_confirmed'] as bool? ?? false;
      final status = item['attendance_status'] as String? ?? 'unconfirmed';

      int delta = 0;
      if (confirmed) {
        if (status == 'attended') {
          delta = 5;
        } else if (status == 'absent') {
          delta = -15;
        }
      }

      return AttendanceRecordModel(
        groupId: s['group_id'] as String,
        subject: g['subject'] as String,
        topic: s['topic'] as String,
        sessionDate: DateTime.parse(s['start_time'] as String),
        wasConfirmed: confirmed,
        attendanceStatus: status,
        scoreImpact: delta,
        recordedAt: item['attendance_recorded_at'] != null
            ? DateTime.parse(item['attendance_recorded_at'] as String)
            : null,
      );
    }).toList();
  }
}
