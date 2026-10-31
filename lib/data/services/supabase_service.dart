import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/env/app_config.dart';

/// Service managing the Supabase client connection.
class SupabaseService {
  static bool _initialized = false;
  static String? _initializationFailure;
  static final Map<String, String> _avatarUrlCache = {};
  static final Map<String, DateTime> _avatarUrlExpiry = {};

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!AppConfig.hasValidSupabaseKeys) {
      _initializationFailure = 'Supabase URL or public key is missing or invalid.';
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      _initialized = true;
      _initializationFailure = null;
    } catch (error) {
      // Supabase may have created its client before failing during optional
      // session restoration. Keep using it if the SDK confirms it is ready.
      try {
        _initialized = Supabase.instance.isInitialized;
      } catch (_) {
        _initialized = false;
      }

      final type = error.runtimeType.toString();
      _initializationFailure = switch (type) {
        'FormatException' =>
          'Supabase rejected the URL or public key format (FormatException).',
        'MissingPluginException' =>
          'An Android plugin failed to start (MissingPluginException).',
        'PlatformException' =>
          'Android local storage failed to start (PlatformException).',
        _ => 'Supabase startup failed ($type).',
      };
      debugPrint('Supabase initialization failed ($type).');
    }
  }

  /// Returns a short-lived URL for a photo in the existing private bucket.
  static Future<String> signedAvatarUrl(String path) async {
    final expiry = _avatarUrlExpiry[path];
    final cached = _avatarUrlCache[path];
    if (cached != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return cached;
    }
    final url = await client.storage
        .from('student-avatars')
        .createSignedUrl(path, 3600);
    _avatarUrlCache[path] = url;
    _avatarUrlExpiry[path] = DateTime.now().add(const Duration(minutes: 58));
    return url;
  }

  static bool get isInitialized => _initialized;
  static String? get initializationFailure => _initializationFailure;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        _initializationFailure ??
            'Supabase client is not ready. Check its startup configuration.',
      );
    }
    return Supabase.instance.client;
  }
}
