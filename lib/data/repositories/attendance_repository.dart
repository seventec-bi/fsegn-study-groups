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
        .from('group_members')
        .select('''
          attendance_confirmed, attendance_status, attendance_recorded_at,
          study_groups!group_members_group_id_fkey(id, subject, topic, start_time)
        ''')
        .eq('user_id', uid)
        .neq('attendance_status', 'pending')
        .order('joined_at', ascending: false);

    return (data as List<dynamic>).map((item) {
      final g = item['study_groups'] as Map<String, dynamic>;
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
        groupId: g['id'] as String,
        subject: g['subject'] as String,
        topic: g['topic'] as String,
        sessionDate: DateTime.parse(g['start_time'] as String),
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
