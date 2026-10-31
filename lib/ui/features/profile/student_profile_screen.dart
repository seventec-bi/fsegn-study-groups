import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/student_avatar.dart';
import '../groups/group_detail_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  ProfileModel? _profile;
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
      final profile = await AuthRepository.instance.getPublicProfile(
        widget.studentId,
      );
      final groups = profile == null
          ? <StudyGroupModel>[]
          : await GroupRepository.instance.getGroupsForStudent(
              widget.studentId,
            );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _groups = groups;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      appBar: AppBar(title: const Text('Profil étudiant')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _messageState(
              icon: Icons.cloud_off_rounded,
              title: 'Impossible de charger le profil',
              detail: _error!,
            )
          : _profile == null
          ? _messageState(
              icon: Icons.person_off_outlined,
              title: 'Profil introuvable',
              detail: 'Ce profil n’est pas disponible actuellement.',
            )
          : _profileContent(_profile!),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileContent(ProfileModel profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryNavy, Color(0xFF176B78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(190),
                    width: 2,
                  ),
                ),
                child: StudentAvatar(
                  displayName: profile.displayName,
                  avatarKey: profile.avatarPath,
                  radius: 48,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                ),
              ),
              if (profile.bio?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFB6F1D0),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Score de fiabilité',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${profile.reliabilityScore}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${profile.licenceYear} • ${profile.specialty}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Groupes de cette personne',
                style: TextStyle(
                  color: AppTheme.primaryNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_groups.length}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_groups.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    color: AppTheme.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun groupe à afficher pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ..._groups.map(_groupCard),
      ],
    );
  }

  Widget _groupCard(StudyGroupModel group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.tealLight,
          child: Icon(Icons.menu_book_rounded, color: AppTheme.primaryNavy),
        ),
        title: Text(group.topic, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${group.name} • ${group.subject}'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        ),
      ),
    );
  }
}
