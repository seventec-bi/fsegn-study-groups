import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/group_message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupTitle;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<GroupMessageModel>>? _subscription;
  List<GroupMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _subscription = ChatRepository.instance.streamMessages(widget.groupId).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _errorMessage = err.toString();
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _manualRefresh() async {
    try {
      final list = await ChatRepository.instance.fetchMessages(widget.groupId);
      if (!mounted) return;
      setState(() => _messages = list);
      _scrollToBottom();
      UiHelpers.showSnackBar(context, 'Messages actualisés.');
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Erreur d’actualisation : $e',
          isError: true,
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _messageController.clear();
    try {
      await ChatRepository.instance.sendMessage(widget.groupId, text);
    } catch (e) {
      if (mounted) {
        _messageController.text = text;
        UiHelpers.showSnackBar(
          context,
          'Impossible d’envoyer le message : $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _continuesFromPrevious(int index) {
    if (index == 0) return false;
    final previous = _messages[index - 1];
    final current = _messages[index];
    return previous.senderId == current.senderId &&
        _sameDay(previous.createdAt, current.createdAt) &&
        current.createdAt.difference(previous.createdAt).inMinutes < 5;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthRepository.instance.currentUserId;
    return ResponsiveScaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.tealLight,
              child: const Icon(
                Icons.groups_2_rounded,
                size: 19,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Discussion du groupe',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(
                'Connexion limitée : $_errorMessage',
                style: const TextStyle(fontSize: 12),
              ),
              leading: const Icon(Icons.wifi_off_rounded),
              actions: [
                TextButton(
                  onPressed: _manualRefresh,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? UiHelpers.buildEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'La discussion commence ici',
                        description:
                            'Présentez-vous et partagez vos questions avec le groupe.',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == currentUserId;
                          final continues = _continuesFromPrevious(index);
                          final showDate = index == 0 ||
                              !_sameDay(
                                msg.createdAt,
                                _messages[index - 1].createdAt,
                              );
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryNavy.withAlpha(18),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        DateFormat('d MMMM yyyy', 'fr')
                                            .format(msg.createdAt.toLocal()),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryNavy,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              _MessageBubble(
                                message: msg,
                                isMe: isMe,
                                continues: continues,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: const Color(0xFFF2F4F7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppTheme.tealAccent,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      onPressed: _isSending ? null : _handleSend,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: AppTheme.primaryNavy,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 19),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final GroupMessageModel message;
  final bool isMe;
  final bool continues;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.continues,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _senderAvatar(message);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe || continues ? 18 : 5),
      bottomRight: Radius.circular(!isMe || continues ? 18 : 5),
    );

    return Padding(
      padding: EdgeInsets.only(top: continues ? 2 : 7, bottom: 1),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 30,
              child: continues
                  ? null
                  : CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.tealLight,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(
                              message.senderName.isEmpty
                                  ? '?'
                                  : message.senderName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryNavy,
                              ),
                            )
                          : null,
                    ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFDCEAF7) : Colors.white,
                  borderRadius: radius,
                  border: isMe
                      ? null
                      : Border.all(color: AppTheme.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(7),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 11, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe && !continues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            message.senderName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.tealAccent,
                            ),
                          ),
                        ),
                      Text(
                        message.message,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.28,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          UiHelpers.formatTime(message.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ImageProvider? _senderAvatar(GroupMessageModel message) {
  final path = message.senderAvatarPath;
  if (path == null || path.isEmpty || !SupabaseService.isInitialized) {
    return null;
  }
  return NetworkImage(
    SupabaseService.client.storage.from('avatars').getPublicUrl(path),
  );
}
