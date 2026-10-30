import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/env/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/cohort_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/student_avatar.dart';
import '../../core/ui_helpers.dart';
import 'attendance_history_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _openEditProfileDialog() async {
    final profile = AuthRepository.instance.currentProfile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.displayName);
    final bioController = TextEditingController(text: profile.bio ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mon profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom et Prénom',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioController,
              maxLines: 3,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'Courte bio (optionnel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (updated == true) {
      setState(() => _isLoading = true);
      try {
        await AuthRepository.instance.updateProfile(
          displayName: nameController.text.trim(),
          bio: bioController.text.trim(),
        );
        if (mounted) {
          UiHelpers.showSnackBar(context, 'Profil mis à jour avec succès.');
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
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (image == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final extension = image.name.split('.').last.toLowerCase();
      await AuthRepository.instance.uploadAvatar(
        await image.readAsBytes(),
        extension: extension,
      );
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Photo de profil mise à jour.');
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
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
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthRepository.instance.signOut();
    }
  }

  void _openAttendanceHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttendanceHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthRepository.instance,
      builder: (context, _) {
        final profile = AuthRepository.instance.currentProfile;
        final email =
            AuthRepository.instance.currentUserEmail ?? 'Non renseigné';
        final score = profile?.reliabilityScore ?? 100;

        return ResponsiveScaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                Card(
                  color: AppTheme.primaryNavy,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            StudentAvatar(
                              displayName: profile?.displayName ?? 'Étudiant',
                              avatarKey: AppConfig.isDemoMode
                                  ? null
                                  : profile?.avatarPath,
                              radius: 42,
                              backgroundColor: AppTheme.tealLight,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: AppTheme.tealAccent,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Changer la photo',
                                  onPressed: _isLoading ? null : _changeAvatar,
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile?.displayName ?? 'Étudiant FSEGN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (profile?.bio != null &&
                            profile!.bio!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            profile.bio!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Safe Email Badge (Directive #1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(24),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 13,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$email (Privé)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          onPressed: _isLoading ? null : _openEditProfileDialog,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.edit_outlined, size: 16),
                          label: Text(
                            _isLoading
                                ? 'Mise à jour...'
                                : 'Modifier mon profil',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cohort Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.school_outlined,
                              size: 20,
                              color: AppTheme.primaryNavy,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cohorte Beta FSEGN',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCohortRow(
                          'Université',
                          CohortConstants.universityName,
                        ),
                        _buildCohortRow(
                          'Établissement',
                          CohortConstants.facultyFullName,
                        ),
                        _buildCohortRow('Niveau', CohortConstants.licenceYear),
                        _buildCohortRow(
                          'Spécialité',
                          CohortConstants.specialty,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Reliability Score Card (Directive #4)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 20,
                                  color: AppTheme.tealAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Score de fiabilité',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.tealLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$score%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (score / 100.0).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: AppTheme.borderSubtle,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              score >= 80
                                  ? AppTheme.alertSuccess
                                  : (score >= 60
                                        ? AppTheme.alertWarning
                                        : AppTheme.alertError),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Règles du système d’assiduité honnête (Beta) :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Présence à une session confirmée : +5 pts\n'
                          '• Absence après confirmation : -15 pts\n'
                          '• Score initial : 100% (plafonné entre 0% et 100%)\n'
                          '• Système d’honneur : déclaration autonome post-séance.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openAttendanceHistory,
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text(
                            'Consulter mon historique d’assiduité',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Supabase Free Plan Notice Card (Directive #5)
                Card(
                  color: const Color(0xFFF9FAFB),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.cloud_done_outlined,
                              size: 18,
                              color: AppTheme.primaryNavy,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Infrastructure Supabase Free Tier',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          AppConfig.freeTierNotice,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Out Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.alertError,
                  ),
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCohortRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
