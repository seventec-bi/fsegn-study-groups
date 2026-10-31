import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/models/study_session_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/group_icon.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';
import 'choose_session_group_screen.dart';
import 'group_detail_screen.dart';
import 'group_list_screen.dart';

class StudySessionDiscoveryScreen extends StatefulWidget {
  const StudySessionDiscoveryScreen({super.key});

  @override
  State<StudySessionDiscoveryScreen> createState() =>
      _StudySessionDiscoveryScreenState();
}

class _StudySessionDiscoveryScreenState
    extends State<StudySessionDiscoveryScreen> {
  List<_SessionEntry> _sessions = [];
  bool _loading = true;
  String? _error;
  String? _busySessionId;

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
      final groups = await GroupRepository.instance.fetchGroups();
      final now = DateTime.now();
      final sessions = [
        for (final group in groups)
          for (final session in group.sessions)
            if (session.status == 'scheduled' && session.startTime.isAfter(now))
              _SessionEntry(group: group, session: session),
      ]..sort((a, b) => a.session.startTime.compareTo(b.session.startTime));
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _participate(_SessionEntry entry) async {
    if (entry.group.isFull && !entry.group.isUserMember) return;
    setState(() => _busySessionId = entry.session.id);
    try {
      if (!entry.group.isUserMember) {
        await GroupRepository.instance.joinGroup(entry.group.id);
      }
      await AttendanceRepository.instance.setSessionConfirmation(
        entry.session.id,
        !entry.session.isConfirmed,
      );
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          entry.session.isConfirmed
              ? 'Votre participation a été annulée.'
              : 'Vous êtes inscrit à cette rencontre !',
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busySessionId = null);
    }
  }

  Future<void> _createSession() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChooseSessionGroupScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _createSession,
      backgroundColor: AppTheme.primaryNavy,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.handshake_outlined),
      label: const Text('Créer une séance'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Étudiez ensemble, en vrai.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Trouvez une rencontre à venir ou proposez la vôtre.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Séances à venir',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GroupListScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Groupes'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.alertError),
                ),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_sessions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 52,
                      color: AppTheme.tealAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune séance prévue pour le moment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Soyez la personne qui lance la prochaine rencontre sur le campus.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _createSession,
                      icon: const Icon(Icons.add),
                      label: const Text('Proposer une séance'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              sliver: SliverList.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) => _SessionDiscoveryCard(
                  entry: _sessions[index],
                  busy: _busySessionId == _sessions[index].session.id,
                  onParticipate: () => _participate(_sessions[index]),
                  onOpenGroup: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(
                        groupId: _sessions[index].group.id,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SessionEntry {
  final StudyGroupModel group;
  final StudySessionModel session;
  const _SessionEntry({required this.group, required this.session});
}

class _SessionDiscoveryCard extends StatelessWidget {
  final _SessionEntry entry;
  final bool busy;
  final VoidCallback onParticipate;
  final VoidCallback onOpenGroup;

  const _SessionDiscoveryCard({
    required this.entry,
    required this.busy,
    required this.onParticipate,
    required this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final group = entry.group;
    final session = entry.session;
    final full = group.isFull && !group.isUserMember;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onOpenGroup,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GroupIcon(emoji: group.iconEmoji, size: 44, radius: 13),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.tealAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${group.remainingSpots} places',
                    style: TextStyle(
                      color: full ? AppTheme.alertError : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                session.topic,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InfoLabel(
                    icon: Icons.calendar_month_outlined,
                    text: UiHelpers.formatDate(session.startTime),
                  ),
                  _InfoLabel(
                    icon: Icons.access_time,
                    text: UiHelpers.formatTimeRange(
                      session.startTime,
                      session.endTime,
                    ),
                  ),
                  _InfoLabel(
                    icon: Icons.place_outlined,
                    text: session.meetingLocation,
                  ),
                ],
              ),
              if (session.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  session.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: group.isUserMember && session.isConfirmed
                    ? OutlinedButton.icon(
                        onPressed: busy ? null : onParticipate,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Vous participez · Annuler'),
                      )
                    : FilledButton.icon(
                        onPressed: full || busy ? null : onParticipate,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                group.isUserMember
                                    ? Icons.check_circle_outline
                                    : Icons.group_add_outlined,
                              ),
                        label: Text(
                          full
                              ? 'Groupe complet'
                              : group.isUserMember
                              ? 'Je participe'
                              : 'Rejoindre et participer',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppTheme.tealAccent),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
        ),
      ),
    ],
  );
}
