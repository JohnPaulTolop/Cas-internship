enum UserRole { admin, coordinator, student }

extension UserRoleLabel on UserRole {
  String get value => name;

  String get label => switch (this) {
    UserRole.admin => 'Administrator',
    UserRole.coordinator => 'Coordinator',
    UserRole.student => 'Student',
  };

  static UserRole parse(String? value) => switch (value?.toLowerCase()) {
    'admin' => UserRole.admin,
    'coordinator' => UserRole.coordinator,
    'student' || 'intern' => UserRole.student,
    _ => throw const FormatException('Unsupported user role'),
  };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.studentNumber,
    this.coordinatorId,
    this.coordinatorName,
    this.program,
    this.yearLevel,
    this.academicYear,
    this.phone,
    this.photoUrl,
    this.active = true,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? studentNumber;
  final String? coordinatorId;
  final String? coordinatorName;
  final String? program;
  final String? yearLevel;
  final String? academicYear;
  final String? phone;
  final String? photoUrl;
  final bool active;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
    uid: uid,
    email: data['email'] as String? ?? '',
    displayName:
        data['displayName'] as String? ??
        data['display_name'] as String? ??
        'Practicum Connect User',
    role: UserRoleLabel.parse(data['role'] as String?),
    studentNumber: data['studentNumber'] as String?,
    coordinatorId: data['coordinatorId'] as String?,
    coordinatorName: data['coordinatorName'] as String?,
    program: data['program'] as String?,
    yearLevel: data['yearLevel'] as String?,
    academicYear: data['academicYear'] as String?,
    phone: data['phone'] as String?,
    photoUrl: data['photoUrl'] as String?,
    active: data['active'] as bool? ?? true,
  );
}
