import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/env/app_config.dart';
import '../models/group_message_model.dart';
import '../services/supabase_service.dart';
import '../services/local_demo_service.dart';
import 'auth_repository.dart';

class ChatRepository extends ChangeNotifier {
  static final ChatRepository instance = ChatRepository._();
  ChatRepository._();

  /// Streams real-time messages for a specific group.
  /// Automatically falls back to local demo streams when offline.
  Stream<List<GroupMessageModel>> streamMessages(String groupId) {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.streamMessages(groupId);
    }

    try {
      return SupabaseService.client
          .from('group_messages')
          .stream(primaryKey: ['id'])
          .eq('group_id', groupId)
          .order('created_at', ascending: true)
          .asyncMap((list) async {
            // Join sender names from profiles for clean chat rendering
            final messages = <GroupMessageModel>[];
            for (final item in list) {
              final senderId = item['sender_id'] as String;
              String senderName = 'Étudiant FSEGN';

              // Fetch sender name if possible
              try {
                final p = await SupabaseService.client
                    .from('profiles')
                    .select('display_name, avatar_path')
                    .eq('id', senderId)
                    .maybeSingle();
                if (p != null) {
                  senderName = p['display_name'] as String? ?? 'Étudiant FSEGN';
                }
              } catch (_) {}

              final enriched = Map<String, dynamic>.from(item);
              enriched['sender_name'] = senderName;\n              try {\n                final p = await SupabaseService.client.from('profiles').select('avatar_path').eq('id', senderId).maybeSingle();\n                enriched['sender_avatar_path'] = p?['avatar_path'];\n              } catch (_) {}
              messages.add(GroupMessageModel.fromJson(enriched));
            }
            return messages;
          });
    } catch (_) {
      // Fallback polling stream if realtime publication is not configured
      return Stream.periodic(
        const Duration(seconds: 4),
      ).asyncMap((_) => fetchMessages(groupId));
    }
  }

  /// Manual refresh fallback: fetches the latest messages over REST.
  Future<List<GroupMessageModel>> fetchMessages(String groupId) async {
    if (AppConfig.isDemoMode) {
      return LocalDemoService.instance.getMessages(groupId);
    }

    final data = await SupabaseService.client
        .from('group_messages')
        .select('''
          id, group_id, sender_id, message, created_at,
          profiles!group_messages_sender_id_fkey(display_name, avatar_path)
        ''')
        .eq('group_id', groupId)
        .order('created_at', ascending: true);

    return (data as List<dynamic>).map((item) {
      return GroupMessageModel.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  Future<void> sendMessage(String groupId, String text) async {
    if (text.trim().isEmpty) return;

    if (AppConfig.isDemoMode) {
      await LocalDemoService.instance.sendMessage(groupId, text);
      notifyListeners();
      return;
    }

    final uid = AuthRepository.instance.currentUserId;
    if (uid == null) throw Exception('Non connecté');

    await SupabaseService.client.from('group_messages').insert({
      'group_id': groupId,
      'sender_id': uid,
      'message': text.trim(),
    });

    notifyListeners();
  }
}
