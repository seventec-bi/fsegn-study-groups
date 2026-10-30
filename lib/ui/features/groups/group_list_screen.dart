import 'package:flutter/material.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/study_group_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../core/responsive_scaffold.dart';
import '../../core/ui_helpers.dart';
import 'group_filter_sheet.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';

class GroupListScreen extends StatefulWidget {
  final bool initialUserGroupsOnly;

  const GroupListScreen({super.key, this.initialUserGroupsOnly = false});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final _searchController = TextEditingController();
  FilterCriteria _criteria = const FilterCriteria();

  List<StudyGroupModel> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserGroupsOnly) {
      _criteria = _criteria.copyWith(userGroupsOnly: true);
    }
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await GroupRepository.instance.fetchGroups(
        subject: _criteria.subject,
        topicQuery: _searchController.text.trim().isEmpty
            ? _criteria.topicQuery
            : _searchController.text.trim(),
        date: _criteria.date,
        availableOnly: _criteria.availableOnly,
        userGroupsOnly:
            widget.initialUserGroupsOnly || _criteria.userGroupsOnly,
      );
      if (mounted) {
        setState(() {
          _groups = list;
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

  void _openFilterSheet() async {
    final updated = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupFilterSheet(
        currentCriteria: _criteria,
        lockUserGroupsOnly: widget.initialUserGroupsOnly,
      ),
    );

    if (updated != null) {
      setState(() {
        _criteria = updated;
      });
      _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
          if (created == true) {
            _loadGroups();
          }
        },
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau groupe'),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un chapitre ou sujet...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadGroups();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _loadGroups(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _criteria.hasActiveFilters,
                      child: IconButton.filledTonal(
                        onPressed: _openFilterSheet,
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: 'Filtrer les groupes',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Horizontal Subject Pills
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Toutes'),
                          selected: _criteria.subject == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _criteria = _criteria.copyWith(
                                  clearSubject: true,
                                );
                              });
                              _loadGroups();
                            }
                          },
                        ),
                      ),
                      ...Subjects.list.map((subj) {
                        final isSelected = _criteria.subject == subj;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(subj),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _criteria = _criteria.copyWith(
                                  subject: selected ? subj : null,
                                  clearSubject: !selected,
                                );
                              });
                              _loadGroups();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Active filter badges row
          if (_criteria.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.tealLight.withAlpha(100),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    size: 14,
                    color: AppTheme.tealAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Filtres actifs : ${_criteria.availableOnly ? "Dispos • " : ""}${_criteria.userGroupsOnly ? "Mes groupes • " : ""}${_criteria.date != null ? "Date sélectionnée" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _criteria = FilterCriteria(
                          userGroupsOnly: widget.initialUserGroupsOnly,
                        );
                        _searchController.clear();
                      });
                      _loadGroups();
                    },
                    child: const Text(
                      'Effacer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.alertError,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.alertError.withAlpha(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppTheme.alertError,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.alertError,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Groups List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadGroups,
                    child: _groups.isEmpty
                        ? UiHelpers.buildEmptyState(
                            icon: Icons.search_off_rounded,
                            title: widget.initialUserGroupsOnly
                                ? 'Vous n’avez rejoint aucun groupe'
                                : 'Aucun groupe d’étude trouvé',
                            description: widget.initialUserGroupsOnly
                                ? 'Les groupes que vous créez ou rejoignez apparaîtront ici.'
                                : _criteria.hasActiveFilters
                                ? 'Aucun groupe ne correspond à vos filtres. Essayez de réinitialiser la recherche.'
                                : 'Soyez le premier à créer un groupe d’étude pour votre promo FSEGN L1 !',
                            buttonText: 'Créer un groupe',
                            onButtonPressed: () async {
                              final created = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => const CreateGroupScreen(),
                                    ),
                                  );
                              if (created == true) _loadGroups();
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            itemCount: _groups.length,
                            itemBuilder: (context, index) {
                              final g = _groups[index];
                              return _GroupCard(
                                group: g,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GroupDetailScreen(groupId: g.id),
                                    ),
                                  );
                                  _loadGroups();
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final StudyGroupModel group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject tag & user status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      group.subject,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.tealAccent,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (group.isUserMember)
                    UiHelpers.buildBadge(
                      text: group.isUserConfirmed ? 'Confirmé' : 'Inscrit',
                      color: group.isUserConfirmed
                          ? AppTheme.alertSuccess
                          : AppTheme.tealAccent,
                      icon: group.isUserConfirmed
                          ? Icons.check_circle
                          : Icons.person,
                    )
                  else if (group.isFull)
                    UiHelpers.buildBadge(
                      text: 'Complet',
                      color: AppTheme.alertError,
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Free-text Topic (prominent)
              Text(
                group.topic,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryNavy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),

              // Date, Time & Location
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${UiHelpers.formatDate(group.startTime)} • ${UiHelpers.formatTimeRange(group.startTime, group.endTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.meetingLocation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Capacity Progress Indicator
              UiHelpers.buildCapacityBar(
                memberCount: group.memberCount,
                capacity: group.capacity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
