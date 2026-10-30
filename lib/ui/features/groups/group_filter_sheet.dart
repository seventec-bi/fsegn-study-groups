import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/theme/app_theme.dart';

class FilterCriteria {
  final String? subject;
  final String? topicQuery;
  final DateTime? date;
  final bool availableOnly;
  final bool userGroupsOnly;

  const FilterCriteria({
    this.subject,
    this.topicQuery,
    this.date,
    this.availableOnly = false,
    this.userGroupsOnly = false,
  });

  bool get hasActiveFilters =>
      (subject != null && subject!.isNotEmpty) ||
      (topicQuery != null && topicQuery!.trim().isNotEmpty) ||
      date != null ||
      availableOnly ||
      userGroupsOnly;

  FilterCriteria copyWith({
    String? subject,
    String? topicQuery,
    DateTime? date,
    bool? availableOnly,
    bool? userGroupsOnly,
    bool clearSubject = false,
    bool clearDate = false,
  }) {
    return FilterCriteria(
      subject: clearSubject ? null : (subject ?? this.subject),
      topicQuery: topicQuery ?? this.topicQuery,
      date: clearDate ? null : (date ?? this.date),
      availableOnly: availableOnly ?? this.availableOnly,
      userGroupsOnly: userGroupsOnly ?? this.userGroupsOnly,
    );
  }
}

class GroupFilterSheet extends StatefulWidget {
  final FilterCriteria currentCriteria;
  final bool lockUserGroupsOnly;

  const GroupFilterSheet({
    super.key,
    required this.currentCriteria,
    this.lockUserGroupsOnly = false,
  });

  @override
  State<GroupFilterSheet> createState() => _GroupFilterSheetState();
}

class _GroupFilterSheetState extends State<GroupFilterSheet> {
  String? _selectedSubject;
  DateTime? _selectedDate;
  bool _availableOnly = false;
  bool _userGroupsOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.currentCriteria.subject;
    _selectedDate = widget.currentCriteria.date;
    _availableOnly = widget.currentCriteria.availableOnly;
    _userGroupsOnly = widget.currentCriteria.userGroupsOnly;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtres de recherche',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedSubject = null;
                      _selectedDate = null;
                      _availableOnly = false;
                      _userGroupsOnly = widget.lockUserGroupsOnly;
                    });
                  },
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subject Filter
            const Text(
              'Matière (Emploi du temps L1)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              hint: const Text('Toutes les matières'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Toutes les matières'),
                ),
                ...Subjects.list.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedSubject = val;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date Filter
            const Text(
              'Date de la séance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Toutes les dates'
                            : DateFormat(
                                'EEE d MMMM y',
                                'fr_FR',
                              ).format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDate == null
                              ? AppTheme.textMuted
                              : AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Toggle Available Only
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Places disponibles uniquement',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Masquer les groupes complets',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              value: _availableOnly,
              activeTrackColor: AppTheme.tealAccent,
              onChanged: (val) {
                setState(() {
                  _availableOnly = val;
                });
              },
            ),

            // Toggle User Groups Only
            if (!widget.lockUserGroupsOnly)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mes groupes uniquement',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Groupes créés ou rejoints',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                value: _userGroupsOnly,
                activeTrackColor: AppTheme.tealAccent,
                onChanged: (val) {
                  setState(() {
                    _userGroupsOnly = val;
                  });
                },
              ),
            const SizedBox(height: 20),

            // Apply Button
            ElevatedButton(
              onPressed: () {
                final newCriteria = FilterCriteria(
                  subject: _selectedSubject,
                  topicQuery: widget.currentCriteria.topicQuery,
                  date: _selectedDate,
                  availableOnly: _availableOnly,
                  userGroupsOnly: widget.lockUserGroupsOnly || _userGroupsOnly,
                );
                Navigator.of(context).pop(newCriteria);
              },
              child: const Text('Appliquer les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}
