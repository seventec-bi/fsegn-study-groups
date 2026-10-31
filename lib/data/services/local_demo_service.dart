import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/profile_model.dart';
import '../models/study_group_model.dart';
import '../models/study_session_model.dart';
import '../models/group_member_model.dart';
import '../models/group_message_model.dart';
import '../models/attendance_record_model.dart';

/// In-memory local demo service.
///
/// Provides a fully interactive offline testbed for reviewers and students
/// before Supabase credentials are plugged into `.env`.
///
/// NOTE: Complies with all 7 directives:
/// - No email exposure in profiles.
/// - Secure capacity checks before joining.
/// - Unconfirmed creator attendance by default.
/// - Idempotent score adjustments capped between 0 and 100.
class LocalDemoService {
  static final LocalDemoService instance = LocalDemoService._();
  LocalDemoService._() {
    _initializeSeedData();
  }

  final _uuid = const Uuid();

  ProfileModel _currentProfile = ProfileModel(
    id: 'demo-user-1',
    displayName: 'Amine Ben Salem (Demo)',
    bio:
        'Étudiant L1 Business Computing passionné par l’algorithmique et le Web.',
    university: 'Université de Carthage',
    faculty: 'FSEGN (Nabeul)',
    licenceYear: '1ère année Licence (L1)',
    specialty: 'Business Computing',
    reliabilityScore: 100,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  );

  final List<StudyGroupModel> _groups = [];
  final List<GroupMemberModel> _members = [];
  final List<GroupMessageModel> _messages = [];
  final List<AttendanceRecordModel> _attendanceHistory = [];

  final _messagesStreamController =
      StreamController<List<GroupMessageModel>>.broadcast();

  ProfileModel get currentProfile => _currentProfile;

