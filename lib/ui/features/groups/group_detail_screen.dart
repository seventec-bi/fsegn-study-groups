import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/models/group_member_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';
import '../../core/student_avatar.dart';
import '../chat/group_chat_screen.dart';
import '../profile/student_profile_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  StudyGroupModel? _group;
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final g = await GroupRepository.instance.getGroupById(widget.groupId);
      final m = await GroupRepository.instance.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          _group = g;
          _members = m;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Directive #2: Transactional Join
  Future<void> _handleJoin() async {
    setState(() => _isActionLoading = true);
    try {
      await GroupRepository.instance.joinGroup(widget.groupId);
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Vous avez rejoint le groupe d’étude !',
        );
        await _loadGroupDetails();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text(
          'Voulez-vous vraiment libérer votre place dans ce groupe ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await GroupRepository.instance.leaveGroup(widget.groupId);
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Vous avez quitté le groupe.');
        await _loadGroupDetails();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCancelGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la séance'),
        content: const Text(
          'Cette action informera les membres et annulera la séance d’étude. Confirmer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Annuler le groupe'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await GroupRepository.instance.cancelGroup(widget.groupId);
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Le groupe a été annulé.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Pre-session attendance confirmation toggle (Directive #3: creator is unconfirmed by default)
  Future<void> _toggleConfirmation(bool target) async {
    setState(() => _isActionLoading = true);
    try {
      await AttendanceRepository.instance.setConfirmation(
        widget.groupId,
        target,
      );
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          target
              ? 'Présence confirmée ! Merci pour votre engagement.'
              : 'Confirmation de présence annulée.',
        );
        await _loadGroupDetails();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // Directive #4: Post-session honest attendance recording dialog
  Future<void> _showPostSessionAttendanceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrer votre assiduité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                AttendanceRepository.disclaimerText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textDark,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Avez-vous été présent à cette séance de révision ?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Je n’ai pas pu assister (-15 pts si confirmé)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('J’étais bien présent (+5 pts)'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await AttendanceRepository.instance.recordAttendance(
        widget.groupId,
        result,
      );
      if (mounted) {
        final delta = res['score_delta'] as int? ?? 0;
        final newScore = res['new_score'] as int? ?? 100;
        final sign = delta >= 0 ? '+$delta' : '$delta';
        UiHelpers.showSnackBar(
          context,
          'Assiduité enregistrée ! Impact score : $sign pt (Nouveau score : $newScore%)',
        );
        await _loadGroupDetails();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ResponsiveScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return ResponsiveScaffold(
        appBar: AppBar(title: const Text('Groupe d’étude')),
        body: UiHelpers.buildEmptyState(
          icon: Icons.error_outline,
          title: 'Groupe introuvable',
          description:
              _errorMessage ??
              'Ce groupe d’étude a été supprimé ou est inaccessible.',
          buttonText: 'Retour',
          onButtonPressed: () => Navigator.of(context).pop(),
        ),
      );
    }

    final g = _group!;
    final currentUserId = AuthRepository.instance.currentUserId;
    final isCreator = g.creatorId == currentUserId;
    final isMember = g.isUserMember;
    final isConfirmed = g.isUserConfirmed;
    final isEnded = g.isEnded;
    final hasStarted = g.hasStarted;

    // Check current member attendance record
    GroupMemberModel? myMemberRecord;
    try {
      myMemberRecord = _members.firstWhere((m) => m.userId == currentUserId);
    } catch (_) {}

    final bool attendanceAlreadyRecorded =
        myMemberRecord?.attendanceRecordedAt != null ||
        (myMemberRecord?.attendanceStatus != 'pending');

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(g.subject),
        actions: [
          if (isMember)
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'Chat du groupe',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(
                      groupId: g.id,
                      groupTitle: '${g.subject} • ${g.topic}',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroupDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subject & Free-text Topic Card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.subject,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.tealAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  g.topic,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryNavy,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCreator)
                            UiHelpers.buildBadge(
                              text: 'Créateur',
                              color: AppTheme.primaryNavy,
                              textColor: AppTheme.primaryNavy,
                              icon: Icons.star,
                            )
                          else if (isMember)
                            UiHelpers.buildBadge(
                              text: isConfirmed ? 'Confirmé' : 'Inscrit',
                              color: isConfirmed
                                  ? AppTheme.alertSuccess
                                  : AppTheme.tealAccent,
                              icon: isConfirmed
                                  ? Icons.check_circle
                                  : Icons.person,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Time & Location Info
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${UiHelpers.formatDate(g.startTime)} • ${UiHelpers.formatTimeRange(g.startTime, g.endTime)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.meetingLocation,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (g.description != null &&
                          g.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.borderSubtle),
                        const SizedBox(height: 8),
                        Text(
                          g.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textDark,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Capacity Progress Bar
                      UiHelpers.buildCapacityBar(
                        memberCount: _members.length,
                        capacity: g.capacity,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Section
              if (_isActionLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // 1. Join Group Button (if not member)
                if (!isMember) ...[
                  if (isEnded)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Cette session d’étude est terminée.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else if (g.isFull)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.alertError.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Groupe complet (capacité maximale atteinte)',
                          style: TextStyle(
                            color: AppTheme.alertError,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _handleJoin,
                      icon: const Icon(Icons.group_add, size: 20),
                      label: const Text('Rejoindre ce groupe d’étude'),
                    ),
                ],

                // 2. Member Actions
                if (isMember) ...[
                  // Pre-session attendance confirmation (up to start time)
                  if (!hasStarted) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      color: isConfirmed
                          ? AppTheme.tealLight
                          : const Color(0xFFFFF9E6),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isConfirmed
                                      ? Icons.check_circle_outline
                                      : Icons.notification_important_outlined,
                                  color: isConfirmed
                                      ? AppTheme.alertSuccess
                                      : const Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isConfirmed
                                      ? 'Votre présence est confirmée'
                                      : 'Présence non confirmée',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isConfirmed
                                        ? AppTheme.alertSuccess
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isConfirmed
                                  ? 'Vous vous êtes engagé à participer. Vous pouvez annuler jusqu’au début de la séance.'
                                  : 'Confirmez votre présence pour informer le groupe. Assister à une séance confirmée augmente votre score de fiabilité (+5 pts).',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textDark,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!isConfirmed)
                              ElevatedButton.icon(
                                onPressed: () => _toggleConfirmation(true),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Confirmer ma présence'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => _toggleConfirmation(false),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Annuler ma confirmation'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Post-session attendance self-recording
                  if (isEnded) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      color: attendanceAlreadyRecorded
                          ? Colors.grey.shade100
                          : AppTheme.tealLight,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attendanceAlreadyRecorded
                                  ? 'Assiduité enregistrée'
                                  : 'Séance terminée : Enregistrez votre présence',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              attendanceAlreadyRecorded
                                  ? 'Statut : ${myMemberRecord?.attendanceStatus == 'attended' ? 'Présent (+5 pts)' : 'Absent'}.'
                                  : 'La séance est maintenant terminée. Veuillez déclarer en toute honnêteté si vous avez assisté.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            if (!attendanceAlreadyRecorded) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _showPostSessionAttendanceDialog,
                                icon: const Icon(
                                  Icons.fact_check_outlined,
                                  size: 18,
                                ),
                                label: const Text('Déclarer ma présence'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Chat Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepSlate,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(
                            groupId: g.id,
                            groupTitle: '${g.subject} • ${g.topic}',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Ouvrir le Chat du Groupe'),
                  ),
                  const SizedBox(height: 12),

                  // Leave or Cancel Actions
                  if (isCreator)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.alertError,
                        side: const BorderSide(color: AppTheme.alertError),
                      ),
                      onPressed: _handleCancelGroup,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Annuler cette séance d’étude'),
                    )
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.alertError,
                        side: const BorderSide(color: AppTheme.alertError),
                      ),
                      onPressed: _handleLeave,
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: const Text('Quitter ce groupe'),
                    ),
                ],
              ],
              const SizedBox(height: 24),

              // Members List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Membres inscrits (${_members.length}/${g.capacity})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ..._members.map((member) {
                final isMe = member.userId == currentUserId;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    leading: StudentAvatar(
                      displayName: member.displayName,
                      avatarKey: member.avatarPath,
                      radius: 22,
                      backgroundColor: member.isCreator
                          ? AppTheme.tealLight
                          : null,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentProfileScreen(studentId: member.userId),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName + (isMe ? ' (Vous)' : ''),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        if (member.isCreator)
                          UiHelpers.buildBadge(
                            text: 'Créateur',
                            color: AppTheme.primaryNavy,
                            icon: Icons.star,
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            member.attendanceConfirmed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 13,
                            color: member.attendanceConfirmed
                                ? AppTheme.alertSuccess
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.attendanceConfirmed
                                ? 'Présence confirmée'
                                : 'Non confirmé',
                            style: TextStyle(
                              fontSize: 12,
                              color: member.attendanceConfirmed
                                  ? AppTheme.alertSuccess
                                  : AppTheme.textMuted,
                              fontWeight: member.attendanceConfirmed
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Fiabilité : ${member.reliabilityScore}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
