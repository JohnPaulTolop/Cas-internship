import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';

class PracticumRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<RequirementRecord>> watchRequirements(AppUser user) {
    Query<Map<String, dynamic>> query = _db.collection('requirements');
    if (user.role == UserRole.student) {
      query = query.where('studentId', isEqualTo: user.uid);
    }
    return query.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map(RequirementRecord.fromDoc)
          .where((record) => !record.archived)
          .toList();
      records.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return records;
    });
  }

  Stream<List<DtrRecord>> watchDtr(AppUser user) {
    Query<Map<String, dynamic>> query = _db.collection('dtr_entries');
    if (user.role == UserRole.student) {
      query = query.where('studentId', isEqualTo: user.uid);
    }
    return query.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map(DtrRecord.fromDoc)
          .where((record) => !record.archived)
          .toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  Stream<List<NotificationRecord>> watchNotifications(AppUser user) {
    Query<Map<String, dynamic>> query = _db.collection('notifications');
    if (user.role == UserRole.student) {
      query = query.where(
        'targetRole',
        whereIn: ['all', user.role.value, 'user:${user.uid}'],
      );
    }
    return query.snapshots().map((snapshot) {
      var records = snapshot.docs.map(NotificationRecord.fromDoc).toList();
      if (user.role == UserRole.student) {
        records = records
            .where(
              (record) =>
                  record.active &&
                  (record.targetUserId == null ||
                      record.targetUserId == user.uid),
            )
            .toList();
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  Stream<List<AppUser>> watchUsers({UserRole? role}) {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (role != null) {
      query = query.where('role', isEqualTo: role.value);
    }
    return query.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }

  Stream<List<MoaRecord>> watchMoas() =>
      _db.collection('moas').snapshots().map((snapshot) {
        final records = snapshot.docs.map(MoaRecord.fromDoc).toList();
        records.sort((a, b) => b.endDate.compareTo(a.endDate));
        return records;
      });

  Stream<List<RequirementDefinition>> watchRequirementDefinitions() =>
      _db.collection('requirement_definitions').snapshots().map((snapshot) {
        final definitions = snapshot.docs
            .map(RequirementDefinition.fromDoc)
            .where((definition) => definition.active)
            .toList();
        definitions.sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order == 0 ? a.dueDate.compareTo(b.dueDate) : order;
        });
        return definitions;
      });

  Stream<InternshipProfileRecord?> watchInternshipProfile(String studentId) =>
      _db
          .collection('internship_profiles')
          .doc(studentId)
          .snapshots()
          .map(
            (snapshot) => snapshot.exists
                ? InternshipProfileRecord.fromDoc(snapshot)
                : null,
          );

  Stream<List<InternshipProfileRecord>> watchInternshipProfiles() => _db
      .collection('internship_profiles')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(InternshipProfileRecord.fromDoc).toList(),
      );

  Stream<List<RequirementVersionRecord>> watchRequirementVersions(
    String requirementId,
  ) => _db
      .collection('requirement_versions')
      .where('requirementId', isEqualTo: requirementId)
      .snapshots()
      .map((snapshot) {
        final versions = snapshot.docs
            .map(RequirementVersionRecord.fromDoc)
            .toList();
        versions.sort((a, b) => b.version.compareTo(a.version));
        return versions;
      });

  Stream<List<ActivityLogRecord>> watchActivityLogs() =>
      _db.collection('activity_logs').limit(200).snapshots().map((snapshot) {
        final records = snapshot.docs.map(ActivityLogRecord.fromDoc).toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      });

  Stream<List<SupervisorEvaluationRecord>> watchEvaluations() =>
      _db.collection('supervisor_evaluations').snapshots().map((snapshot) {
        final records = snapshot.docs
            .map(SupervisorEvaluationRecord.fromDoc)
            .where((record) => !record.archived)
            .toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      });

  Stream<SupervisorEvaluationRecord?> watchPublicEvaluation(String token) => _db
      .collection('supervisor_evaluations')
      .doc(token)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? SupervisorEvaluationRecord.fromDoc(snapshot)
            : null,
      );

  Stream<List<AcademicArchiveRecord>> watchAcademicArchives() =>
      _db.collection('academic_archives').snapshots().map((snapshot) {
        final records = snapshot.docs
            .map(AcademicArchiveRecord.fromDoc)
            .toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      });

  Future<AcademicArchiveContents> loadAcademicArchive(
    String academicYear,
  ) async {
    final snapshots = await Future.wait([
      _db
          .collection('requirements')
          .where('academicYear', isEqualTo: academicYear)
          .get(),
      _db
          .collection('dtr_entries')
          .where('academicYear', isEqualTo: academicYear)
          .get(),
      _db
          .collection('supervisor_evaluations')
          .where('academicYear', isEqualTo: academicYear)
          .get(),
    ]);
    return AcademicArchiveContents(
      requirements: snapshots[0].docs.map(RequirementRecord.fromDoc).toList(),
      dtr: snapshots[1].docs.map(DtrRecord.fromDoc).toList(),
      evaluations: snapshots[2].docs
          .map(SupervisorEvaluationRecord.fromDoc)
          .toList(),
    );
  }

  Future<void> submitRequirement({
    required AppUser user,
    required String title,
    required PlatformFile file,
    RequirementDefinition? definition,
  }) async {
    if (!AppConfig.hasSupabaseConfig) {
      throw StateError('Supabase is not configured for file uploads.');
    }
    final storagePath = await _uploadFile(
      ownerId: user.uid,
      folder: 'requirements',
      file: file,
    );

    await _db.collection('requirements').add({
      'studentId': user.uid,
      'studentName': user.displayName,
      'title': title,
      'definitionId': definition?.id,
      'category': definition?.category ?? 'General',
      'program': user.program,
      'studentNumber': user.studentNumber,
      'dueDate': definition == null
          ? null
          : Timestamp.fromDate(definition.dueDate),
      'version': 1,
      'status': ReviewStatus.pending.value,
      'storagePath': storagePath,
      'fileName': file.name,
      'remarks': null,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(user, 'Submitted requirement: $title');
  }

  Future<void> updateRequirementStatus({
    required String requirementId,
    required ReviewStatus status,
    required String remarks,
    required AppUser reviewer,
  }) async {
    if (reviewer.role == UserRole.student) {
      throw StateError('Students cannot review requirements.');
    }
    await _db.collection('requirements').doc(requirementId).update({
      'status': status.value,
      'remarks': remarks,
      'reviewedBy': reviewer.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final requirement = await _db
        .collection('requirements')
        .doc(requirementId)
        .get();
    final data = requirement.data();
    if (data != null) {
      await _createTargetedNotification(
        actor: reviewer,
        targetUserId: data['studentId'] as String? ?? '',
        title: status == ReviewStatus.verified
            ? '${data['title']} has been verified'
            : status == ReviewStatus.rejected
            ? '${data['title']} was rejected'
            : '${data['title']} needs revision',
        message: remarks.trim().isEmpty
            ? 'The coordinator updated your document status to ${status.label}.'
            : remarks.trim(),
        type: 'document_feedback',
        relatedId: requirementId,
      );
    }
    await _log(
      reviewer,
      'Changed requirement $requirementId to ${status.label}',
    );
  }

  Future<void> resubmitRequirement({
    required AppUser user,
    required RequirementRecord requirement,
    required PlatformFile file,
  }) async {
    if (user.role != UserRole.student || requirement.studentId != user.uid) {
      throw StateError('You cannot replace this requirement.');
    }
    if (requirement.status != ReviewStatus.needsRevision) {
      throw StateError('Only requirements needing revision can be replaced.');
    }
    final storagePath = await _uploadFile(
      ownerId: user.uid,
      folder: 'requirements',
      file: file,
    );
    if (requirement.storagePath != null && requirement.fileName != null) {
      await _db.collection('requirement_versions').add({
        'requirementId': requirement.id,
        'version': requirement.version,
        'fileName': requirement.fileName,
        'storagePath': requirement.storagePath,
        'submittedAt': Timestamp.fromDate(requirement.submittedAt),
        'status': requirement.status.value,
        'remarks': requirement.remarks,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await _db.collection('requirements').doc(requirement.id).update({
      'storagePath': storagePath,
      'fileName': file.name,
      'status': ReviewStatus.pending.value,
      'remarks': null,
      'version': requirement.version + 1,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(user, 'Resubmitted requirement: ${requirement.title}');
  }

  Future<String> createDownloadUrl(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Storage path is required.');
    }
    if (!AppConfig.hasSupabaseConfig) {
      throw StateError('Supabase is not configured for file downloads.');
    }
    return Supabase.instance.client.storage
        .from(AppConfig.supabaseBucket)
        .createSignedUrl(path, 300);
  }

  Future<RequirementRecord?> getRequirement(String id) async {
    if (id.isEmpty) {
      return null;
    }
    final snapshot = await _db.collection('requirements').doc(id).get();
    return snapshot.exists ? RequirementRecord.fromDoc(snapshot) : null;
  }

  Future<void> addDtrEntry({
    required AppUser actor,
    required String studentId,
    required String studentName,
    required DateTime date,
    required DateTime timeIn,
    required DateTime timeOut,
    required int breakMinutes,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('This module is managed by coordinators.');
    }
    if (!timeOut.isAfter(timeIn)) {
      throw ArgumentError('Time out must be later than time in.');
    }
    if (studentId.trim().isEmpty || studentName.trim().isEmpty) {
      throw ArgumentError('Select a student before saving the DTR entry.');
    }
    if (breakMinutes < 0) {
      throw ArgumentError('Break minutes cannot be negative.');
    }
    await _db.collection('dtr_entries').add({
      'studentId': studentId,
      'studentName': studentName,
      'date': Timestamp.fromDate(date),
      'timeIn': Timestamp.fromDate(timeIn),
      'timeOut': Timestamp.fromDate(timeOut),
      'breakMinutes': breakMinutes,
      'status': ReviewStatus.pending.value,
      'remarks': null,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Added DTR entry for $studentName');
  }

  Future<void> updateDtrStatus({
    required AppUser reviewer,
    required String recordId,
    required ReviewStatus status,
    required String remarks,
  }) async {
    if (reviewer.role == UserRole.student) {
      throw StateError('Students cannot review DTR entries.');
    }
    await _db.collection('dtr_entries').doc(recordId).update({
      'status': status.value,
      'remarks': remarks.trim(),
      'reviewedBy': reviewer.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(reviewer, 'Changed DTR $recordId to ${status.label}');
  }

  Future<void> sendNotification({
    required AppUser actor,
    required String title,
    required String message,
    required String targetRole,
    String? targetUserId,
    String type = 'general',
    String? relatedId,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot create notifications.');
    }
    await _db.collection('notifications').add({
      'title': title,
      'message': message,
      'targetRole': targetUserId == null ? targetRole : 'user:$targetUserId',
      'targetUserId': targetUserId,
      'type': type,
      'relatedId': relatedId,
      'readBy': <String>[],
      'createdBy': actor.uid,
      'read': false,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Published notification: $title');
  }

  Future<void> markNotificationRead({
    required AppUser user,
    required NotificationRecord notification,
  }) async {
    if (notification.isReadBy(user.uid)) {
      return;
    }
    await _db.collection('notifications').doc(notification.id).update({
      'readBy': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveInternshipProfile({
    required AppUser actor,
    required AppUser student,
    required String program,
    required String yearLevel,
    required String academicYear,
    required InternshipProfileRecord profile,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot update internship placement records.');
    }
    if (profile.requiredHours <= 0) {
      throw ArgumentError('Required hours must be greater than zero.');
    }
    final batch = _db.batch();
    batch.set(_db.collection('internship_profiles').doc(student.uid), {
      'status': profile.status,
      'placementStatus': profile.placementStatus,
      'companyName': profile.companyName.trim(),
      'department': profile.department.trim(),
      'position': profile.position.trim(),
      'startDate': profile.startDate == null
          ? null
          : Timestamp.fromDate(profile.startDate!),
      'endDate': profile.endDate == null
          ? null
          : Timestamp.fromDate(profile.endDate!),
      'requiredHours': profile.requiredHours,
      'supervisorName': profile.supervisorName.trim(),
      'supervisorEmail': profile.supervisorEmail.trim(),
      'supervisorPhone': profile.supervisorPhone.trim(),
      'coordinatorRemarks': profile.coordinatorRemarks.trim(),
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(_db.collection('users').doc(student.uid), {
      'program': program.trim(),
      'yearLevel': yearLevel.trim(),
      'academicYear': academicYear.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _log(actor, 'Updated internship profile for ${student.displayName}');
  }

  Future<void> saveRequirementDefinition({
    required AppUser actor,
    String? id,
    required String title,
    required String description,
    required String instructions,
    required String category,
    required DateTime dueDate,
    required String program,
    String? officialFormUrl,
    String? sampleFormUrl,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot configure requirement bins.');
    }
    if (title.trim().isEmpty || category.trim().isEmpty) {
      throw ArgumentError('Requirement title and category are required.');
    }
    final reference = id == null
        ? _db.collection('requirement_definitions').doc()
        : _db.collection('requirement_definitions').doc(id);
    await reference.set({
      'title': title.trim(),
      'description': description.trim(),
      'instructions': instructions.trim(),
      'category': category.trim(),
      'dueDate': Timestamp.fromDate(dueDate),
      'program': program.trim().isEmpty ? 'All Programs' : program.trim(),
      'officialFormUrl': officialFormUrl?.trim(),
      'sampleFormUrl': sampleFormUrl?.trim(),
      'active': true,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(actor, 'Configured requirement bin: $title');
  }

  Future<void> setNotificationActive({
    required AppUser actor,
    required NotificationRecord notification,
    required bool active,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot manage notifications.');
    }
    await _db.collection('notifications').doc(notification.id).update({
      'active': active,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      actor,
      '${active ? 'Activated' : 'Deactivated'} notification: ${notification.title}',
    );
  }

  Future<void> addMoa({
    required AppUser actor,
    required String partnerName,
    required String moaNumber,
    required DateTime startDate,
    required DateTime endDate,
    required PlatformFile file,
    List<String> programs = const [],
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? remarks,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot manage MOA records.');
    }
    if (partnerName.trim().isEmpty || moaNumber.trim().isEmpty) {
      throw ArgumentError('Partner name and MOA number are required.');
    }
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('The expiry date must be after the start date.');
    }
    final storagePath = await _uploadFile(
      ownerId: actor.uid,
      folder: 'moas',
      file: file,
    );
    await _db.collection('moas').add({
      'partnerName': partnerName.trim(),
      'moaNumber': moaNumber.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'storagePath': storagePath,
      'fileName': file.name,
      'programs': programs,
      'contactName': contactName?.trim(),
      'contactEmail': contactEmail?.trim(),
      'contactPhone': contactPhone?.trim(),
      'remarks': remarks?.trim(),
      'manualStatus': null,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Created MOA $moaNumber for $partnerName');
  }

  Future<void> renewMoa({
    required AppUser actor,
    required MoaRecord record,
    required DateTime endDate,
    PlatformFile? replacementFile,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot renew MOA records.');
    }
    if (!endDate.isAfter(record.startDate)) {
      throw ArgumentError('The expiry date must be after the start date.');
    }
    String? storagePath = record.storagePath;
    String? fileName = record.fileName;
    if (replacementFile != null) {
      storagePath = await _uploadFile(
        ownerId: actor.uid,
        folder: 'moas',
        file: replacementFile,
      );
      fileName = replacementFile.name;
    }
    await _db.collection('moas').doc(record.id).update({
      'endDate': Timestamp.fromDate(endDate),
      'storagePath': storagePath,
      'fileName': fileName,
      'manualStatus': null,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Renewed MOA ${record.moaNumber}');
  }

  Future<void> updateMoaDetails({
    required AppUser actor,
    required MoaRecord record,
    required String partnerName,
    required String moaNumber,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> programs,
    required String contactName,
    required String contactEmail,
    required String contactPhone,
    required String remarks,
    required String? manualStatus,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot manage MOA records.');
    }
    if (partnerName.trim().isEmpty || moaNumber.trim().isEmpty) {
      throw ArgumentError('Partner name and reference number are required.');
    }
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('The expiration date must be after the signed date.');
    }
    await _db.collection('moas').doc(record.id).update({
      'partnerName': partnerName.trim(),
      'moaNumber': moaNumber.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'programs': programs,
      'contactName': contactName.trim(),
      'contactEmail': contactEmail.trim(),
      'contactPhone': contactPhone.trim(),
      'remarks': remarks.trim(),
      'manualStatus': manualStatus,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Updated MOA ${record.moaNumber}');
  }

  Future<void> deleteMoa({
    required AppUser actor,
    required MoaRecord record,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot delete MOA records.');
    }
    await _db.collection('moas').doc(record.id).delete();
    if (record.storagePath != null && AppConfig.hasSupabaseConfig) {
      await Supabase.instance.client.storage
          .from(AppConfig.supabaseBucket)
          .remove([record.storagePath!]);
    }
    await _log(actor, 'Deleted MOA ${record.moaNumber}');
  }

  Future<void> assignStudent({
    required AppUser actor,
    required AppUser student,
    required AppUser? coordinator,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot manage coordinator assignments.');
    }
    if (student.role != UserRole.student) {
      throw ArgumentError('Only student profiles can be assigned.');
    }
    if (coordinator != null && coordinator.role != UserRole.coordinator) {
      throw ArgumentError('The selected account is not a coordinator.');
    }
    await _db.collection('users').doc(student.uid).update({
      'coordinatorId': coordinator?.uid,
      'coordinatorName': coordinator?.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      actor,
      coordinator == null
          ? 'Removed coordinator assignment for ${student.displayName}'
          : 'Assigned ${student.displayName} to ${coordinator.displayName}',
    );
  }

  Future<void> setUserActive({
    required AppUser actor,
    required AppUser target,
    required bool active,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError('Only administrators can change account status.');
    }
    if (actor.uid == target.uid && !active) {
      throw StateError('You cannot deactivate your own account.');
    }
    await _db.collection('users').doc(target.uid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      actor,
      '${active ? 'Activated' : 'Deactivated'} ${target.email}',
    );
  }

  Future<String> createSupervisorEvaluation({
    required AppUser actor,
    required AppUser student,
    required String companyName,
    required String supervisorName,
    required String supervisorEmail,
    int validDays = 14,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot create evaluation links.');
    }
    if (student.role != UserRole.student ||
        companyName.trim().isEmpty ||
        supervisorName.trim().isEmpty ||
        !supervisorEmail.contains('@') ||
        validDays < 1 ||
        validDays > 60) {
      throw ArgumentError('Complete all supervisor evaluation details.');
    }
    final secureRandom = Random.secure();
    final token = base64Url
        .encode(List<int>.generate(24, (_) => secureRandom.nextInt(256)))
        .replaceAll('=', '');
    await _db.collection('supervisor_evaluations').doc(token).set({
      'studentId': student.uid,
      'studentName': student.displayName,
      'companyName': companyName.trim(),
      'supervisorName': supervisorName.trim(),
      'supervisorEmail': supervisorEmail.trim(),
      'status': 'pending',
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(Duration(days: validDays)),
      ),
      'archived': false,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(
      actor,
      'Created supervisor evaluation for ${student.displayName}',
    );
    return token;
  }

  Future<void> submitSupervisorEvaluation({
    required String token,
    required Map<String, int> ratings,
    required String comments,
  }) async {
    const requiredRatings = {
      'professionalism',
      'workQuality',
      'attendance',
      'communication',
      'initiative',
    };
    if (!ratings.keys.toSet().containsAll(requiredRatings) ||
        ratings.values.any((rating) => rating < 1 || rating > 5)) {
      throw ArgumentError('Every rating must be between 1 and 5.');
    }
    await _db.collection('supervisor_evaluations').doc(token).update({
      'ratings': ratings,
      'comments': comments.trim(),
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveAcademicYear({
    required AppUser actor,
    required int startYear,
  }) async {
    if (actor.role == UserRole.student) {
      throw StateError('Students cannot archive academic records.');
    }
    final start = DateTime(startYear, 6, 1);
    final end = DateTime(startYear + 1, 6, 1);
    if (end.isAfter(DateTime.now())) {
      throw StateError(
        'The active or a future academic year cannot be archived.',
      );
    }
    final requirementSnapshot = await _db.collection('requirements').get();
    final dtrSnapshot = await _db.collection('dtr_entries').get();
    final evaluationSnapshot = await _db
        .collection('supervisor_evaluations')
        .get();
    final references = <DocumentReference<Map<String, dynamic>>>[];

    for (final doc in requirementSnapshot.docs) {
      if (doc.data()['archived'] == true) {
        continue;
      }
      final date = (doc.data()['submittedAt'] as Timestamp?)?.toDate();
      if (date != null && !date.isBefore(start) && date.isBefore(end)) {
        references.add(doc.reference);
      }
    }
    final requirementCount = references.length;
    for (final doc in dtrSnapshot.docs) {
      if (doc.data()['archived'] == true) {
        continue;
      }
      final date = (doc.data()['date'] as Timestamp?)?.toDate();
      if (date != null && !date.isBefore(start) && date.isBefore(end)) {
        references.add(doc.reference);
      }
    }
    final dtrCount = references.length - requirementCount;
    for (final doc in evaluationSnapshot.docs) {
      if (doc.data()['archived'] == true) {
        continue;
      }
      final date = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (date != null && !date.isBefore(start) && date.isBefore(end)) {
        references.add(doc.reference);
      }
    }
    final evaluationCount = references.length - requirementCount - dtrCount;
    if (references.isEmpty) {
      throw StateError('No records were found for that academic year.');
    }
    final academicYear = '$startYear-${startYear + 1}';
    for (var offset = 0; offset < references.length; offset += 450) {
      final batch = _db.batch();
      final endIndex = min(offset + 450, references.length);
      for (final reference in references.sublist(offset, endIndex)) {
        batch.update(reference, {
          'archived': true,
          'academicYear': academicYear,
          'archivedBy': actor.uid,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    await _db.collection('academic_archives').add({
      'academicYear': academicYear,
      'requirementCount': requirementCount,
      'dtrCount': dtrCount,
      'evaluationCount': evaluationCount,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Archived academic year $academicYear');
  }

  Future<void> _log(AppUser actor, String action) =>
      _db.collection('activity_logs').add({
        'userId': actor.uid,
        'userName': actor.displayName,
        'action': action,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _createTargetedNotification({
    required AppUser actor,
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    required String relatedId,
  }) async {
    if (targetUserId.isEmpty) {
      return;
    }
    await sendNotification(
      actor: actor,
      title: title,
      message: message,
      targetRole: UserRole.student.value,
      targetUserId: targetUserId,
      type: type,
      relatedId: relatedId,
    );
  }

  Future<String> _uploadFile({
    required String ownerId,
    required String folder,
    required PlatformFile file,
  }) async {
    if (!AppConfig.hasSupabaseConfig) {
      throw StateError('Supabase is not configured for file uploads.');
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in again before uploading a file.');
    }

    // Refresh once here so a claim granted by the local admin tool is used by
    // the Supabase access-token callback immediately.
    final token = await firebaseUser.getIdTokenResult(true);
    if (token.claims?['role'] != 'authenticated') {
      throw StateError(
        'This account does not have file-upload access yet. Ask an '
        'administrator to run tools/set_user_claims.mjs for your email, then '
        'try again.',
      );
    }
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$ownerId/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final bytes = await file.readAsBytes();
    try {
      await Supabase.instance.client.storage
          .from(AppConfig.supabaseBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(file.extension),
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      if (error.statusCode == '403' &&
          error.message.contains('Header Parameter value not allowed')) {
        throw StateError(
          'Supabase is not accepting Firebase tokens yet. In the Supabase '
          'dashboard, add Firebase project integratedschoolmanageme-8a7ef '
          'under Authentication > Third-Party Auth.',
        );
      }
      rethrow;
    }
    return path;
  }

  String _contentTypeFor(String? extension) => switch (extension
      ?.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
