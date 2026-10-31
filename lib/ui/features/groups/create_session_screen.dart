import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';

class CreateSessionScreen extends StatefulWidget {
  final String groupId;
  final String groupTopic;
  const CreateSessionScreen({
    super.key,
    required this.groupId,
    required this.groupTopic,
  });
  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  late final TextEditingController _topic = TextEditingController(
    text: widget.groupTopic,
  );
  final _place = TextEditingController();
  final _details = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 12, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _topic.dispose();
    _place.dispose();
    _details.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _save() async {
    if (_topic.text.trim().length < 2 || _place.text.trim().length < 2) {
      UiHelpers.showSnackBar(
        context,
        'Ajoutez le sujet et le lieu de la rencontre.',
        isError: true,
      );
      return;
    }
    if (!_at(_start).isAfter(DateTime.now()) ||
        !_at(_end).isAfter(_at(_start))) {
      UiHelpers.showSnackBar(
        context,
        'Choisissez un horaire futur valide.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await GroupRepository.instance.createSession(
        groupId: widget.groupId,
        topic: _topic.text,
        location: _place.text,
        start: _at(_start),
        end: _at(_end),
        description: _details.text,
      );
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Rencontre ajoutée au groupe !');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        UiHelpers.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    appBar: AppBar(title: const Text('Proposer une rencontre')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Le groupe et son chat restent ouverts après la rencontre.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _topic,
          maxLength: 150,
          decoration: const InputDecoration(
            labelText: 'Sujet de la rencontre',
            prefixIcon: Icon(Icons.menu_book_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _place,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Lieu sur le campus',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 180)),
            );
            if (d != null) setState(() => _date = d);
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(DateFormat('EEEE d MMMM y', 'fr_FR').format(_date)),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _start,
                  );
                  if (t != null) setState(() => _start = t);
                },
                icon: const Icon(Icons.access_time),
                label: Text(_start.format(context)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _end,
                  );
                  if (t != null) setState(() => _end = t);
                },
                icon: const Icon(Icons.timelapse),
                label: Text(_end.format(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _details,
          maxLines: 3,
          maxLength: 400,
          decoration: const InputDecoration(
            labelText: 'Détails (facultatif)',
            hintText: 'Exercices à préparer, matériel…',
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.event_available_outlined),
          label: const Text('Ajouter la rencontre'),
        ),
      ],
    ),
  );
}
