import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../core/constants/subjects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _topic = TextEditingController();
  final _description = TextEditingController();
  String? _subject;
  XFile? _cover;
  Uint8List? _coverBytes;
  int _capacity = 8;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subject == null) {
      setState(() => _error = 'Choisissez une matière pour votre groupe.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = await GroupRepository.instance.createGroup(
        name: _name.text.trim(),
        subject: _subject!,
        topic: _topic.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        capacity: _capacity,
      );
      String? coverError;
      if (_cover != null) {
        try {
          await GroupRepository.instance.uploadGroupCover(
            groupId: group.id,
            bytes: _coverBytes!,
            extension: _cover!.name.split('.').last,
          );
        } catch (_) {
          coverError =
              'Le groupe est créé, mais la photo n’a pas pu être envoyée.';
        }
      }
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          coverError ?? 'Votre groupe est prêt !',
          isError: coverError != null,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    appBar: AppBar(title: const Text('Créer un groupe')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Un espace pour vos cours et vos camarades.',
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppTheme.alertError)),
            const SizedBox(height: 12),
          ],
          const Text(
            'Nom du groupe',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(
              hintText: 'ex. Les as de l’algorithmique',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            validator: (v) => v == null || v.trim().length < 2
                ? 'Ajoutez un nom de 2 caractères minimum.'
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Photo du groupe (facultatif)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final image = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1000,
                maxHeight: 1000,
              );
              if (image != null && mounted) {
                final bytes = await image.readAsBytes();
                if (mounted)
                  setState(() {
                    _cover = image;
                    _coverBytes = bytes;
                  });
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: _cover == null
                  ? const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(width: 8),
                          Text('Ajouter une image'),
                        ],
                      ),
                    )
                  : Image.memory(
                      _coverBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Matière', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _subject,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Choisir un cours',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            items: Subjects.list
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _subject = v),
            validator: (v) => v == null ? 'Choisissez une matière.' : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Qu’est-ce que vous étudiez ?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _topic,
            maxLength: 150,
            decoration: const InputDecoration(
              hintText: 'ex. Pointeurs, listes chaînées et exercices',
            ),
            validator: (v) => v == null || v.trim().length < 2
                ? 'Décrivez le sujet du groupe.'
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Quelques mots pour accueillir les membres (facultatif)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _description,
            maxLength: 400,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Notes, exercices, entraide…',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Limite de membres',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Vous pourrez l’ajuster plus tard.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _capacity > 2
                    ? () => setState(() => _capacity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_capacity',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              IconButton(
                onPressed: _capacity < 20
                    ? () => setState(() => _capacity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Votre groupe reste ouvert pour discuter des cours. Vous pourrez proposer une rencontre en présentiel quand vous voulez, puis en organiser une autre dans le même groupe.',
              style: TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _create,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.favorite_border),
            label: const Text('Créer mon groupe'),
          ),
        ],
      ),
    ),
  );
}
