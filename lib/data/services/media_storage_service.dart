import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Storage boundary for profile photos and future chat attachments.
///
/// Keep object keys in Postgres and resolve view URLs through this service.
/// Replacing this implementation with a Cloudflare Worker backed adapter later
/// will not require profile or chat UI changes.
abstract interface class MediaStorageService {
  static final MediaStorageService instance = SupabaseMediaStorageService();

  Future<void> upload({
    required String key,
    required Uint8List bytes,
    required String contentType,
  });

  Future<String> viewUrl(String key);

  Future<void> delete(String key);

}

class SupabaseMediaStorageService implements MediaStorageService {
  static const _bucket = 'student-avatars';
  static final Map<String, String> _urlCache = {};
  static final Map<String, DateTime> _urlExpiry = {};

  @override
  Future<void> upload({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await SupabaseService.client.storage
        .from(_bucket)
        .uploadBinary(
          key,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
  }

  @override
  Future<String> viewUrl(String key) async {
    final expiry = _urlExpiry[key];
    final cached = _urlCache[key];
    if (cached != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return cached;
    }
    final url = await SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(key, 3600);
    _urlCache[key] = url;
    _urlExpiry[key] = DateTime.now().add(const Duration(minutes: 58));
    return url;
  }

  @override
  Future<void> delete(String key) async {
    await SupabaseService.client.storage.from(_bucket).remove([key]);
  }

}
