import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String? _selectedSubject;
  final _topicController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  int _capacity = 5;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _topicController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(now) ? now : _startDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Adjust end time to be at least 1 hour later
        final startM = picked.hour * 60 + picked.minute;
        final endM = _endTime.hour * 60 + _endTime.minute;
        if (endM <= startM) {
          final newEndHour = (picked.hour + 1) % 24;
          _endTime = TimeOfDay(hour: newEndHour, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubject == null) {
      setState(() {
        _errorMessage =
            'Veuillez sélectionner une matière de l’emploi du temps.';
      });
      return;
    }

    final fullStart = _combineDateTime(_startDate, _startTime);
    final fullEnd = _combineDateTime(_startDate, _endTime);

    if (fullStart.isBefore(DateTime.now())) {
      setState(() {
        _errorMessage = 'La date de début doit être dans le futur.';
      });
      return;
    }

    if (!fullEnd.isAfter(fullStart)) {
      setState(() {
        _errorMessage =
            'L’heure de fin doit être postérieure à l’heure de début.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await GroupRepository.instance.createGroup(
        subject: _selectedSubject!,
        topic: _topicController.text.trim(),
        meetingLocation: _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: fullStart,
        endTime: fullEnd,
        capacity: _capacity,
      );

      if (mounted) {
        UiHelpers.showSnackBar(context, 'Groupe d’étude créé avec succès !');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullStart = _combineDateTime(_startDate, _startTime);
    final fullEnd = _combineDateTime(_startDate, _endTime);

    return ResponsiveScaffold(
      appBar: AppBar(title: const Text('Créer un groupe d’étude')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.alertError.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.alertError.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.alertError,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.alertError,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Subject Dropdown
              const Text(
                'Matière *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Sélectionner la matière (12 cours L1)',
                  prefixIcon: Icon(Icons.menu_book, size: 20),
                ),
                items: Subjects.list.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSubject = val;
                  });
                },
                validator: (val) => val == null
                    ? 'Veuillez choisir une matière de l’emploi du temps.'
                    : null,
              ),
              const SizedBox(height: 16),

              // 2. Free-text Chapter / Topic
              const Text(
                'Chapitre / Sujet libre de révision *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Indiquez précisément le chapitre, les exercices ou le projet à travailler.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _topicController,
                maxLength: 120,
                decoration: const InputDecoration(
                  hintText: 'ex. Chapitre 4 : Arbres binaires & Récursivité',
                  prefixIcon: Icon(Icons.edit_note, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez indiquer le chapitre ou sujet de révision.';
                  }
                  if (val.trim().length < 3) {
                    return 'Le sujet doit comporter au moins 3 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 3. Meeting Location
              const Text(
                'Lieu de rencontre en présentiel *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _locationController,
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: 'ex. Bibliothèque FSEGN - Salle de travail 2',
                  prefixIcon: Icon(Icons.place_outlined, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez préciser le lieu sur le campus.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 4. Date and Time
              const Text(
                'Date et Horaires *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        DateFormat('EEE d MMM', 'fr_FR').format(_startDate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_startTime.format(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.timelapse, size: 18),
                      label: Text(_endTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Créneau prévu : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(fullStart)} de ${UiHelpers.formatTimeRange(fullStart, fullEnd)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.tealAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // 5. Capacity Stepper (2 to 20)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capacité maximale',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      Text(
                        '$_capacity étudiants (vous inclus)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _capacity > 2
                            ? () {
                                setState(() {
                                  _capacity--;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_capacity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _capacity < 20
                            ? () {
                                setState(() {
                                  _capacity++;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6. Optional Description
              const Text(
                'Description / Consignes (Optionnel)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 400,
                decoration: const InputDecoration(
                  hintText:
                      'ex. Ramenez vos notes de cours et un ordi portable si possible.',
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSubmit,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Publier le groupe d’étude'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
