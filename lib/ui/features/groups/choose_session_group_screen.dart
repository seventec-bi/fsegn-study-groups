import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/group_icon.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';
import 'create_group_screen.dart';
import 'create_session_screen.dart';

class ChooseSessionGroupScreen extends StatefulWidget {
  const ChooseSessionGroupScreen({super.key});

  @override
  State<ChooseSessionGroupScreen> createState() =>
      _ChooseSessionGroupScreenState();
}

class _ChooseSessionGroupScreenState extends State<ChooseSessionGroupScreen> {
  List<StudyGroupModel> _groups = [];
  bool _loading = true;
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
      final groups = await GroupRepository.instance.fetchGroups(
        userGroupsOnly: true,
      );
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroupAndSession() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CreateGroupScreen(scheduleFirstSession: true),
      ),
    );
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _choose(StudyGroupModel group) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSessionScreen(
          groupId: group.id,
          groupTopic: group.topic,
        ),
      ),
    );
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    appBar: AppBar(title: const Text('Créer une séance')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choisissez le groupe qui va se retrouver en présentiel.',
            style: TextStyle(color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.alertError),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_groups.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.tealLight.withAlpha(120),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Vous n’êtes membre d’aucun groupe pour le moment. Créez un groupe et programmez sa première rencontre en une seule étape.',
                style: TextStyle(height: 1.4),
              ),
            )
          else ...[
            const Text(
              'Mes groupes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            ..._groups.map(
              (group) => Card(
                child: ListTile(
                  leading: GroupIcon(emoji: group.iconEmoji, size: 48),
                  title: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${group.subject} · ${group.memberCount}/${group.capacity} membres',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _choose(group),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _createGroupAndSession,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Créer un groupe et sa première séance'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
              _load();
            },
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Créer seulement un groupe'),
          ),
        ],
      ),
    ),
  );
}
