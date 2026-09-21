import 'package:cloud_firestore/cloud_firestore.dart';

enum InternshipStage {
  pendingRequirements,
  forVerification,
  readyForDeployment,
  ongoingInternship,
  completed,
  archived,
}

extension InternshipStageLabel on InternshipStage {
  String get value => switch (this) {
    InternshipStage.pendingRequirements => 'Pending Requirements',
    InternshipStage.forVerification => 'For Verification',
    InternshipStage.readyForDeployment => 'Ready for Deployment',
    InternshipStage.ongoingInternship => 'Ongoing Internship',
    InternshipStage.completed => 'Completed',
    InternshipStage.archived => 'Archived',
  };

  /// Human-readable stage name used throughout the UI.
  String get label => value;

  static InternshipStage parse(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('_', ' ');
    return switch (normalized) {
      'for verification' => InternshipStage.forVerification,
      'ready for deployment' => InternshipStage.readyForDeployment,
      'ongoing internship' || 'ongoing' => InternshipStage.ongoingInternship,
      'completed' || 'complete' => InternshipStage.completed,
      'archived' => InternshipStage.archived,
      _ => InternshipStage.pendingRequirements,
    };
  }
}

class RequirementDefinition {
  const RequirementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.category,
    required this.dueDate,
    this.program = 'All Programs',
    this.officialFormUrl,
    this.sampleFormUrl,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String title;
  final String description;
  final String instructions;
  final String category;
  final DateTime dueDate;
  final String program;
  final String? officialFormUrl;
  final String? sampleFormUrl;
  final int sortOrder;
  final bool active;

  bool appliesToProgram(String? studentProgram) =>
      program == 'All Programs' ||
      program.trim().isEmpty ||
      (studentProgram != null && program == studentProgram);

  String get _workflowKey => '$category $title'.toLowerCase();

  bool get isOngoingRequirement =>
      _workflowKey.contains('weekly') ||
      _workflowKey.contains('dtr') ||
      _workflowKey.contains('daily time') ||
      _workflowKey.contains('monitoring');

  bool get isCompletionRequirement =>
      _workflowKey.contains('performance') ||
      _workflowKey.contains('evaluation') ||
      _workflowKey.contains('final report') ||
      _workflowKey.contains('narrative') ||
      _workflowKey.contains('exit form');

  bool get blocksDeployment =>
      !isOngoingRequirement && !isCompletionRequirement;

  factory RequirementDefinition.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RequirementDefinition(
      id: doc.id,
      title: data['title'] as String? ?? 'Internship requirement',
      description: data['description'] as String? ?? '',
      instructions: data['instructions'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      program: data['program'] as String? ?? 'All Programs',
      officialFormUrl: data['officialFormUrl'] as String?,
      sampleFormUrl: data['sampleFormUrl'] as String?,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }
}

class InternshipProfileRecord {
  const InternshipProfileRecord({
    required this.studentId,
    this.status = 'Pending Requirements',
    this.placementStatus = 'Unassigned',
    this.companyName = '',
    this.department = '',
    this.position = '',
    this.startDate,
    this.endDate,
    this.requiredHours = 400,
    this.supervisorName = '',
    this.supervisorEmail = '',
    this.supervisorPhone = '',
    this.coordinatorRemarks = '',
    this.coordinatorId,
    this.academicYear,
    this.archived = false,
    this.completedAt,
    this.archivedAt,
  });

  final String studentId;
  final String status;
  final String placementStatus;
  final String companyName;
  final String department;
  final String position;
  final DateTime? startDate;
  final DateTime? endDate;
  final int requiredHours;
  final String supervisorName;
  final String supervisorEmail;
  final String supervisorPhone;
  final String coordinatorRemarks;
  final String? coordinatorId;
  final String? academicYear;
  final bool archived;
  final DateTime? completedAt;
  final DateTime? archivedAt;

  InternshipStage get stage => archived
      ? InternshipStage.archived
      : InternshipStageLabel.parse(status);

  bool get placementConfirmed {
    final value = placementStatus.toLowerCase();
    return value.contains('confirm') ||
        value.contains('deploy') ||
        value.contains('ongoing') ||
        value.contains('active');
  }

  factory InternshipProfileRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InternshipProfileRecord(
      studentId: doc.id,
      status: data['status'] as String? ?? 'Pending Requirements',
      placementStatus: data['placementStatus'] as String? ?? 'Unassigned',
      companyName: data['companyName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      position: data['position'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      requiredHours: (data['requiredHours'] as num?)?.toInt() ?? 400,
      supervisorName: data['supervisorName'] as String? ?? '',
      supervisorEmail: data['supervisorEmail'] as String? ?? '',
      supervisorPhone: data['supervisorPhone'] as String? ?? '',
      coordinatorRemarks: data['coordinatorRemarks'] as String? ?? '',
      coordinatorId: data['coordinatorId'] as String?,
      academicYear: data['academicYear'] as String?,
      archived: data['archived'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RequirementVersionRecord {
  const RequirementVersionRecord({
    required this.id,
    required this.requirementId,
    required this.version,
    required this.fileName,
    required this.storagePath,
    required this.submittedAt,
    required this.status,
    this.remarks,
  });

  final String id;
  final String requirementId;
  final int version;
  final String fileName;
  final String storagePath;
  final DateTime submittedAt;
  final String status;
  final String? remarks;

  factory RequirementVersionRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RequirementVersionRecord(
      id: doc.id,
      requirementId: data['requirementId'] as String? ?? '',
      version: (data['version'] as num?)?.toInt() ?? 1,
      fileName: data['fileName'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      remarks: data['remarks'] as String?,
    );
  }
}
