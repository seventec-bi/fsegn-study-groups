/// Student profile domain model.
///
/// Email addresses stay in Supabase Auth and are deliberately excluded here.
class ProfileModel {
  final String id;
  final String displayName;
  final String? bio;
  final String university;
  final String faculty;
  final String licenceYear;
  final String specialty;
  final int reliabilityScore;
  final DateTime createdAt;
  final String? avatarPath;

  const ProfileModel({
    required this.id,
    required this.displayName,
    this.bio,
    this.university = 'Université de Carthage',
    this.faculty = 'FSEGN (Nabeul)',
    this.licenceYear = '1ère année Licence (L1)',
    this.specialty = 'Business Computing',
    this.reliabilityScore = 100,
    required this.createdAt,
    this.avatarPath,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Étudiant FSEGN',
      bio: json['bio'] as String?,
      university: json['university'] as String? ?? 'Université de Carthage',
      faculty: json['faculty'] as String? ?? 'FSEGN (Nabeul)',
      licenceYear: json['licence_year'] as String? ?? '1ère année Licence (L1)',
      specialty: json['specialty'] as String? ?? 'Business Computing',
      reliabilityScore: (json['reliability_score'] as num?)?.toInt() ?? 100,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      avatarPath: json['avatar_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'bio': bio,
    'university': university,
    'faculty': faculty,
    'licence_year': licenceYear,
    'specialty': specialty,
    'reliability_score': reliabilityScore,
    'avatar_path': avatarPath,
  };

  ProfileModel copyWith({
    String? displayName,
    String? bio,
    int? reliabilityScore,
    String? avatarPath,
  }) {
    return ProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      university: university,
      faculty: faculty,
      licenceYear: licenceYear,
      specialty: specialty,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      createdAt: createdAt,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
