import 'dart:typed_data';\nimport 'package:flutter/foundation.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/env/app_config.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../services/local_demo_service.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._();
  AuthRepository._();

  ProfileModel? _currentProfile;
  ProfileModel? get currentProfile => _currentProfile;

  bool get isAuthenticated {
    if (AppConfig.isDemoMode) return true;
    return SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;
  }

  String? get currentUserId {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.currentProfile.id;
    }
    return SupabaseService.client.auth.currentUser?.id;
  }

  /// NOTE (Directive #1): Email is retrieved strictly from auth session,
  /// never from public profile table.
  String? get currentUserEmail {
    if (AppConfig.isDemoMode) {
      return 'etudiant.demo@fsegn.ucar.tn';
    }
    return SupabaseService.client.auth.currentUser?.email;
  }

  Future<void> initialize() async {
    if (AppConfig.isDemoMode) {
      _currentProfile = LocalDemoService.instance.currentProfile;
      notifyListeners();
      return;
    }

    if (isAuthenticated) {
      await loadProfile();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    String? bio,
  }) async {
    if (AppConfig.isDemoMode) {
      // Simulate signup in demo mode
      await LocalDemoService.instance.updateProfile(
        displayName: displayName,
        bio: bio,
      );
      _currentProfile = LocalDemoService.instance.currentProfile;
      notifyListeners();
      return;
    }

    final response = await SupabaseService.client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConfig.authRedirectUrl,
      data: {
        'display_name': displayName.trim(),
        'bio': bio?.trim(),
        'cohort': 'fsegn_l1_bc',
      },
    );

    if (response.user == null) {
      throw Exception('Échec de la création du compte. Vérifiez votre saisie.');
    }

    await loadProfile();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (AppConfig.isDemoMode) {
      _currentProfile = LocalDemoService.instance.currentProfile;
      notifyListeners();
      return;
    }

    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user == null) {
      throw Exception('Identifiants incorrects.');
    }

    await loadProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    if (AppConfig.isDemoMode) {
      // In demo mode, reset to base demo profile
      _currentProfile = LocalDemoService.instance.currentProfile;
      notifyListeners();
      return;
    }

    await SupabaseService.client.auth.signOut();
    _currentProfile = null;
    notifyListeners();
  }

  Future<ProfileModel?> loadProfile() async {
    if (AppConfig.isDemoMode) {
      _currentProfile = LocalDemoService.instance.getProfile();
      notifyListeners();
      return _currentProfile;
    }

    final uid = currentUserId;
    if (uid == null) return null;

    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data != null) {
      _currentProfile = ProfileModel.fromJson(data);
      notifyListeners();
    }
    return _currentProfile;
  }

  Future<void> updateProfile({required String displayName, String? bio}) async {
    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.updateProfile(
        displayName: displayName,
        bio: bio,
      );
      _currentProfile = LocalDemoService.instance.getProfile();
      notifyListeners();
      return;
    }

    final uid = currentUserId;
    if (uid == null) throw Exception('Non connecté');

    final res = await SupabaseService.client.rpc(
      'update_my_profile',
      params: {
        'p_display_name': displayName.trim(),
        'p_bio': bio?.trim().isEmpty == true ? null : bio?.trim(),\n        'p_avatar_path': _currentProfile?.avatarPath,
      },
    );

    if (res is Map && res['success'] != true) {
      throw Exception(
        res['message'] ?? 'Erreur lors de la mise à jour du profil.',
      );
    }

    await loadProfile();
  }
}
