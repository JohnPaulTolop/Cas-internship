enum UserRole { admin, coordinator, student }

extension UserRoleLabel on UserRole {
  String get value => name;

  String get label => switch (this) {
    UserRole.admin => 'CAS College Coordinator',
    UserRole.coordinator => 'Program Coordinator',
    UserRole.student => 'Student Intern',
  };

  String get longLabel => switch (this) {
    UserRole.admin => 'CAS College Coordinator / SIP Admin',
    UserRole.coordinator => 'Program Adviser / Coordinator',
    UserRole.student => 'Student / Intern',
  };

  bool get isStaff => this == UserRole.admin || this == UserRole.coordinator;
  bool get isCollegeAdmin => this == UserRole.admin;
  bool get isProgramCoordinator => this == UserRole.coordinator;

  static UserRole parse(String? value) => switch (value?.toLowerCase()) {
    'admin' || 'cas_coordinator' || 'sip_admin' => UserRole.admin,
    'coordinator' || 'program_coordinator' || 'program_adviser' =>
      UserRole.coordinator,
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
    this.staffId,
    this.department,
    this.approvalStatus = 'approved',
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
  final String? staffId;
  final String? department;
  final String approvalStatus;
  final String? coordinatorId;
  final String? coordinatorName;
  final String? program;
  final String? yearLevel;
  final String? academicYear;
  final String? phone;
  final String? photoUrl;
  final bool active;

  bool get isPendingCoordinator =>
      role == UserRole.coordinator && approvalStatus == 'pending';

  bool get isRejectedCoordinator =>
      role == UserRole.coordinator && approvalStatus == 'rejected';

  bool get isApprovedCoordinator =>
      role == UserRole.coordinator && approvalStatus == 'approved';

  bool isAssignedTo(String coordinatorUid) => coordinatorId == coordinatorUid;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final role = UserRoleLabel.parse(data['role'] as String?);
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName:
          data['displayName'] as String? ??
          data['display_name'] as String? ??
          'Practicum Connect User',
      role: role,
      studentNumber: data['studentNumber'] as String?,
      staffId: data['staffId'] as String?,
      department: data['department'] as String?,
      approvalStatus: data['approvalStatus'] as String? ?? 'approved',
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
}
