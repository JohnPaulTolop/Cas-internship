import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewStatus { pending, underReview, verified, needsRevision, rejected }

extension ReviewStatusLabel on ReviewStatus {
  String get value => switch (this) {
    ReviewStatus.pending => 'pending',
    ReviewStatus.underReview => 'under_review',
    ReviewStatus.verified => 'verified',
    ReviewStatus.needsRevision => 'needs_revision',
    ReviewStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    ReviewStatus.pending => 'Pending',
    ReviewStatus.underReview => 'Under review',
    ReviewStatus.verified => 'Verified',
    ReviewStatus.needsRevision => 'Needs revision',
    ReviewStatus.rejected => 'Rejected',
  };

  static ReviewStatus parse(String? value) => switch (value) {
    'verified' => ReviewStatus.verified,
    'under_review' => ReviewStatus.underReview,
    'needs_revision' => ReviewStatus.needsRevision,
    'rejected' => ReviewStatus.rejected,
    _ => ReviewStatus.pending,
  };
}

class RequirementRecord {
  const RequirementRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.status,
    required this.submittedAt,
    this.storagePath,
    this.fileName,
    this.remarks,
    this.definitionId,
    this.category = 'General',
    this.program,
    this.studentNumber,
    this.institutionName,
    this.coordinatorId,
    this.academicYear,
    this.dueDate,
    this.reviewedAt,
    this.reviewedBy,
    this.version = 1,
    this.archived = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final ReviewStatus status;
  final DateTime submittedAt;
  final String? storagePath;
  final String? fileName;
  final String? remarks;
  final String? definitionId;
  final String category;
  final String? program;
  final String? studentNumber;
  final String? institutionName;
  final String? coordinatorId;
  final String? academicYear;
  final DateTime? dueDate;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final int version;
  final bool archived;

  factory RequirementRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RequirementRecord(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Student',
      title: data['title'] as String? ?? 'Requirement',
      status: ReviewStatusLabel.parse(data['status'] as String?),
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storagePath: data['storagePath'] as String?,
      fileName: data['fileName'] as String?,
      remarks: data['remarks'] as String?,
      definitionId: data['definitionId'] as String?,
      category: data['category'] as String? ?? 'General',
      program: data['program'] as String?,
      studentNumber: data['studentNumber'] as String?,
      institutionName: data['institutionName'] as String?,
      coordinatorId: data['coordinatorId'] as String?,
      academicYear: data['academicYear'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      version: (data['version'] as num?)?.toInt() ?? 1,
      archived: data['archived'] as bool? ?? false,
    );
  }
}

class DtrRecord {
  const DtrRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.timeIn,
    required this.timeOut,
    required this.breakMinutes,
    required this.status,
    this.remarks,
    this.coordinatorId,
    this.academicYear,
    this.archived = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final DateTime date;
  final DateTime timeIn;
  final DateTime timeOut;
  final int breakMinutes;
  final ReviewStatus status;
  final String? remarks;
  final String? coordinatorId;
  final String? academicYear;
  final bool archived;

  double get renderedHours {
    final minutes = timeOut.difference(timeIn).inMinutes - breakMinutes;
    return minutes <= 0 ? 0 : minutes / 60;
  }

