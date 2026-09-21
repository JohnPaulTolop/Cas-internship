import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
    } else if (user.role == UserRole.coordinator) {
      query = query.where('coordinatorId', isEqualTo: user.uid);
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
    } else if (user.role == UserRole.coordinator) {
      query = query.where('coordinatorId', isEqualTo: user.uid);
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
    if (user.role != UserRole.admin) {
      query = query.where(
        'targetRole',
        whereIn: ['all', user.role.value, 'user:${user.uid}'],
      );
    }
    return query.snapshots().map((snapshot) {
      var records = snapshot.docs.map(NotificationRecord.fromDoc).toList();
      if (user.role != UserRole.admin) {
        records = records
            .where(
              (record) =>
                  record.active &&
                  record.isDue &&
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

  Stream<List<AppUser>> watchStudentsFor(AppUser actor) {
    Query<Map<String, dynamic>> query =
        _db.collection('users').where('role', isEqualTo: UserRole.student.value);
    if (actor.role == UserRole.coordinator) {
      query = query.where('coordinatorId', isEqualTo: actor.uid);
    } else if (actor.role == UserRole.student) {
      query = query.where(FieldPath.documentId, isEqualTo: actor.uid);
    }
    return query.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((student) => student.active)
          .toList();
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }

  Stream<List<PartnerInstitutionRecord>> watchPartnerInstitutions() =>
      _db.collection('partner_institutions').snapshots().map((snapshot) {
        final records = snapshot.docs
            .map(PartnerInstitutionRecord.fromDoc)
            .toList();
        records.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return records;
      });

  Future<String> savePartnerInstitution({
    required AppUser actor,
    String? id,
    required String name,
    required String address,
    required String institutionType,
    required String industryField,
    required String contactName,
    required String contactEmail,
    required String contactPhone,
    required List<String> programs,
    required String status,
    required String remarks,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can manage partner institutions.',
      );
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Partner institution name is required.');
    }
    if (contactEmail.trim().isNotEmpty && !contactEmail.contains('@')) {
      throw ArgumentError('Enter a valid partner contact email.');
    }
    final reference = id == null
        ? _db.collection('partner_institutions').doc()
        : _db.collection('partner_institutions').doc(id);
    await reference.set({
      'name': name.trim(),
      'address': address.trim(),
      'institutionType': institutionType.trim(),
      'industryField': industryField.trim(),
      'contactName': contactName.trim(),
      'contactEmail': contactEmail.trim(),
      'contactPhone': contactPhone.trim(),
      'programs': programs,
      'status': status.trim().isEmpty ? 'Active' : status.trim(),
      'remarks': remarks.trim(),
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log(actor, '${id == null ? 'Added' : 'Updated'} partner institution: ${name.trim()}');
    return reference.id;
  }

  Future<void> deletePartnerInstitution({
    required AppUser actor,
    required PartnerInstitutionRecord partner,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can remove partner institutions.',
      );
    }
    final linked = await _db
        .collection('moas')
        .where('partnerId', isEqualTo: partner.id)
        .limit(1)
        .get();
    if (linked.docs.isNotEmpty) {
      throw StateError(
        'This partner has linked MOA records. Keep the partner record or update the MOA records first.',
      );
    }
    await _db.collection('partner_institutions').doc(partner.id).delete();
    await _log(actor, 'Deleted partner institution: ${partner.name}');
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

  Stream<List<InternshipProfileRecord>> watchInternshipProfilesFor(
    AppUser actor,
  ) {
    Query<Map<String, dynamic>> query = _db.collection('internship_profiles');
    if (actor.role == UserRole.coordinator) {
      query = query.where('coordinatorId', isEqualTo: actor.uid);
    } else if (actor.role == UserRole.student) {
      query = query.where(FieldPath.documentId, isEqualTo: actor.uid);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(InternshipProfileRecord.fromDoc)
          .where((profile) => !profile.archived)
          .toList(),
    );
  }

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

  Stream<List<ActivityLogRecord>> watchActivityLogs({AppUser? actor}) {
    Query<Map<String, dynamic>> query = _db.collection('activity_logs');
    if (actor?.role == UserRole.coordinator) {
      query = query.where('userId', isEqualTo: actor!.uid);
    }
    return query.limit(200).snapshots().map((snapshot) {
      final records = snapshot.docs.map(ActivityLogRecord.fromDoc).toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  Stream<List<SupervisorEvaluationRecord>> watchEvaluationsFor(AppUser actor) {
    Query<Map<String, dynamic>> query =
        _db.collection('supervisor_evaluations');
    if (actor.role == UserRole.coordinator) {
      query = query.where('coordinatorId', isEqualTo: actor.uid);
    } else if (actor.role == UserRole.student) {
      query = query.where('studentId', isEqualTo: actor.uid);
    }
    return query.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map(SupervisorEvaluationRecord.fromDoc)
          .where((record) => !record.archived)
          .toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  Stream<List<SupervisorEvaluationRecord>> watchEvaluations() =>
      _db.collection('supervisor_evaluations').snapshots().map((snapshot) {
        final records = snapshot.docs
            .map(SupervisorEvaluationRecord.fromDoc)
            .where((record) => !record.archived)
            .toList();
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return records;
      });

  Future<PublicEvaluationAccessRecord> loadPublicEvaluation(String token) async {
    final uri = Uri.parse(AppConfig.evaluationApiUrl).replace(
      queryParameters: {'token': token},
    );
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    final payload = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        payload['error'] as String? ?? 'Unable to load this evaluation link.',
      );
    }
    return PublicEvaluationAccessRecord.fromJson(payload);
  }

  Future<PublicEvaluationAccessRecord> verifyPublicEvaluationAccess({
    required String token,
    required String supervisorEmail,
  }) async {
    final response = await http.post(
      Uri.parse(AppConfig.evaluationApiUrl),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': 'verify',
        'token': token,
        'email': supervisorEmail.trim(),
      }),
    );
    final payload = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        payload['error'] as String? ?? 'Unable to verify evaluation access.',
      );
    }
    if (payload['authorized'] != true) {
      throw StateError('Evaluation access could not be verified.');
    }
    return PublicEvaluationAccessRecord.fromJson(payload);
  }

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
    String academicYear, {
    required AppUser actor,
  }) async {
    if (!actor.role.isStaff) {
      throw StateError('Archived records are available only to authorized internship staff.');
    }

    Query<Map<String, dynamic>> requirementQuery =
        _db.collection('requirements');
    Query<Map<String, dynamic>> dtrQuery = _db.collection('dtr_entries');
    Query<Map<String, dynamic>> evaluationQuery =
        _db.collection('supervisor_evaluations');

    // Program Coordinators may retrieve only records belonging to interns who
    // were assigned to them. CAS College Coordinator / SIP Admin can retrieve
    // college-wide archived records.
    if (actor.role == UserRole.coordinator) {
      requirementQuery = requirementQuery.where(
        'coordinatorId',
        isEqualTo: actor.uid,
      );
      dtrQuery = dtrQuery.where('coordinatorId', isEqualTo: actor.uid);
      evaluationQuery = evaluationQuery.where(
        'coordinatorId',
        isEqualTo: actor.uid,
      );
    }

    final snapshots = await Future.wait([
      requirementQuery.get(),
      dtrQuery.get(),
      evaluationQuery.get(),
    ]);

    final requirements = snapshots[0].docs
        .map(RequirementRecord.fromDoc)
        .where(
          (record) =>
              record.archived && record.academicYear == academicYear,
        )
        .toList();
    final dtr = snapshots[1].docs
        .map(DtrRecord.fromDoc)
        .where(
          (record) => record.archived && record.academicYear == academicYear,
        )
        .toList();
    final evaluations = snapshots[2].docs
        .map(SupervisorEvaluationRecord.fromDoc)
        .where(
          (record) => record.archived && record.academicYear == academicYear,
        )
        .toList();

    return AcademicArchiveContents(
      requirements: requirements,
      dtr: dtr,
      evaluations: evaluations,
    );
  }

  Future<void> submitRequirement({
    required AppUser user,
    required String title,
    required PlatformFile file,
    RequirementDefinition? definition,
  }) async {
    if (user.role != UserRole.student) {
      throw StateError('Only student interns submit requirement documents.');
    }
    if (!AppConfig.hasSupabaseConfig) {
      throw StateError(AppConfig.missingSupabaseMessage);
    }
    final storagePath = await _uploadFile(
      ownerId: user.uid,
      folder: 'requirements',
      file: file,
    );

    final reference = await _db.collection('requirements').add({
      'studentId': user.uid,
      'studentName': user.displayName,
      'title': title,
      'definitionId': definition?.id,
      'category': definition?.category ?? 'General',
      'program': user.program,
      'studentNumber': user.studentNumber,
      'coordinatorId': user.coordinatorId,
      'academicYear': user.academicYear,
      'dueDate': definition == null
          ? null
          : Timestamp.fromDate(definition.dueDate),
      'version': 1,
      'status': ReviewStatus.pending.value,
      'storagePath': storagePath,
      'fileName': file.name,
      'remarks': null,
      'archived': false,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(user, 'Submitted requirement: $title');
    await _syncInternshipStage(user.uid, actor: user);

    if (user.coordinatorId != null && user.coordinatorId!.isNotEmpty) {
      await _createTargetedNotification(
        actor: user,
        targetUserId: user.coordinatorId!,
        targetRole: UserRole.coordinator.value,
        title: 'New document submitted',
        message: '${user.displayName} submitted $title for review.',
        type: 'document_submission',
        relatedId: reference.id,
      );
    }
  }

  Future<void> updateRequirementStatus({
    required String requirementId,
    required ReviewStatus status,
    required String remarks,
    required AppUser reviewer,
  }) async {
    if (!reviewer.role.isStaff) {
      throw StateError('Student interns cannot review requirements.');
    }
    final requirement = await _db
        .collection('requirements')
        .doc(requirementId)
        .get();
    final data = requirement.data();
    if (data == null) {
      throw StateError('The submitted requirement no longer exists.');
    }
    final studentId = data['studentId'] as String? ?? '';
    await _assertCanManageStudent(reviewer, studentId);

    await requirement.reference.update({
      'status': status.value,
      'remarks': remarks.trim(),
      'reviewedBy': reviewer.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _createTargetedNotification(
      actor: reviewer,
      targetUserId: studentId,
      targetRole: UserRole.student.value,
      title: status == ReviewStatus.verified
          ? '${data['title']} has been verified'
          : status == ReviewStatus.rejected
          ? '${data['title']} was rejected'
          : status == ReviewStatus.underReview
          ? '${data['title']} is under review'
          : '${data['title']} needs revision',
      message: remarks.trim().isEmpty
          ? 'Your Program Coordinator updated this document to ${status.label}.'
          : remarks.trim(),
      type: 'document_feedback',
      relatedId: requirementId,
    );

    await _syncInternshipStage(studentId, actor: reviewer);
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
    if (requirement.status != ReviewStatus.needsRevision &&
        requirement.status != ReviewStatus.rejected) {
      throw StateError(
        'Only requirements needing correction can be resubmitted.',
      );
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
      'coordinatorId': user.coordinatorId,
      'academicYear': user.academicYear,
      'version': requirement.version + 1,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(user, 'Resubmitted requirement: ${requirement.title}');
    await _syncInternshipStage(user.uid, actor: user);
    if (user.coordinatorId != null && user.coordinatorId!.isNotEmpty) {
      await _createTargetedNotification(
        actor: user,
        targetUserId: user.coordinatorId!,
        targetRole: UserRole.coordinator.value,
        title: 'Corrected document resubmitted',
        message: '${user.displayName} resubmitted ${requirement.title}.',
        type: 'document_submission',
        relatedId: requirement.id,
      );
    }
  }

  Future<String> createDownloadUrl(String path) async {
    var normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Storage path is required.');
    }

    final parsed = Uri.tryParse(normalizedPath);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return normalizedPath;
    }

    if (!AppConfig.hasSupabaseConfig) {
      throw StateError(AppConfig.missingSupabaseMessage);
    }

    // Older records may contain a leading slash or the bucket name as part of
    // storagePath. Supabase createSignedUrl expects only the object path.
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
    final bucketPrefix = '${AppConfig.supabaseBucket}/';
    if (normalizedPath.startsWith(bucketPrefix)) {
      normalizedPath = normalizedPath.substring(bucketPrefix.length);
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in again before opening a stored document.');
    }

    // Refresh the token so recently assigned Supabase/Firebase custom claims are
    // available immediately. Student-owned files can be read by their owner;
    // coordinators/admins need app_role when reading another user's folder.
    var token = await firebaseUser.getIdTokenResult(true);
    var claims = token.claims ?? const <String, dynamic>{};
    var appRole = claims['app_role']?.toString();
    var supabaseRole = claims['role']?.toString();
    final ownerId = normalizedPath.split('/').first;
    final isOwner = ownerId == firebaseUser.uid;
    var isStaffClaim =
        (appRole == 'admin' || appRole == 'coordinator') &&
        supabaseRole == 'authenticated';

    // Firestore is the source of truth for Practicum Connect roles. Older or
    // manually-created staff accounts may have the correct Firestore role but
    // be missing the Firebase custom claim required by Supabase Storage RLS.
    // Repair that claim through the trusted local/Vercel Admin SDK endpoint,
    // then force-refresh the token before asking Supabase for the signed URL.
    if (!isOwner && !isStaffClaim) {
      final bearer = token.token ?? await firebaseUser.getIdToken();
      if (bearer == null || bearer.isEmpty) {
        throw StateError('Sign in again before opening another user\'s file.');
      }

      try {
        final response = await http.post(
          Uri.parse(AppConfig.staffClaimsApiUrl),
          headers: {
            'Authorization': 'Bearer $bearer',
            'Content-Type': 'application/json',
          },
        );
        final payload = response.body.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            payload['error'] as String? ??
                'Unable to verify staff storage access.',
          );
        }

        token = await firebaseUser.getIdTokenResult(true);
        claims = token.claims ?? const <String, dynamic>{};
        appRole = claims['app_role']?.toString();
        supabaseRole = claims['role']?.toString();
        isStaffClaim =
            (appRole == 'admin' || appRole == 'coordinator') &&
            supabaseRole == 'authenticated';
      } catch (error) {
        if (error is StateError) rethrow;
        throw StateError(
          'Your staff account is valid, but its storage permission could not be '
          'refreshed. Make sure the Practicum Connect local API is running '
          'during development, then try again. Details: $error',
        );
      }
    }

    if (!isOwner && !isStaffClaim) {
      throw StateError(
        'Your CAS/Program Coordinator account could not obtain the required '
        'staff storage permission. Sign out and back in, then retry.',
      );
    }

    try {
      return await Supabase.instance.client.storage
          .from(AppConfig.supabaseBucket)
          .createSignedUrl(normalizedPath, 300);
    } on StorageException catch (error) {
      if (error.statusCode == '500' &&
          error.message.toLowerCase().contains('database')) {
        throw StateError(
          'Supabase rejected the Firebase database role for this session. '
          'Practicum Connect requires Firebase claim role=authenticated and '
          'uses app_role for admin/coordinator authorization. Sign out and back '
          'in, then retry. If needed, keep the local staff-claims API running so '
          'the app can repair the token automatically.',
        );
      }
      if (error.statusCode == '404' ||
          error.statusCode == '400' ||
          error.message.toLowerCase().contains('not found')) {
        throw StateError(
          'The stored file could not be found or is not readable at "$normalizedPath". '
          'For a student requirement, verify the coordinator app_role claim and '
          'the Supabase Storage policies; if the object was deleted, the student '
          'must resubmit it. For an MOA, use Replace File / Renew to upload a new '
          'copy and repair the saved storage path.',
        );
      }
      rethrow;
    }
  }

  Future<RequirementRecord?> getRequirement(String id) async {
    if (id.isEmpty) {
      return null;
    }
    final snapshot = await _db.collection('requirements').doc(id).get();
    return snapshot.exists ? RequirementRecord.fromDoc(snapshot) : null;
  }

  Future<void> syncInternshipStatus({
    required AppUser actor,
    required String studentId,
  }) async {
    if (!actor.role.isStaff) {
      throw StateError('Only authorized internship staff can sync status.');
    }
    await _assertCanManageStudent(actor, studentId);
    await _syncInternshipStage(studentId, actor: actor);

    final evaluations = await _db
        .collection('supervisor_evaluations')
        .where('studentId', isEqualTo: studentId)
        .get();
    final pending = evaluations.docs
        .where((doc) => doc.data()['statusSyncPending'] == true)
        .toList();
    for (var offset = 0; offset < pending.length; offset += 450) {
      final batch = _db.batch();
      final docs = pending;
      final endIndex = min(offset + 450, docs.length);
      for (final doc in docs.sublist(offset, endIndex)) {
        batch.update(doc.reference, {
          'statusSyncPending': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
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
    if (!timeOut.isAfter(timeIn)) {
      throw ArgumentError('Time out must be later than time in.');
    }
    if (studentId.trim().isEmpty || studentName.trim().isEmpty) {
      throw ArgumentError('A student is required before saving a DTR entry.');
    }
    if (breakMinutes < 0) {
      throw ArgumentError('Break minutes cannot be negative.');
    }

    if (actor.role != UserRole.student || studentId != actor.uid) {
      throw StateError('Only the Student Intern can create a Daily Time Record.');
    }
    final now = DateTime.now();
    final submittedDay = DateTime(date.year, date.month, date.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    if (submittedDay != currentDay) {
      throw StateError(
        'New DTR entries are limited to the current date. After the daily cutoff, '
        'a record can only be changed when the Program Coordinator returns it for correction.',
      );
    }
    final student = actor;

    final existing = await _db
        .collection('dtr_entries')
        .where('studentId', isEqualTo: student.uid)
        .get();
    final duplicate = existing.docs.map(DtrRecord.fromDoc).any((record) {
      final recordDay = DateTime(record.date.year, record.date.month, record.date.day);
      return !record.archived && recordDay == submittedDay;
    });
    if (duplicate) {
      throw StateError(
        'A DTR entry already exists for today. Wait for coordinator review, or edit it only if it is returned for correction.',
      );
    }

    final reference = await _db.collection('dtr_entries').add({
      'studentId': student.uid,
      'studentName': student.displayName,
      'coordinatorId': student.coordinatorId,
      'academicYear': student.academicYear,
      'date': Timestamp.fromDate(date),
      'timeIn': Timestamp.fromDate(timeIn),
      'timeOut': Timestamp.fromDate(timeOut),
      'breakMinutes': breakMinutes,
      'status': ReviewStatus.pending.value,
      'remarks': null,
      'archived': false,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Submitted DTR entry for ${student.displayName}');

    if (student.coordinatorId != null && student.coordinatorId!.isNotEmpty) {
      await _createTargetedNotification(
        actor: actor,
        targetUserId: student.coordinatorId!,
        targetRole: UserRole.coordinator.value,
        title: 'DTR submitted for review',
        message:
            '${student.displayName} submitted a Daily Time Record for ${date.month}/${date.day}/${date.year}.',
        type: 'dtr_submission',
        relatedId: reference.id,
      );
    }
  }

  Future<void> updateDtrEntry({
    required AppUser student,
    required DtrRecord record,
    required DateTime date,
    required DateTime timeIn,
    required DateTime timeOut,
    required int breakMinutes,
  }) async {
    if (student.role != UserRole.student || record.studentId != student.uid) {
      throw StateError('Student interns may correct only their own DTR entries.');
    }
    if (record.status != ReviewStatus.needsRevision &&
        record.status != ReviewStatus.rejected) {
      throw StateError('Only DTR entries returned for correction can be edited.');
    }
    if (!timeOut.isAfter(timeIn)) {
      throw ArgumentError('Time out must be later than time in.');
    }
    if (breakMinutes < 0) {
      throw ArgumentError('Break minutes cannot be negative.');
    }

    await _db.collection('dtr_entries').doc(record.id).update({
      'date': Timestamp.fromDate(date),
      'timeIn': Timestamp.fromDate(timeIn),
      'timeOut': Timestamp.fromDate(timeOut),
      'breakMinutes': breakMinutes,
      'status': ReviewStatus.pending.value,
      'remarks': null,
      'coordinatorId': student.coordinatorId,
      'academicYear': student.academicYear,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(student, 'Corrected and resubmitted DTR entry ${record.id}');

    if (student.coordinatorId != null && student.coordinatorId!.isNotEmpty) {
      await _createTargetedNotification(
        actor: student,
        targetUserId: student.coordinatorId!,
        targetRole: UserRole.coordinator.value,
        title: 'Corrected DTR resubmitted',
        message: '${student.displayName} corrected and resubmitted a DTR entry.',
        type: 'dtr_submission',
        relatedId: record.id,
      );
    }
  }

  Future<void> updateDtrStatus({
    required AppUser reviewer,
    required String recordId,
    required ReviewStatus status,
    required String remarks,
  }) async {
    if (!reviewer.role.isStaff) {
      throw StateError('Student interns cannot review DTR entries.');
    }
    final reference = _db.collection('dtr_entries').doc(recordId);
    final snapshot = await reference.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('The selected DTR entry no longer exists.');
    }
    final studentId = data['studentId'] as String? ?? '';
    await _assertCanManageStudent(reviewer, studentId);

    await reference.update({
      'status': status.value,
      'remarks': remarks.trim(),
      'reviewedBy': reviewer.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createTargetedNotification(
      actor: reviewer,
      targetUserId: studentId,
      targetRole: UserRole.student.value,
      title: status == ReviewStatus.verified
          ? 'DTR entry approved'
          : status == ReviewStatus.needsRevision ||
                status == ReviewStatus.rejected
          ? 'DTR entry requires correction'
          : 'DTR review updated',
      message: remarks.trim().isEmpty
          ? 'Your DTR status is now ${status.label}.'
          : remarks.trim(),
      type: 'dtr_update',
      relatedId: recordId,
    );
    await _syncInternshipStage(studentId, actor: reviewer);
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
    String priority = 'normal',
    DateTime? scheduledFor,
    String? linkUrl,
  }) async {
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('Notification title and message are required.');
    }

    if (actor.role == UserRole.student) {
      if (targetUserId == null ||
          targetUserId != actor.coordinatorId ||
          targetRole != UserRole.coordinator.value) {
        throw StateError(
          'Student interns may only send workflow updates to their assigned Program Coordinator.',
        );
      }
    } else if (actor.role == UserRole.coordinator) {
      if (targetUserId == null || targetRole != UserRole.student.value) {
        throw StateError(
          'Program Coordinators may only send targeted workflow notifications to assigned interns.',
        );
      }
      await _assertCanManageStudent(actor, targetUserId);
    }

    await _db.collection('notifications').add({
      'title': title.trim(),
      'message': message.trim(),
      'targetRole': targetUserId == null ? targetRole : 'user:$targetUserId',
      'targetUserId': targetUserId,
      'type': type,
      'relatedId': relatedId,
      'priority': priority,
      'scheduledFor':
          scheduledFor == null ? null : Timestamp.fromDate(scheduledFor),
      'linkUrl': linkUrl?.trim().isEmpty == true ? null : linkUrl?.trim(),
      'readBy': <String>[],
      'createdBy': actor.uid,
      'read': false,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Published notification: ${title.trim()}');
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
    if (!actor.role.isStaff) {
      throw StateError('Student interns cannot update internship placement records.');
    }
    await _assertCanManageStudent(actor, student.uid);
    if (profile.requiredHours <= 0) {
      throw ArgumentError('Required hours must be greater than zero.');
    }

    final coordinatorId = student.coordinatorId ??
        (actor.role == UserRole.coordinator ? actor.uid : profile.coordinatorId);

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
      'coordinatorId': coordinatorId,
      'academicYear': academicYear.trim(),
      'archived': profile.archived,
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.update(_db.collection('users').doc(student.uid), {
      'program': program.trim(),
      'yearLevel': yearLevel.trim(),
      'academicYear': academicYear.trim(),
      'coordinatorId': coordinatorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await _syncInternshipStage(student.uid, actor: actor);
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can configure requirement bins.',
      );
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can manage notifications.',
      );
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

  Future<void> updateNotification({
    required AppUser actor,
    required NotificationRecord notification,
    required String title,
    required String message,
    required String priority,
    DateTime? scheduledFor,
    String? linkUrl,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can edit notifications.',
      );
    }
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('Notification title and message are required.');
    }
    await _db.collection('notifications').doc(notification.id).update({
      'title': title.trim(),
      'message': message.trim(),
      'priority': priority,
      'scheduledFor':
          scheduledFor == null ? null : Timestamp.fromDate(scheduledFor),
      'linkUrl': linkUrl?.trim().isEmpty == true ? null : linkUrl?.trim(),
      'updatedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _log(actor, 'Edited notification: ${notification.title}');
  }

  Future<void> deleteNotification({
    required AppUser actor,
    required NotificationRecord notification,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can delete notifications.',
      );
    }
    await _db.collection('notifications').doc(notification.id).delete();
    await _log(actor, 'Deleted notification: ${notification.title}');
  }

  Future<void> addMoa({
    required AppUser actor,
    required String partnerName,
    required String moaNumber,
    required DateTime startDate,
    required DateTime endDate,
    required PlatformFile file,
    String? partnerId,
    List<String> programs = const [],
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? remarks,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can manage partner and MOA records.',
      );
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
      'partnerId': partnerId,
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can renew MOA records.',
      );
    }
    if (!endDate.isAfter(record.startDate)) {
      throw ArgumentError('The expiry date must be after the start date.');
    }

    final previousStoragePath = record.storagePath;
    String? storagePath = previousStoragePath;
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

    // Only remove the previous object after Firestore points to the new file.
    // A cleanup failure must not undo a successful replacement.
    if (replacementFile != null &&
        previousStoragePath != null &&
        previousStoragePath.isNotEmpty &&
        previousStoragePath != storagePath) {
      try {
        await Supabase.instance.client.storage
            .from(AppConfig.supabaseBucket)
            .remove([previousStoragePath]);
      } catch (_) {
        // Best-effort cleanup. The new MOA document is already authoritative.
      }
    }

    await _log(
      actor,
      replacementFile == null
          ? 'Renewed MOA ${record.moaNumber}'
          : 'Replaced MOA file for ${record.moaNumber}',
    );
  }

  Future<void> updateMoaDetails({
    required AppUser actor,
    required MoaRecord record,
    required String partnerName,
    String? partnerId,
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can manage partner and MOA records.',
      );
    }
    if (partnerName.trim().isEmpty || moaNumber.trim().isEmpty) {
      throw ArgumentError('Partner name and reference number are required.');
    }
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('The expiration date must be after the signed date.');
    }
    await _db.collection('moas').doc(record.id).update({
      'partnerName': partnerName.trim(),
      'partnerId': partnerId,
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can delete MOA records.',
      );
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
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can assign interns to Program Coordinators.',
      );
    }
    if (student.role != UserRole.student) {
      throw ArgumentError('Only student intern profiles can be assigned.');
    }
    if (coordinator != null && coordinator.role != UserRole.coordinator) {
      throw ArgumentError('The selected account is not a Program Coordinator.');
    }

    final batch = _db.batch();
    batch.update(_db.collection('users').doc(student.uid), {
      'coordinatorId': coordinator?.uid,
      'coordinatorName': coordinator?.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _db.collection('internship_profiles').doc(student.uid),
      {
        'coordinatorId': coordinator?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Keep existing records aligned with the newly assigned coordinator so
    // Program Coordinator queries and security rules remain consistent.
    await _backfillCoordinatorAssignment(
      studentId: student.uid,
      coordinatorId: coordinator?.uid,
    );

    await _log(
      actor,
      coordinator == null
          ? 'Removed Program Coordinator assignment for ${student.displayName}'
          : 'Assigned ${student.displayName} to ${coordinator.displayName}',
    );

    if (coordinator != null) {
      await _createTargetedNotification(
        actor: actor,
        targetUserId: coordinator.uid,
        targetRole: UserRole.coordinator.value,
        title: 'New intern assigned',
        message: '${student.displayName} has been assigned to your internship group.',
        type: 'assignment',
        relatedId: student.uid,
      );
      await _createTargetedNotification(
        actor: actor,
        targetUserId: student.uid,
        targetRole: UserRole.student.value,
        title: 'Program Coordinator assigned',
        message: '${coordinator.displayName} is now your Program Coordinator.',
        type: 'assignment',
        relatedId: coordinator.uid,
      );
    }
  }

  Future<void> reviewCoordinatorRegistration({
    required AppUser actor,
    required AppUser target,
    required bool approve,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError('Only the CAS College Coordinator / SIP Admin can review coordinator requests.');
    }
    if (target.role != UserRole.coordinator ||
        target.approvalStatus != 'pending') {
      throw StateError('This coordinator request is no longer pending.');
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != actor.uid) {
      throw StateError('Your CAS College Coordinator / SIP Admin session has expired. Sign in again.');
    }
    final token = await currentUser.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('Unable to refresh the CAS College Coordinator / SIP Admin security token.');
    }

    final endpoint = Uri.parse(AppConfig.coordinatorApprovalApiUrl);
    http.Response response;
    try {
      response = await http.post(
        endpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'uid': target.uid,
          'action': approve ? 'approve' : 'reject',
        }),
      );
    } catch (error) {
      throw StateError(
        'The coordinator approval service could not be reached. For local '
        'testing, start tools/approval_server.mjs and set '
        'COORDINATOR_APPROVAL_API_URL in config/local.json. On Vercel, deploy '
        'the included /api/coordinator-approval endpoint. Details: $error',
      );
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload?['error']?.toString();
      throw StateError(
        message == null || message.isEmpty
            ? 'Coordinator approval failed (${response.statusCode}).'
            : message,
      );
    }

    await _log(
      actor,
      '${approve ? 'Approved' : 'Rejected'} coordinator registration for ${target.email}',
    );
  }

  Future<void> setUserActive({
    required AppUser actor,
    required AppUser target,
    required bool active,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError('Only the CAS College Coordinator / SIP Admin can change account status.');
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
    if (!actor.role.isStaff) {
      throw StateError('Student interns cannot create supervisor evaluation links.');
    }
    await _assertCanManageStudent(actor, student.uid);
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
      'supervisorEmail': supervisorEmail.trim().toLowerCase(),
      'coordinatorId':
          student.coordinatorId ??
          (actor.role == UserRole.coordinator ? actor.uid : null),
      'academicYear': student.academicYear,
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
    required String supervisorEmail,
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

    final response = await http.post(
      Uri.parse(AppConfig.evaluationApiUrl),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': token,
        'email': supervisorEmail.trim(),
        'ratings': ratings,
        'comments': comments.trim(),
      }),
    );
    final payload = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        payload['error'] as String? ?? 'Unable to submit the evaluation.',
      );
    }
  }

  Future<void> logReportGeneration({
    required AppUser actor,
    required String format,
    required int rowCount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can generate college-wide reports.',
      );
    }
    final rangeLabel = startDate == null || endDate == null
        ? 'all dates'
        : '${startDate.year}-${startDate.month}-${startDate.day} to '
              '${endDate.year}-${endDate.month}-${endDate.day}';
    await _log(
      actor,
      'Generated ${format.toUpperCase()} internship report ($rowCount row(s), $rangeLabel)',
    );
  }

  Future<void> archiveAcademicYear({
    required AppUser actor,
    required int startYear,
  }) async {
    if (actor.role != UserRole.admin) {
      throw StateError(
        'Only the CAS College Coordinator / SIP Admin can archive academic-year records.',
      );
    }
    final end = DateTime(startYear + 1, 6, 1);
    if (end.isAfter(DateTime.now())) {
      throw StateError(
        'The active or a future academic year cannot be archived.',
      );
    }

    final academicYear = '$startYear-${startYear + 1}';
    final profileSnapshot = await _db
        .collection('internship_profiles')
        .where('academicYear', isEqualTo: academicYear)
        .get();

    final completedStudents = profileSnapshot.docs
        .where((doc) {
          final data = doc.data();
          return data['archived'] != true &&
              InternshipStageLabel.parse(data['status'] as String?) ==
                  InternshipStage.completed;
        })
        .map((doc) => doc.id)
        .toSet();

    if (completedStudents.isEmpty) {
      throw StateError(
        'No completed internship records are eligible for archiving in AY $academicYear.',
      );
    }

    final requirementSnapshot = await _db
        .collection('requirements')
        .where('academicYear', isEqualTo: academicYear)
        .get();
    final dtrSnapshot = await _db
        .collection('dtr_entries')
        .where('academicYear', isEqualTo: academicYear)
        .get();
    final evaluationSnapshot = await _db
        .collection('supervisor_evaluations')
        .where('academicYear', isEqualTo: academicYear)
        .get();

    final references = <DocumentReference<Map<String, dynamic>>>[];
    var requirementCount = 0;
    var dtrCount = 0;
    var evaluationCount = 0;

    for (final doc in requirementSnapshot.docs) {
      final data = doc.data();
      if (data['archived'] == true ||
          !completedStudents.contains(data['studentId'])) {
        continue;
      }
      if (ReviewStatusLabel.parse(data['status'] as String?) !=
          ReviewStatus.verified) {
        throw StateError(
          'All requirements must be verified before AY $academicYear can be archived.',
        );
      }
      references.add(doc.reference);
      requirementCount++;
    }

    for (final doc in dtrSnapshot.docs) {
      final data = doc.data();
      if (data['archived'] == true ||
          !completedStudents.contains(data['studentId'])) {
        continue;
      }
      if (ReviewStatusLabel.parse(data['status'] as String?) !=
          ReviewStatus.verified) {
        throw StateError(
          'All DTR entries must be approved before AY $academicYear can be archived.',
        );
      }
      references.add(doc.reference);
      dtrCount++;
    }

    for (final doc in evaluationSnapshot.docs) {
      final data = doc.data();
      if (data['archived'] == true ||
          !completedStudents.contains(data['studentId'])) {
        continue;
      }
      if (data['status'] != 'submitted') {
        throw StateError(
          'Supervisor evaluations must be submitted before AY $academicYear can be archived.',
        );
      }
      references.add(doc.reference);
      evaluationCount++;
    }

    for (final profile in profileSnapshot.docs) {
      if (!completedStudents.contains(profile.id)) continue;
      references.add(profile.reference);
    }

    for (var offset = 0; offset < references.length; offset += 450) {
      final batch = _db.batch();
      final endIndex = min(offset + 450, references.length);
      for (final reference in references.sublist(offset, endIndex)) {
        batch.update(reference, {
          'archived': true,
          'academicYear': academicYear,
          'archivedBy': actor.uid,
          'archivedAt': FieldValue.serverTimestamp(),
          if (reference.parent.id == 'internship_profiles')
            'status': InternshipStage.archived.value,
        });
      }
      await batch.commit();
    }

    await _db.collection('academic_archives').add({
      'academicYear': academicYear,
      'requirementCount': requirementCount,
      'dtrCount': dtrCount,
      'evaluationCount': evaluationCount,
      'studentCount': completedStudents.length,
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
    required String targetRole,
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
      targetRole: targetRole,
      targetUserId: targetUserId,
      type: type,
      relatedId: relatedId,
    );
  }

  Future<void> _assertCanManageStudent(
    AppUser actor,
    String studentId,
  ) async {
    if (actor.role == UserRole.admin) {
      return;
    }
    if (actor.role != UserRole.coordinator) {
      throw StateError('This action is restricted to authorized staff.');
    }
    final snapshot = await _db.collection('users').doc(studentId).get();
    final data = snapshot.data();
    if (data == null ||
        data['role'] != UserRole.student.value ||
        data['coordinatorId'] != actor.uid) {
      throw StateError(
        'This student intern is not assigned to your Program Coordinator account.',
      );
    }
  }

  Future<void> _backfillCoordinatorAssignment({
    required String studentId,
    required String? coordinatorId,
  }) async {
    const collections = [
      'requirements',
      'dtr_entries',
      'supervisor_evaluations',
    ];
    for (final collection in collections) {
      final snapshot = await _db
          .collection(collection)
          .where('studentId', isEqualTo: studentId)
          .get();
      for (var offset = 0; offset < snapshot.docs.length; offset += 450) {
        final batch = _db.batch();
        final endIndex = min(offset + 450, snapshot.docs.length);
        for (final doc in snapshot.docs.sublist(offset, endIndex)) {
          batch.update(doc.reference, {
            'coordinatorId': coordinatorId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    }
  }

  Future<void> _syncInternshipStage(
    String studentId, {
    required AppUser actor,
  }) async {
    if (studentId.isEmpty) return;

    final userSnapshot = await _db.collection('users').doc(studentId).get();
    final userData = userSnapshot.data();
    if (userData == null || userData['role'] != UserRole.student.value) {
      return;
    }

    final profileReference = _db.collection('internship_profiles').doc(studentId);
    final profileSnapshot = await profileReference.get();
    final profileData = profileSnapshot.data() ?? <String, dynamic>{};

    if (profileData['archived'] == true) {
      if (profileData['status'] != InternshipStage.archived.value) {
        await profileReference.set({
          'status': InternshipStage.archived.value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    final program = userData['program'] as String?;
    final definitionsSnapshot =
        await _db.collection('requirement_definitions').get();
    final definitions = definitionsSnapshot.docs
        .map(RequirementDefinition.fromDoc)
        .where((definition) =>
            definition.active && definition.appliesToProgram(program))
        .toList();

    final requirementSnapshot = await _db
        .collection('requirements')
        .where('studentId', isEqualTo: studentId)
        .get();
    final activeRequirements = requirementSnapshot.docs
        .map(RequirementRecord.fromDoc)
        .where((record) => !record.archived)
        .toList();

    RequirementRecord? recordFor(RequirementDefinition definition) {
      final candidates = activeRequirements
          .where(
            (record) =>
                record.definitionId == definition.id ||
                (record.definitionId == null &&
                    record.title.trim().toLowerCase() ==
                        definition.title.trim().toLowerCase()),
          )
          .toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return candidates.isEmpty ? null : candidates.first;
    }

    final deploymentDefinitions =
        definitions.where((definition) => definition.blocksDeployment).toList();
    final prerequisites = deploymentDefinitions.isEmpty
        ? definitions
        : deploymentDefinitions;
    final completionDefinitions = definitions
        .where((definition) => definition.isCompletionRequirement)
        .toList();

    final allSubmitted =
        prerequisites.isNotEmpty &&
        prerequisites.every((definition) => recordFor(definition) != null);
    final allVerified =
        allSubmitted &&
        prerequisites.every(
          (definition) =>
              recordFor(definition)?.status == ReviewStatus.verified,
        );

    InternshipStage nextStage;
    if (!allSubmitted) {
      nextStage = InternshipStage.pendingRequirements;
    } else if (!allVerified) {
      nextStage = InternshipStage.forVerification;
    } else {
      final placementStatus =
          (profileData['placementStatus'] as String? ?? 'Unassigned')
              .toLowerCase();
      final placementConfirmed =
          placementStatus.contains('confirm') ||
          placementStatus.contains('deploy') ||
          placementStatus.contains('ongoing') ||
          placementStatus.contains('active');

      if (!placementConfirmed) {
        nextStage = InternshipStage.readyForDeployment;
      } else {
        final dtrSnapshot = await _db
            .collection('dtr_entries')
            .where('studentId', isEqualTo: studentId)
            .get();
        final approvedHours = dtrSnapshot.docs
            .map(DtrRecord.fromDoc)
            .where(
              (record) =>
                  !record.archived && record.status == ReviewStatus.verified,
            )
            .fold<double>(0, (total, record) => total + record.renderedHours);

        final requiredHours =
            (profileData['requiredHours'] as num?)?.toDouble() ?? 400;
        final evaluationSnapshot = await _db
            .collection('supervisor_evaluations')
            .where('studentId', isEqualTo: studentId)
            .get();
        final evaluationSubmitted = evaluationSnapshot.docs.any(
          (doc) =>
              doc.data()['archived'] != true &&
              doc.data()['status'] == 'submitted',
        );

        final completionRequirementsVerified =
            completionDefinitions.isEmpty ||
            completionDefinitions.every(
              (definition) =>
                  recordFor(definition)?.status == ReviewStatus.verified,
            );

        nextStage =
            approvedHours >= requiredHours &&
                evaluationSubmitted &&
                completionRequirementsVerified
            ? InternshipStage.completed
            : InternshipStage.ongoingInternship;
      }
    }

    final previousStatus =
        profileData['status'] as String? ??
        InternshipStage.pendingRequirements.value;
    final nextStatus = nextStage.value;
    final coordinatorId =
        userData['coordinatorId'] as String? ??
        profileData['coordinatorId'] as String?;
    final academicYear =
        userData['academicYear'] as String? ??
        profileData['academicYear'] as String?;

    await profileReference.set({
      'status': nextStatus,
      'coordinatorId': coordinatorId,
      'academicYear': academicYear,
      'archived': false,
      if (nextStage == InternshipStage.completed &&
          profileData['completedAt'] == null)
        'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previousStatus != nextStatus && actor.role.isStaff) {
      await _createTargetedNotification(
        actor: actor,
        targetUserId: studentId,
        targetRole: UserRole.student.value,
        title: 'Internship status updated',
        message: 'Your internship status is now $nextStatus.',
        type: 'status_update',
        relatedId: studentId,
      );
    }
  }

  Future<String> _uploadFile({
    required String ownerId,
    required String folder,
    required PlatformFile file,
  }) async {
    if (!AppConfig.hasSupabaseConfig) {
      throw StateError(AppConfig.missingSupabaseMessage);
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in again before uploading a file.');
    }

    // Refresh the Firebase ID token so Supabase receives the latest session.
    // Student interns do not need an app_role custom claim to upload into
    // their own UID folder; the Storage RLS policy enforces ownership.
    await firebaseUser.getIdTokenResult(true);
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
