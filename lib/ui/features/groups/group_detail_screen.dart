import 'package:flutter/material.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/models/study_session_model.dart';
import '../../../data/models/group_member_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';
import '../../core/student_avatar.dart';
import '../../core/group_icon.dart';
import '../chat/group_chat_screen.dart';
import '../profile/student_profile_screen.dart';
import 'create_session_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  StudyGroupModel? _group;
  List<GroupMemberModel> _members = [];
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = await GroupRepository.instance.getGroupById(widget.groupId);
      final members = await GroupRepository.instance.getGroupMembers(
        widget.groupId,
      );
      if (mounted)
        setState(() {
          _group = group;
          _members = members;
        });
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) {
        UiHelpers.showSnackBar(context, message);
        await _load();
      }
    } catch (e) {
      if (mounted)
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _edit(StudyGroupModel group) async {
    final name = TextEditingController(text: group.name);
    final topic = TextEditingController(text: group.topic);
    final desc = TextEditingController(text: group.description ?? '');
    var capacity = group.capacity;
    var subject = group.subject;
    var iconEmoji = group.iconEmoji;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Modifier le groupe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GroupIconPicker(
                  selected: iconEmoji,
                  onSelected: (emoji) => setDialog(() => iconEmoji = emoji),
                ),
                TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nom du groupe'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: subject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: Subjects.list
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => subject = v);
                  },
                ),
                TextField(
                  controller: topic,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Ce que vous étudiez',
                  ),
                ),
                TextField(
                  controller: desc,
                  maxLength: 400,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Limite de membres')),
                    IconButton(
                      onPressed: capacity > _members.length
                          ? () => setDialog(() => capacity--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$capacity'),
                    IconButton(
                      onPressed: capacity < 20
                          ? () => setDialog(() => capacity++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _run(
        () => GroupRepository.instance.updateGroup(
          groupId: group.id,
          name: name.text,
          iconEmoji: iconEmoji,
          subject: subject,
          topic: topic.text,
          description: desc.text.trim().isEmpty ? null : desc.text.trim(),
          capacity: capacity,
        ),
        'Groupe mis à jour.',
      );
    }
    name.dispose();
    topic.dispose();
    desc.dispose();
  }

  Future<void> _declareAttendance(StudySessionModel session) async {
    final attended = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déclarer votre présence'),
        content: const Text(
          'Avez-vous participé à cette rencontre ? Votre déclaration mettra à jour votre score de fiabilité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Plus tard'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, j’y étais'),
          ),
        ],
      ),
    );
    if (attended == null) return;
    await _run(() async {
      await AttendanceRepository.instance.recordSessionAttendance(
        session.id,
        attended,
      );
    }, 'Présence enregistrée.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const ResponsiveScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    final g = _group;
    if (g == null)
      return ResponsiveScaffold(
        appBar: AppBar(title: const Text('Groupe')),
        body: UiHelpers.buildEmptyState(
          icon: Icons.error_outline,
          title: 'Groupe introuvable',
          description: _error ?? 'Ce groupe est inaccessible.',
          buttonText: 'Retour',
          onButtonPressed: () => Navigator.pop(context),
        ),
      );
    final uid = AuthRepository.instance.currentUserId;
    final creator = uid == g.creatorId;
    final member = g.isUserMember;
    final sessions = [...g.sessions]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sessions.isEmpty &&
        g.legacyStartTime != null &&
        g.legacyEndTime != null) {
      sessions.add(
        StudySessionModel(
          id: 'legacy',
          groupId: g.id,
          topic: g.topic,
          meetingLocation: g.meetingLocation,
          startTime: g.startTime,
          endTime: g.endTime,
          description: g.description,
          status: g.status == 'cancelled' ? 'cancelled' : 'scheduled',
        ),
      );
    }
    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(g.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (creator)
            IconButton(
              onPressed: () => _edit(g),
              tooltip: 'Modifier le groupe',
              icon: const Icon(Icons.edit_outlined),
            ),
          if (member)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupChatScreen(groupId: g.id, groupTitle: g.name),
                ),
              ),
              tooltip: 'Chat du groupe',
              icon: const Icon(Icons.chat_bubble_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GroupIcon(
                        emoji: g.iconEmoji,
                        size: 68,
                        radius: 18,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              g.subject,
                              style: const TextStyle(
                                color: AppTheme.tealAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    g.topic,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (g.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      g.description!,
                      style: const TextStyle(
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 18,
                        color: AppTheme.tealAccent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${_members.length} membres · limite ${g.capacity}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (creator) const Spacer(),
                      if (creator)
                        TextButton(
                          onPressed: () => _edit(g),
                          child: const Text('Modifier'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!member) ...[
              ElevatedButton.icon(
                onPressed: _acting || g.isFull
                    ? null
                    : () => _run(
                        () => GroupRepository.instance.joinGroup(g.id),
                        'Vous avez rejoint le groupe !',
                      ),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(
                  g.isFull ? 'Groupe complet' : 'Rejoindre ce groupe',
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (member) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepSlate,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupChatScreen(groupId: g.id, groupTitle: g.name),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ouvrir la conversation'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSessionScreen(
                        groupId: g.id,
                        groupTopic: g.topic,
                      ),
                    ),
                  );
                  if (added == true) _load();
                },
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Proposer une rencontre en présentiel'),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rencontres du groupe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                if (sessions.isNotEmpty)
                  Text(
                    '${sessions.length}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight.withAlpha(120),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Pas encore de rencontre planifiée. Vous pouvez discuter ici et proposer une quand le groupe le souhaite.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ...sessions.map(
              (s) => _SessionCard(
                session: s,
                isMember: member,
                busy: _acting,
                onConfirm: (v) => _run(
                  () => AttendanceRepository.instance.setSessionConfirmation(
                    s.id,
                    v,
                  ),
                  v ? 'Présence confirmée !' : 'Confirmation annulée.',
                ),
                onReport: () => _declareAttendance(s),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Membres (${_members.length}/${g.capacity})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 6),
            ..._members.map(
              (m) => Card(
                child: ListTile(
                  leading: StudentAvatar(
                    displayName: m.displayName,
                    avatarKey: m.avatarPath,
                    radius: 21,
                  ),
                  title: Text(
                    m.displayName + (m.userId == uid ? ' (vous)' : ''),
                  ),
                  subtitle: Text('Fiabilité : ${m.reliabilityScore}%'),
                  trailing: m.isCreator
                      ? const Icon(
                          Icons.star_outline,
                          color: AppTheme.tealAccent,
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProfileScreen(studentId: m.userId),
                    ),
                  ),
                ),
              ),
            ),
            if (member && !creator)
              TextButton.icon(
                onPressed: _acting
                    ? null
                    : () => _run(
                        () => GroupRepository.instance.leaveGroup(g.id),
                        'Vous avez quitté le groupe.',
                      ),
                icon: const Icon(Icons.logout, color: AppTheme.alertError),
                label: const Text(
                  'Quitter le groupe',
                  style: TextStyle(color: AppTheme.alertError),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final StudySessionModel session;
  final bool isMember;
  final bool busy;
  final ValueChanged<bool> onConfirm;
  final VoidCallback onReport;
  const _SessionCard({
    required this.session,
    required this.isMember,
    required this.busy,
    required this.onConfirm,
    required this.onReport,
  });
  @override
  Widget build(BuildContext context) {
    final ended = session.isEnded || session.status == 'completed';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  color: AppTheme.tealAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                if (ended) const Chip(label: Text('Terminée')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${UiHelpers.formatDate(session.startTime)} · ${UiHelpers.formatTimeRange(session.startTime, session.endTime)}',
            ),
            const SizedBox(height: 4),
            Text(
              session.meetingLocation,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            if (session.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(session.description!),
            ],
            if (isMember &&
                session.id != 'legacy' &&
                !ended &&
                session.status == 'scheduled')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => onConfirm(!session.isConfirmed),
                  icon: Icon(
                    session.isConfirmed
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  label: Text(
                    session.isConfirmed ? 'Je ne viens plus' : 'Je serai là',
                  ),
                ),
              ),
            if (isMember &&
                session.id != 'legacy' &&
                ended &&
                session.attendanceStatus == 'pending')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: busy ? null : onReport,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Déclarer ma présence'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