  factory DtrRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    return DtrRecord(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Student',
      date: (data['date'] as Timestamp?)?.toDate() ?? now,
      timeIn: (data['timeIn'] as Timestamp?)?.toDate() ?? now,
      timeOut: (data['timeOut'] as Timestamp?)?.toDate() ?? now,
      breakMinutes: (data['breakMinutes'] as num?)?.toInt() ?? 0,
      status: ReviewStatusLabel.parse(data['status'] as String?),
      remarks: data['remarks'] as String?,
      coordinatorId: data['coordinatorId'] as String?,
      academicYear: data['academicYear'] as String?,
      archived: data['archived'] as bool? ?? false,
    );
  }
}

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.targetRole,
    this.read = false,
    this.active = true,
    this.targetUserId,
    this.type = 'general',
    this.relatedId,
    this.priority = 'normal',
    this.scheduledFor,
    this.linkUrl,
    this.createdBy,
    this.readBy = const [],
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String targetRole;
  final bool read;
  final bool active;
  final String? targetUserId;
  final String type;
  final String? relatedId;
  final String priority;
  final DateTime? scheduledFor;
  final String? linkUrl;
  final String? createdBy;
  final List<String> readBy;

  bool get isDue =>
      scheduledFor == null || !scheduledFor!.isAfter(DateTime.now());

  bool isReadBy(String userId) => read || readBy.contains(userId);

  factory NotificationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return NotificationRecord(
      id: doc.id,
      title: data['title'] as String? ?? 'Notification',
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetRole: data['targetRole'] as String? ?? 'all',
      read: data['read'] as bool? ?? false,
      active: data['active'] as bool? ?? true,
      targetUserId: data['targetUserId'] as String?,
      type: data['type'] as String? ?? 'general',
      relatedId: data['relatedId'] as String?,
      priority: data['priority'] as String? ?? 'normal',
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      linkUrl: data['linkUrl'] as String?,
      createdBy: data['createdBy'] as String?,
      readBy: (data['readBy'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class PartnerInstitutionRecord {
  const PartnerInstitutionRecord({
    required this.id,
    required this.name,
    this.address = '',
    this.institutionType = '',
    this.industryField = '',
    this.contactName = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.programs = const [],
    this.status = 'Active',
    this.remarks = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final String institutionType;
  final String industryField;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final List<String> programs;
  final String status;
  final String remarks;
  final DateTime? createdAt;

  factory PartnerInstitutionRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PartnerInstitutionRecord(
      id: doc.id,
      name: data['name'] as String? ?? 'Partner Institution',
      address: data['address'] as String? ?? '',
      institutionType: data['institutionType'] as String? ?? '',
      industryField: data['industryField'] as String? ?? '',
      contactName: data['contactName'] as String? ?? '',
      contactEmail: data['contactEmail'] as String? ?? '',
      contactPhone: data['contactPhone'] as String? ?? '',
      programs: (data['programs'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      status: data['status'] as String? ?? 'Active',
      remarks: data['remarks'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MoaRecord {
  const MoaRecord({
    required this.id,
    required this.partnerName,
    required this.moaNumber,
    required this.startDate,
    required this.endDate,
    this.partnerId,
    this.storagePath,
    this.fileName,
    this.programs = const [],
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.remarks,
    this.manualStatus,
    this.createdAt,
  });

  final String id;
  final String partnerName;
  final String moaNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String? partnerId;
  final String? storagePath;
  final String? fileName;
  final List<String> programs;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? remarks;
  final String? manualStatus;
  final DateTime? createdAt;

  bool get isExpired => endDate.isBefore(DateTime.now());

  int get daysUntilExpiry => endDate.difference(DateTime.now()).inDays;

  String get status {
    if (manualStatus == 'for_renewal') return 'For renewal';
    if (isExpired) return 'Expired';
    if (daysUntilExpiry <= 90) return 'Nearing expiration';
    return 'Active';
  }

  factory MoaRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    return MoaRecord(
      id: doc.id,
      partnerName: data['partnerName'] as String? ?? 'Partner institution',
      moaNumber: data['moaNumber'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? now,
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? now,
      partnerId: data['partnerId'] as String?,
      storagePath: data['storagePath'] as String?,
      fileName: data['fileName'] as String?,
      programs: (data['programs'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      contactName: data['contactName'] as String?,
      contactEmail: data['contactEmail'] as String?,
      contactPhone: data['contactPhone'] as String?,
      remarks: data['remarks'] as String?,
      manualStatus: data['manualStatus'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ActivityLogRecord {
  const ActivityLogRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String action;
  final DateTime createdAt;

  factory ActivityLogRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ActivityLogRecord(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'User',
      action: data['action'] as String? ?? 'Updated a record',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SupervisorEvaluationRecord {
  const SupervisorEvaluationRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.companyName,
    required this.supervisorName,
    required this.supervisorEmail,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.ratings = const {},
    this.comments,
    this.submittedAt,
    this.coordinatorId,
    this.academicYear,
    this.archived = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String companyName;
  final String supervisorName;
  final String supervisorEmail;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final Map<String, int> ratings;
  final String? comments;
  final DateTime? submittedAt;
  final String? coordinatorId;
  final String? academicYear;
  final bool archived;

  bool get submitted => status == 'submitted';
  bool get expired => !submitted && expiresAt.isBefore(DateTime.now());

  double get averageRating => ratings.isEmpty
      ? 0
      : ratings.values.fold<int>(0, (total, value) => total + value) /
            ratings.length;

  factory SupervisorEvaluationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawRatings = data['ratings'] as Map<String, dynamic>? ?? const {};
    return SupervisorEvaluationRecord(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Student',
      companyName: data['companyName'] as String? ?? '',
      supervisorName: data['supervisorName'] as String? ?? '',
      supervisorEmail: data['supervisorEmail'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ratings: rawRatings.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      comments: data['comments'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      coordinatorId: data['coordinatorId'] as String?,
      academicYear: data['academicYear'] as String?,
      archived: data['archived'] as bool? ?? false,
    );
  }
}

class AcademicArchiveRecord {
  const AcademicArchiveRecord({
    required this.id,
    required this.academicYear,
    required this.requirementCount,
    required this.dtrCount,
    required this.evaluationCount,
    required this.createdAt,
  });

  final String id;
  final String academicYear;
  final int requirementCount;
  final int dtrCount;
  final int evaluationCount;
  final DateTime createdAt;

  factory AcademicArchiveRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AcademicArchiveRecord(
      id: doc.id,
      academicYear: data['academicYear'] as String? ?? '',
      requirementCount: (data['requirementCount'] as num?)?.toInt() ?? 0,
      dtrCount: (data['dtrCount'] as num?)?.toInt() ?? 0,
      evaluationCount: (data['evaluationCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AcademicArchiveContents {
  const AcademicArchiveContents({
    required this.requirements,
    required this.dtr,
    required this.evaluations,
  });

  final List<RequirementRecord> requirements;
  final List<DtrRecord> dtr;
  final List<SupervisorEvaluationRecord> evaluations;
}


class PublicEvaluationAccessRecord {
  const PublicEvaluationAccessRecord({
    required this.token,
    required this.studentName,
    required this.companyName,
    required this.supervisorName,
    required this.status,
    required this.expiresAt,
    required this.archived,
    this.submittedAt,
  });

  final String token;
  final String studentName;
  final String companyName;
  final String supervisorName;
  final String status;
  final DateTime expiresAt;
  final bool archived;
  final DateTime? submittedAt;

  bool get submitted => status == 'submitted';
  bool get expired => !submitted && expiresAt.isBefore(DateTime.now());

  factory PublicEvaluationAccessRecord.fromJson(Map<String, dynamic> data) {
    return PublicEvaluationAccessRecord(
      token: data['token'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Student Intern',
      companyName: data['companyName'] as String? ?? '',
      supervisorName: data['supervisorName'] as String? ?? 'Industry Supervisor',
      status: data['status'] as String? ?? 'pending',
      expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      archived: data['archived'] as bool? ?? false,
      submittedAt: DateTime.tryParse(data['submittedAt'] as String? ?? ''),
    );
  }
}