  void _initializeSeedData() {
    final now = DateTime.now();

    // 1. Group in 1 day: Algorithmique
    final g1 = StudyGroupModel(
      id: 'group-1',
      creatorId: 'peer-user-sarra',
      creatorName: 'Sarra Trabelsi',
      subject: 'Algorithmique et structures',
      topic: 'Pointeurs, listes chaînées & récursivité',
      description:
          'Préparation de la série TD 3 avec révision des fonctions récursives.',
      meetingLocation: 'Bibliothèque FSEGN - Salle de travail 2',
      startTime: now.add(const Duration(days: 1, hours: 2)),
      endTime: now.add(const Duration(days: 1, hours: 4)),
      capacity: 5,
      status: 'active',
      createdAt: now.subtract(const Duration(days: 2)),
      memberCount: 3,
      isUserMember: true,
      isUserConfirmed: false, // Directive #3
    );

    // 2. Group in 2 days: Systèmes logiques
    final g2 = StudyGroupModel(
      id: 'group-2',
      creatorId: 'peer-user-yassine',
      creatorName: 'Yassine Gharbi',
      subject: 'Systèmes logiques, architecture et ordinateurs',
      topic: 'Tableaux de Karnaugh & Simplification logique',
      description: 'Exercices pratiques sur circuits combinatoires.',
      meetingLocation: 'Salle Machine 4 (Bloc Info)',
      startTime: now.add(const Duration(days: 2, hours: 4)),
      endTime: now.add(const Duration(days: 2, hours: 6, minutes: 30)),
      capacity: 6,
      status: 'active',
      createdAt: now.subtract(const Duration(days: 1)),
      memberCount: 2,
      isUserMember: false,
      isUserConfirmed: false,
    );

    // 3. Group in 3 days: Statistique (Full)
    final g3 = StudyGroupModel(
      id: 'group-3',
      creatorId: 'peer-user-mariem',
      creatorName: 'Mariem Khemir',
      subject: 'Statistique et probabilité',
      topic: 'Lois discrètes (Binomiale, Poisson) & Espérance',
      description: 'Résolution des anciens examens du premier semestre.',
      meetingLocation: 'Espaces verts FSEGN (près du Kiosque)',
      startTime: now.add(const Duration(days: 3, hours: 1)),
      endTime: now.add(const Duration(days: 3, hours: 3)),
      capacity: 4,
      status: 'active',
      createdAt: now.subtract(const Duration(days: 1)),
      memberCount: 4,
      isUserMember: false,
      isUserConfirmed: false,
    );

    // 4. Past completed session for attendance testing
    final g4 = StudyGroupModel(
      id: 'group-4',
      creatorId: 'peer-user-sarra',
      creatorName: 'Sarra Trabelsi',
      subject: 'Comptabilité générale',
      topic: 'Journal, grand livre et balance de clôture',
      description: 'Session de clôture passée.',
      meetingLocation: 'Salle de lecture FSEGN',
      startTime: now.subtract(const Duration(days: 1, hours: 4)),
      endTime: now.subtract(const Duration(days: 1, hours: 2)),
      capacity: 5,
      status: 'active',
      createdAt: now.subtract(const Duration(days: 4)),
      memberCount: 3,
      isUserMember: true,
      isUserConfirmed: true, // student had confirmed
      userAttendanceStatus: 'pending', // ready for post-session self-reporting
    );

    _groups.addAll([g1, g2, g3, g4]);

    // Memberships for Group 1
    _members.addAll([
      GroupMemberModel(
        id: 'm1',
        groupId: 'group-1',
        userId: 'peer-user-sarra',
        role: 'creator',
        attendanceConfirmed: false,
        joinedAt: now.subtract(const Duration(days: 2)),
        displayName: 'Sarra Trabelsi',
        reliabilityScore: 95,
      ),
      GroupMemberModel(
        id: 'm2',
        groupId: 'group-1',
        userId: 'peer-user-yassine',
        role: 'member',
        attendanceConfirmed: true,
        joinedAt: now.subtract(const Duration(days: 1)),
        displayName: 'Yassine Gharbi',
        reliabilityScore: 90,
      ),
      GroupMemberModel(
        id: 'm3',
        groupId: 'group-1',
        userId: _currentProfile.id,
        role: 'member',
        attendanceConfirmed: false,
        joinedAt: now.subtract(const Duration(hours: 10)),
        displayName: _currentProfile.displayName,
        reliabilityScore: _currentProfile.reliabilityScore,
      ),
    ]);

    // Memberships for Group 3 (Full group: 4/4)
    _members.addAll([
      GroupMemberModel(
        id: 'm3-1',
        groupId: 'group-3',
        userId: 'peer-user-mariem',
        role: 'creator',
        attendanceConfirmed: true,
        joinedAt: now.subtract(const Duration(days: 1)),
        displayName: 'Mariem Khemir',
        reliabilityScore: 92,
      ),
      GroupMemberModel(
        id: 'm3-2',
        groupId: 'group-3',
        userId: 'peer-user-sarra',
        role: 'member',
        attendanceConfirmed: true,
        joinedAt: now.subtract(const Duration(hours: 20)),
        displayName: 'Sarra Trabelsi',
        reliabilityScore: 95,
      ),
      GroupMemberModel(
        id: 'm3-3',
        groupId: 'group-3',
        userId: 'peer-user-yassine',
        role: 'member',
        attendanceConfirmed: false,
        joinedAt: now.subtract(const Duration(hours: 18)),
        displayName: 'Yassine Gharbi',
        reliabilityScore: 90,
      ),
      GroupMemberModel(
        id: 'm3-4',
        groupId: 'group-3',
        userId: 'peer-user-nour',
        role: 'member',
        attendanceConfirmed: true,
        joinedAt: now.subtract(const Duration(hours: 12)),
        displayName: 'Nour Ben Ali',
        reliabilityScore: 88,
      ),
    ]);

    // Memberships for Group 4 (past group)
    _members.addAll([
      GroupMemberModel(
        id: 'm4-1',
        groupId: 'group-4',
        userId: 'peer-user-sarra',
        role: 'creator',
        attendanceConfirmed: true,
        attendanceStatus: 'attended',
        joinedAt: now.subtract(const Duration(days: 4)),
        displayName: 'Sarra Trabelsi',
        reliabilityScore: 95,
      ),
      GroupMemberModel(
        id: 'm4-2',
        groupId: 'group-4',
        userId: _currentProfile.id,
        role: 'member',
        attendanceConfirmed: true,
        attendanceStatus: 'pending',
        joinedAt: now.subtract(const Duration(days: 3)),
        displayName: _currentProfile.displayName,
        reliabilityScore: _currentProfile.reliabilityScore,
      ),
    ]);

    // Initial Messages for Group 1
    _messages.addAll([
      GroupMessageModel(
        id: 'msg-1',
        groupId: 'group-1',
        senderId: 'peer-user-sarra',
        senderName: 'Sarra Trabelsi',
        message:
            'Bonjour tout le monde ! N’oubliez pas d’apporter vos TD et vos PC portables.',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      GroupMessageModel(
        id: 'msg-2',
        groupId: 'group-1',
        senderId: 'peer-user-yassine',
        senderName: 'Yassine Gharbi',
        message: 'Parfait Sarra, j’ai déjà préparé les exercices 2 et 3 !',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  // --- Profile Operations ---
  ProfileModel getProfile() => _currentProfile;

  ProfileModel? getStudentProfile(String userId) {
    if (userId == _currentProfile.id) return _currentProfile;
    for (final member in _members) {
      if (member.userId == userId) {
        return ProfileModel(
          id: member.userId,
          displayName: member.displayName,
          reliabilityScore: member.reliabilityScore,
          createdAt: member.joinedAt,
          avatarPath: member.avatarPath,
        );
      }
    }
    return null;
  }

  List<StudyGroupModel> getGroupsForStudent(String userId) {
    final groupIds = _members
        .where((member) => member.userId == userId)
        .map((member) => member.groupId)
        .toSet();
    return _groups
        .where(
          (group) => groupIds.contains(group.id) && group.status != 'cancelled',
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> updateProfile({required String displayName, String? bio}) async {
    _currentProfile = _currentProfile.copyWith(
      displayName: displayName,
      bio: bio,
    );
  }

  // --- Group Operations ---
  List<StudyGroupModel> getGroups({
    String? subject,
    String? topicQuery,
    bool availableOnly = false,
    bool userGroupsOnly = false,
    DateTime? date,
  }) {
    return _groups.where((g) {
      if (g.status == 'cancelled') return false;
      if (subject != null && subject.isNotEmpty && g.subject != subject) {
        return false;
      }
      if (topicQuery != null && topicQuery.trim().isNotEmpty) {
        final query = topicQuery.toLowerCase().trim();
        final matchTopic = g.topic.toLowerCase().contains(query);
        final matchSubject = g.subject.toLowerCase().contains(query);
        final matchDesc = g.description?.toLowerCase().contains(query) ?? false;
        if (!matchTopic && !matchSubject && !matchDesc) return false;
      }
      if (availableOnly && g.isFull) return false;
      if (userGroupsOnly && !g.isUserMember) return false;
      if (date != null) {
        final gDate = DateTime(
          g.startTime.year,
          g.startTime.month,
          g.startTime.day,
        );
        final filterDate = DateTime(date.year, date.month, date.day);
        if (!g.sessions.any(
              (s) =>
                  s.startTime.year == filterDate.year &&
                  s.startTime.month == filterDate.month &&
                  s.startTime.day == filterDate.day,
            ) &&
            !(g.sessions.isEmpty && gDate == filterDate))
          return false;
      }
      return true;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  StudyGroupModel? getGroupById(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  List<GroupMemberModel> getGroupMembers(String groupId) {
    return _members.where((m) => m.groupId == groupId).toList();
  }

  // Directive #2: Secure capacity check before join
  Future<void> joinGroup(String groupId) async {
    final group = getGroupById(groupId);
    if (group == null) {
      throw Exception('Groupe introuvable.');
    }
    if (group.status != 'active') {
      throw Exception('Ce groupe n’est plus actif.');
    }
    final alreadyMember = _members.any(
      (m) => m.groupId == groupId && m.userId == _currentProfile.id,
    );
    if (alreadyMember) {
      throw Exception('Vous êtes déjà membre de ce groupe.');
    }

    final currentCount = _members.where((m) => m.groupId == groupId).length;
    if (currentCount >= group.capacity) {
      throw Exception(
        'Ce groupe est complet (${group.capacity} places atteintes).',
      );
    }

    final newMember = GroupMemberModel(
      id: _uuid.v4(),
      groupId: groupId,
      userId: _currentProfile.id,
      role: 'member',
      attendanceConfirmed: false, // Directive #3: unconfirmed by default
      attendanceStatus: 'pending',
      joinedAt: DateTime.now(),
      displayName: _currentProfile.displayName,
      reliabilityScore: _currentProfile.reliabilityScore,
    );

    _members.add(newMember);

    // Update group model
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      _groups[idx] = _groups[idx].copyWith(
        memberCount: currentCount + 1,
        isUserMember: true,
        isUserConfirmed: false,
        userAttendanceStatus: 'pending',
      );
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final member = _members.firstWhere(
      (m) => m.groupId == groupId && m.userId == _currentProfile.id,
      orElse: () => throw Exception('Vous n’êtes pas membre de ce groupe.'),
    );

    if (member.isCreator) {
      throw Exception(
        'Le créateur ne peut pas quitter le groupe. Vous pouvez annuler le groupe.',
      );
    }

    _members.removeWhere((m) => m.id == member.id);

    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final newCount = _members.where((m) => m.groupId == groupId).length;
      _groups[idx] = _groups[idx].copyWith(
        memberCount: newCount,
        isUserMember: false,
        isUserConfirmed: false,
      );
    }
  }

  // Directive #3: Creator added automatically as member with attendance_confirmed = false
  Future<StudyGroupModel> createGroup({
    required String name,
    required String subject,
    required String topic,
    String? description,
    required int capacity,
  }) async {
    final groupId = _uuid.v4();
    final newGroup = StudyGroupModel(
      id: groupId,
      creatorId: _currentProfile.id,
      name: name.trim(),
      creatorName: _currentProfile.displayName,
      subject: subject,
      topic: topic.trim(),
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      capacity: capacity,
      status: 'active',
      createdAt: DateTime.now(),
      memberCount: 1,
      isUserMember: true,
      isUserConfirmed: false, // Directive #3: explicitly unconfirmed
      userAttendanceStatus: 'pending',
    );

    _groups.insert(0, newGroup);

    // Add creator to members
    _members.add(
      GroupMemberModel(
        id: _uuid.v4(),
        groupId: groupId,
        userId: _currentProfile.id,
        role: 'creator',
        attendanceConfirmed: false, // unconfirmed
        attendanceStatus: 'pending',
        joinedAt: DateTime.now(),
        displayName: _currentProfile.displayName,
        reliabilityScore: _currentProfile.reliabilityScore,
      ),
    );

    return newGroup;
  }

  Future<void> createSession({
    required String groupId,
    required String topic,
    required String location,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index < 0) throw Exception('Groupe introuvable.');
    if (!_groups[index].isUserMember)
      throw Exception('Rejoignez le groupe pour planifier une séance.');
    if (start.isBefore(DateTime.now()) || !end.isAfter(start))
      throw Exception('Vérifiez les horaires de la séance.');
    final g = _groups[index];
    final session = StudySessionModel(
      id: _uuid.v4(),
      groupId: groupId,
      topic: topic.trim(),
      description: description,
      meetingLocation: location.trim(),
      startTime: start,
      endTime: end,
    );
    _groups[index] = g.copyWith(sessions: [...g.sessions, session]);
  }

  Future<void> setSessionConfirmation(String sessionId, bool confirmed) async {
    final index = _groups.indexWhere(
      (g) => g.sessions.any((s) => s.id == sessionId),
    );
    if (index < 0) throw Exception('Rencontre introuvable.');
    final group = _groups[index];
    _groups[index] = group.copyWith(
      sessions: group.sessions
          .map(
            (s) => s.id == sessionId ? s.copyWith(isConfirmed: confirmed) : s,
          )
          .toList(),
    );
  }

  Future<Map<String, dynamic>> recordSessionAttendance(
    String sessionId,
    bool attended,
  ) async {
    final index = _groups.indexWhere(
      (g) => g.sessions.any((s) => s.id == sessionId),
    );
    if (index < 0) throw Exception('Rencontre introuvable.');
    final group = _groups[index];
    final session = group.sessions.firstWhere((s) => s.id == sessionId);
    if (!session.isEnded || session.attendanceStatus != 'pending')
      throw Exception('Cette présence ne peut pas être enregistrée.');
    final delta = session.isConfirmed ? (attended ? 5 : -15) : 0;
    final score = (_currentProfile.reliabilityScore + delta).clamp(0, 100);
    _currentProfile = _currentProfile.copyWith(reliabilityScore: score);
    _groups[index] = group.copyWith(
      sessions: group.sessions
          .map(
            (s) => s.id == sessionId
                ? s.copyWith(attendanceStatus: attended ? 'attended' : 'absent')
                : s,
          )
          .toList(),
    );
    _attendanceHistory.insert(
      0,
      AttendanceRecordModel(
        groupId: group.id,
        subject: group.subject,
        topic: session.topic,
        sessionDate: session.startTime,
        wasConfirmed: session.isConfirmed,
        attendanceStatus: attended ? 'attended' : 'absent',
        scoreImpact: delta,
        recordedAt: DateTime.now(),
      ),
    );
    return {
      'success': true,
      'attended': attended,
      'score_delta': delta,
      'new_score': score,
    };
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String subject,
    required String topic,
    required String? description,
    required int capacity,
  }) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index < 0) throw Exception('Groupe introuvable.');
    if (_groups[index].creatorId != _currentProfile.id)
      throw Exception('Seul le créateur peut modifier le groupe.');
    if (capacity < _groups[index].memberCount)
      throw Exception(
        'La limite ne peut pas être inférieure au nombre actuel de membres.',
      );
    final g = _groups[index];
    _groups[index] = StudyGroupModel(
      id: g.id,
      creatorId: g.creatorId,
      name: name.trim(),
      coverImagePath: g.coverImagePath,
      subject: subject,
      topic: topic.trim(),
      description: description,
      capacity: capacity,
      status: g.status,
      cohortKey: g.cohortKey,
      createdAt: g.createdAt,
      creatorName: g.creatorName,
      memberCount: g.memberCount,
      isUserMember: g.isUserMember,
      sessions: g.sessions,
    );
  }

  Future<void> cancelGroup(String groupId) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      if (_groups[idx].creatorId != _currentProfile.id) {
        throw Exception('Seul le créateur peut annuler ce groupe.');
      }
      _groups[idx] = _groups[idx].copyWith(status: 'cancelled');
    }
  }

  // --- Attendance & Reliability Operations ---
  Future<void> setAttendanceConfirmation(String groupId, bool confirmed) async {
    final group = getGroupById(groupId);
    if (group == null) throw Exception('Groupe introuvable.');
    if (DateTime.now().isAfter(group.startTime)) {
      throw Exception(
        'La confirmation ne peut plus être modifiée une fois la session commencée.',
      );
    }

    final mIdx = _members.indexWhere(
      (m) => m.groupId == groupId && m.userId == _currentProfile.id,
    );
    if (mIdx == -1) throw Exception('Vous n’êtes pas membre de ce groupe.');

    _members[mIdx] = GroupMemberModel(
      id: _members[mIdx].id,
      groupId: _members[mIdx].groupId,
      userId: _members[mIdx].userId,
      role: _members[mIdx].role,
      attendanceConfirmed: confirmed,
      attendanceStatus: _members[mIdx].attendanceStatus,
      attendanceRecordedAt: _members[mIdx].attendanceRecordedAt,
      joinedAt: _members[mIdx].joinedAt,
      displayName: _members[mIdx].displayName,
      reliabilityScore: _members[mIdx].reliabilityScore,
    );

    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1) {
      _groups[gIdx] = _groups[gIdx].copyWith(isUserConfirmed: confirmed);
    }
  }

  // Directive #4: Idempotent self-reported attendance, capped between 0 and 100
  Future<Map<String, dynamic>> recordMyAttendance(
    String groupId,
    bool attended,
  ) async {
    final group = getGroupById(groupId);
    if (group == null) throw Exception('Groupe introuvable.');
    if (!group.isEnded) {
      throw Exception(
        'L’assiduité ne peut être enregistrée qu’après la fin de la session.',
      );
    }

    final mIdx = _members.indexWhere(
      (m) => m.groupId == groupId && m.userId == _currentProfile.id,
    );
    if (mIdx == -1) throw Exception('Vous n’êtes pas membre de ce groupe.');

    final member = _members[mIdx];
    if (member.attendanceRecordedAt != null ||
        member.attendanceStatus != 'pending') {
      throw Exception('L’assiduité pour ce groupe a déjà été enregistrée.');
    }

    int scoreDelta = 0;
    if (member.attendanceConfirmed) {
      if (attended) {
        scoreDelta = 5; // Reward
      } else {
        scoreDelta = -15; // Penalty for confirmed no-show
      }
    }

    final newScore = (_currentProfile.reliabilityScore + scoreDelta).clamp(
      0,
      100,
    );
    _currentProfile = _currentProfile.copyWith(reliabilityScore: newScore);

    final updatedMember = GroupMemberModel(
      id: member.id,
      groupId: member.groupId,
      userId: member.userId,
      role: member.role,
      attendanceConfirmed: member.attendanceConfirmed,
      attendanceStatus: attended ? 'attended' : 'absent',
      attendanceRecordedAt: DateTime.now(),
      joinedAt: member.joinedAt,
      displayName: member.displayName,
      reliabilityScore: newScore,
    );
    _members[mIdx] = updatedMember;

    // Record in history
    _attendanceHistory.insert(
      0,
      AttendanceRecordModel(
        groupId: groupId,
        subject: group.subject,
        topic: group.topic,
        sessionDate: group.startTime,
        wasConfirmed: member.attendanceConfirmed,
        attendanceStatus: attended ? 'attended' : 'absent',
        scoreImpact: scoreDelta,
        recordedAt: DateTime.now(),
      ),
    );

    final gIdx = _groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1) {
      _groups[gIdx] = _groups[gIdx].copyWith(
        userAttendanceStatus: attended ? 'attended' : 'absent',
      );
    }

    return {
      'success': true,
      'attended': attended,
      'score_delta': scoreDelta,
      'new_score': newScore,
    };
  }

  List<AttendanceRecordModel> getAttendanceHistory() => _attendanceHistory;

  // --- Group Chat Operations ---
  List<GroupMessageModel> getMessages(String groupId) {
    return _messages.where((m) => m.groupId == groupId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Stream<List<GroupMessageModel>> streamMessages(String groupId) {
    // Returns broadcast stream and immediately pushes current list
    Future.microtask(() {
      _messagesStreamController.add(getMessages(groupId));
    });
    return _messagesStreamController.stream.map((_) => getMessages(groupId));
  }

  Future<void> sendMessage(String groupId, String text) async {
    final isMember = _members.any(
      (m) => m.groupId == groupId && m.userId == _currentProfile.id,
    );
    if (!isMember) {
      throw Exception(
        'Seuls les membres du groupe peuvent envoyer des messages.',
      );
    }

    final newMsg = GroupMessageModel(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: _currentProfile.id,
      senderName: _currentProfile.displayName,
      message: text.trim(),
      createdAt: DateTime.now(),
    );

    _messages.add(newMsg);
    _messagesStreamController.add(getMessages(groupId));
  }
}
