import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/env/app_config.dart';

/// Service managing the Supabase client connection.
class SupabaseService {
  static bool _initialized = false;
  static String? _initializationFailure;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!AppConfig.hasValidSupabaseKeys) {
      _initializationFailure =
          'Supabase URL or public key is missing or invalid.';
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
