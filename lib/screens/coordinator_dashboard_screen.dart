import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
import 'document_workflow_screens.dart';
import 'moa_management_screen.dart';
import 'student_profile_screen.dart';
import 'workflow_shared.dart';

class CoordinatorDashboardScreen extends StatefulWidget {
  const CoordinatorDashboardScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<CoordinatorDashboardScreen> createState() =>
      _CoordinatorDashboardScreenState();
}

class _CoordinatorDashboardScreenState
    extends State<CoordinatorDashboardScreen> {
  AppUser? _selectedStudent;
  String _program = 'All Programs';
  String _academicYear = 'All Academic Years';

  Future<void> _openDocumentReview() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Document Review')),
        backgroundColor: AppTheme.background,
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: DocumentReviewScreen(
            user: widget.user,
            repository: widget.repository,
          ),
        ),
      ),
    ),
  );

  Future<void> _openMoaManagement() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Partner Institutions & MOA')),
        backgroundColor: AppTheme.background,
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: MoaManagementScreen(
            user: widget.user,
            repository: widget.repository,
          ),
        ),
      ),
    ),
  );

  Future<void> _showActivityHistory() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Recent Activity'),
      content: SizedBox(
        width: 620,
        height: 480,
        child: StreamBuilder<List<ActivityLogRecord>>(
          stream: widget.repository.watchActivityLogs(actor: widget.user),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load activity: ${snapshot.error}'),
              );
            }
            final records = snapshot.data ?? const <ActivityLogRecord>[];
            if (records.isEmpty) {
              return const Center(child: Text('No recent activity.'));
            }
            return ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history, size: 18),
                  ),
                  title: Text(record.action),
                  subtitle: Text(
                    '${record.userName} • ${DateFormat.yMMMd().add_jm().format(record.createdAt)}',
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: widget.repository.watchStudentsFor(widget.user),
    builder: (context, userSnapshot) {
      final allStudents = userSnapshot.data ?? const <AppUser>[];
      final programs = {
        'All Programs',
        ...allStudents.map((student) => student.program).whereType<String>(),
      }.toList();
      final academicYears = {
        'All Academic Years',
        ...allStudents
            .map((student) => student.academicYear)
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty),
      }.toList()..sort();
      final effectiveProgram = programs.contains(_program)
          ? _program
          : 'All Programs';
      final effectiveAcademicYear = academicYears.contains(_academicYear)
          ? _academicYear
          : 'All Academic Years';
      final students = allStudents.where((student) {
        final programMatches =
            effectiveProgram == 'All Programs' ||
            student.program == effectiveProgram;
        final yearMatches =
            effectiveAcademicYear == 'All Academic Years' ||
            student.academicYear == effectiveAcademicYear;
        return programMatches && yearMatches;
      }).toList();

      return StreamBuilder<List<RequirementRecord>>(
        stream: widget.repository.watchRequirements(widget.user),
        builder: (context, requirementSnapshot) {
          final allRequirements =
              requirementSnapshot.data ?? const <RequirementRecord>[];
          final selectedStudentIds = students
              .map((student) => student.uid)
              .toSet();
          final requirements = allRequirements
              .where((record) => selectedStudentIds.contains(record.studentId))
              .toList();
          return StreamBuilder<List<MoaRecord>>(
            stream: widget.user.role == UserRole.admin
                ? widget.repository.watchMoas()
                : Stream<List<MoaRecord>>.value(const <MoaRecord>[]),
            builder: (context, moaSnapshot) {
              final moas = moaSnapshot.data ?? const <MoaRecord>[];
              return StreamBuilder<List<InternshipProfileRecord>>(
                stream: widget.repository.watchInternshipProfilesFor(
                  widget.user,
                ),
                builder: (context, profileSnapshot) {
                  final allProfiles =
                      profileSnapshot.data ?? const <InternshipProfileRecord>[];
                  final profiles = allProfiles
                      .where(
                        (profile) =>
                            selectedStudentIds.contains(profile.studentId),
                      )
                      .toList();
                  return StreamBuilder<List<DtrRecord>>(
                    stream: widget.repository.watchDtr(widget.user),
                    builder: (context, dtrSnapshot) {
                      final allDtr = dtrSnapshot.data ?? const <DtrRecord>[];
                      final dtr = allDtr
                          .where(
                            (record) =>
                                selectedStudentIds.contains(record.studentId),
                          )
                          .toList();
                      final selected =
                          _selectedStudent != null &&
                              selectedStudentIds.contains(_selectedStudent!.uid)
                          ? _selectedStudent
                          : (students.isEmpty ? null : students.first);
                      final selectedProfile = selected == null
                          ? null
                          : profiles
                                .where(
                                  (profile) =>
                                      profile.studentId == selected.uid,
                                )
                                .firstOrNull;

                      return WorkflowPage(
                        title: widget.user.role == UserRole.admin
                            ? 'CAS Dashboard'
                            : 'Program Coordinator Dashboard',
                        subtitle: widget.user.role == UserRole.admin
                            ? 'Monitor CAS internship records, documents, partnerships, status, and college-wide activity.'
                            : 'Monitor assigned interns, review requirements, and track internship progress.',
                        eyebrow: 'Home  ›  Dashboard',
                        actions: [
                          SizedBox(
                            width: 178,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: effectiveAcademicYear,
                              decoration: const InputDecoration(
                                labelText: 'Academic Year',
                              ),
                              items: academicYears
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _academicYear =
                                    value ?? 'All Academic Years',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: effectiveProgram,
                              decoration: const InputDecoration(
                                labelText: 'CAS Program',
                              ),
                              items: programs
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _program = value ?? 'All Programs',
                              ),
                            ),
                          ),
                        ],
                        child: ListView(
                          children: [
                            _DashboardStats(
                              students: students,
                              requirements: requirements,
                              profiles: profiles,
                              moas: moas,
                              showMoa: widget.user.role == UserRole.admin,
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final left = Column(
                                  children: [
                                    _RecentSubmissions(
                                      requirements: requirements,
                                      onViewAll: _openDocumentReview,
                                      onSelect: (record) {
                                        final match = allStudents.where(
                                          (student) =>
                                              student.uid == record.studentId,
                                        );
                                        if (match.isNotEmpty) {
                                          setState(
                                            () =>
                                                _selectedStudent = match.first,
                                          );
                                        }
                                      },
                                    ),
                                    if (widget.user.role == UserRole.admin) ...[
                                      const SizedBox(height: 10),
                                      _PartnerStatus(
                                        moas: moas,
                                        onViewAll: _openMoaManagement,
                                      ),
                                    ],
                                  ],
                                );
                                final middle = Column(
                                  children: [
                                    _NeedsAttention(
                                      requirements: requirements,
                                      onViewAll: _openDocumentReview,
                                    ),
                                    const SizedBox(height: 10),
                                    _DashboardActivity(
                                      repository: widget.repository,
                                      actor: widget.user,
                                      onViewAll: _showActivityHistory,
                                    ),
                                    const SizedBox(height: 10),
                                    _InternshipDistribution(profiles: profiles),
                                  ],
                                );
                                final right = _StudentSummary(
                                  student: selected,
                                  requirements: requirements,
                                  profile: selectedProfile,
                                  dtr: dtr,
                                  onOpen: selected == null
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => Scaffold(
                                              appBar: AppBar(
                                                title: const Text(
                                                  'Student Internship Profile',
                                                ),
                                              ),
                                              body: Padding(
                                                padding: const EdgeInsets.all(
                                                  18,
                                                ),
                                                child:
                                                    StudentInternshipProfileScreen(
                                                      actor: widget.user,
                                                      student: selected,
                                                      repository:
                                                          widget.repository,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                );
                                if (constraints.maxWidth < 1120) {
                                  return Column(
                                    children: [
                                      left,
                                      const SizedBox(height: 10),
                                      middle,
                                      const SizedBox(height: 10),
                                      right,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: left),
                                    const SizedBox(width: 10),
                                    Expanded(flex: 4, child: middle),
                                    const SizedBox(width: 10),
                                    SizedBox(width: 260, child: right),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({
    required this.students,
    required this.requirements,
    required this.profiles,
    required this.moas,
    required this.showMoa,
  });

  final List<AppUser> students;
  final List<RequirementRecord> requirements;
  final List<InternshipProfileRecord> profiles;
  final List<MoaRecord> moas;
  final bool showMoa;

  @override
  Widget build(BuildContext context) {
    final forVerification = requirements
        .where(
          (item) =>
              item.status == ReviewStatus.pending ||
              item.status == ReviewStatus.underReview,
        )
        .length;
    final ongoing = profiles
        .where((item) => item.status.toLowerCase().contains('ongoing'))
        .length;
    final completed = profiles
        .where((item) => item.status.toLowerCase().contains('complete'))
        .length;
    final expiring = moas
        .where((item) => item.status == 'Nearing expiration')
        .length;
    final cards = [
      StatCard(
        label: 'Total Interns',
        value: '${students.length}',
        caption: 'CAS students',
        icon: Icons.groups_outlined,
        color: AppTheme.blue,
      ),
      StatCard(
        label: 'For Verification',
        value: '$forVerification',
        caption: 'submissions',
        icon: Icons.pending_actions_outlined,
        color: AppTheme.purple,
      ),
      StatCard(
        label: 'Ongoing Internship',
        value: '$ongoing',
        caption: 'active interns',
        icon: Icons.timelapse_outlined,
        color: AppTheme.blue,
      ),
      StatCard(
        label: 'Completed',
        value: '$completed',
        caption: 'this school year',
        icon: Icons.verified_outlined,
        color: AppTheme.success,
      ),
      if (showMoa)
        StatCard(
          label: 'MOA Expiring Soon',
          value: '$expiring',
          caption: 'within 90 days',
          icon: Icons.warning_amber_outlined,
          color: AppTheme.warning,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 780
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _RecentSubmissions extends StatelessWidget {
  const _RecentSubmissions({
    required this.requirements,
    required this.onSelect,
    required this.onViewAll,
  });

  final List<RequirementRecord> requirements;
  final ValueChanged<RequirementRecord> onSelect;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final records = requirements.take(8).toList();
    return SectionCard(
      title: 'Recent Student Submissions',
      trailing: TextButton(onPressed: onViewAll, child: const Text('View All')),
      padding: EdgeInsets.zero,
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No submissions yet.'),
            )
          : Column(
              children: [
                Container(
                  height: 31,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: AppTheme.surfaceSoft,
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Student', style: _head)),
                      Expanded(
                        flex: 3,
                        child: Text('Requirement', style: _head),
                      ),
                      Expanded(flex: 2, child: Text('Submitted', style: _head)),
                      Expanded(flex: 2, child: Text('Status', style: _head)),
                      SizedBox(width: 44, child: Text('Action', style: _head)),
                    ],
                  ),
                ),
                ...records.map(
                  (record) => InkWell(
                    onTap: () => onSelect(record),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              record.studentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(flex: 3, child: _cell(record.title)),
                          Expanded(
                            flex: 2,
                            child: _cell(
                              DateFormat.MMMd().format(record.submittedAt),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: StatusBadge(
                                record.status.label,
                                compact: true,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: TextButton(
                              onPressed: () => onSelect(record),
                              child: const Text(
                                'View',
                                style: TextStyle(fontSize: 8.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static const TextStyle _head = TextStyle(
    fontSize: 8.4,
    color: AppTheme.muted,
    fontWeight: FontWeight.w700,
  );

  Widget _cell(String value) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 9),
  );
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.requirements, required this.onViewAll});
  final List<RequirementRecord> requirements;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final records = requirements
        .where(
          (record) =>
              record.status == ReviewStatus.needsRevision ||
              record.status == ReviewStatus.rejected ||
              (record.dueDate?.isBefore(DateTime.now()) ?? false),
        )
        .take(6)
        .toList();
    return SectionCard(
      title: 'Requirements Needing Attention',
      trailing: TextButton(onPressed: onViewAll, child: const Text('View All')),
      child: records.isEmpty
          ? const Text(
              'No urgent requirements.',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            )
          : Column(
              children: records
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.blue.withValues(
                              alpha: .08,
                            ),
                            child: Text(
                              record.studentName.isEmpty
                                  ? '?'
                                  : record.studentName[0],
                              style: const TextStyle(fontSize: 8),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  record.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            shortDate(record.dueDate),
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PartnerStatus extends StatelessWidget {
  const _PartnerStatus({required this.moas, required this.onViewAll});
  final List<MoaRecord> moas;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Partner Institutions & MOA Status',
    trailing: TextButton(onPressed: onViewAll, child: const Text('View All')),
    padding: EdgeInsets.zero,
    child: moas.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(14),
            child: Text('No MOA records.'),
          )
        : Column(
            children: [
              Container(
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTheme.surfaceSoft,
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Institution', style: _head)),
                    Expanded(flex: 2, child: Text('MOA Status', style: _head)),
                    Expanded(flex: 2, child: Text('Expiring', style: _head)),
                    Expanded(flex: 2, child: Text('Valid Until', style: _head)),
                  ],
                ),
              ),
              ...moas
                  .take(6)
                  .map(
                    (record) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              record.partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: StatusBadge(record.status, compact: true),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              record.daysUntilExpiry < 0
                                  ? 'Expired'
                                  : '${record.daysUntilExpiry} days',
                              style: const TextStyle(
                                fontSize: 8.8,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              shortDate(record.endDate),
                              style: const TextStyle(fontSize: 8.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
  );

  static const TextStyle _head = TextStyle(
    fontSize: 8.4,
    color: AppTheme.muted,
    fontWeight: FontWeight.w700,
  );
}

class _DashboardActivity extends StatelessWidget {
  const _DashboardActivity({
    required this.repository,
    required this.actor,
    required this.onViewAll,
  });
  final PracticumRepository repository;
  final AppUser actor;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Recent Activity',
    trailing: TextButton(onPressed: onViewAll, child: const Text('View All')),
    child: StreamBuilder<List<ActivityLogRecord>>(
      stream: repository.watchActivityLogs(actor: actor),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <ActivityLogRecord>[])
            .take(5)
            .toList();
        if (records.isEmpty) {
          return const Text(
            'No recent activity.',
            style: TextStyle(fontSize: 10, color: AppTheme.muted),
          );
        }
        return Column(
          children: records
              .map(
                (record) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.history,
                          size: 13,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.action,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${record.userName} • ${DateFormat.MMMd().format(record.createdAt)}',
                              style: const TextStyle(
                                fontSize: 8.2,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _InternshipDistribution extends StatelessWidget {
  const _InternshipDistribution({required this.profiles});
  final List<InternshipProfileRecord> profiles;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final profile in profiles) {
      counts[profile.status] = (counts[profile.status] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    final colors = [
      AppTheme.blue,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.purple,
      AppTheme.muted,
    ];
    return SectionCard(
      title: 'Internship Status Overview',
      child: profiles.isEmpty
          ? const Text(
              'No internship profiles configured.',
              style: TextStyle(fontSize: 10, color: AppTheme.muted),
            )
          : Row(
              children: [
                SizedBox(
                  width: 105,
                  height: 105,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      values: entries.map((entry) => entry.value).toList(),
                      colors: List.generate(
                        entries.length,
                        (index) => colors[index % colors.length],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${profiles.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Total Interns',
                            style: TextStyle(
                              fontSize: 8.2,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: List.generate(entries.length, (index) {
                      final entry = entries[index];
                      final percent = profiles.isEmpty
                          ? 0
                          : ((entry.value / profiles.length) * 100).round();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 8.8),
                              ),
                            ),
                            Text(
                              '${entry.value} ($percent%)',
                              style: const TextStyle(
                                fontSize: 8.4,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - 5,
    );
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _StudentSummary extends StatefulWidget {
  const _StudentSummary({
    required this.student,
    required this.requirements,
    required this.profile,
    required this.dtr,
    required this.onOpen,
  });

  final AppUser? student;
  final List<RequirementRecord> requirements;
  final InternshipProfileRecord? profile;
  final List<DtrRecord> dtr;
  final VoidCallback? onOpen;

  @override
  State<_StudentSummary> createState() => _StudentSummaryState();
}

class _StudentSummaryState extends State<_StudentSummary> {
  int _tab = 0;

  @override
  void didUpdateWidget(covariant _StudentSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student?.uid != widget.student?.uid) {
      _tab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    if (student == null) {
      return const SectionCard(
        child: Text('Select a student submission to view the record.'),
      );
    }

    final documents = widget.requirements
        .where((record) => record.studentId == student.uid)
        .toList();
    final verified = documents
        .where((record) => record.status == ReviewStatus.verified)
        .length;
    final progress = documents.isEmpty ? 0.0 : verified / documents.length;
    final hours = widget.dtr
        .where(
          (item) =>
              item.studentId == student.uid &&
              item.status == ReviewStatus.verified,
        )
        .fold<double>(0, (sum, item) => sum + item.renderedHours);

    Widget tabContent;
    switch (_tab) {
      case 1:
        tabContent = documents.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No document submissions are available for this student.',
                  style: TextStyle(fontSize: 9.5, color: AppTheme.muted),
                ),
              )
            : Column(
                children: documents
                    .take(8)
                    .map(
                      (record) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              record.status == ReviewStatus.verified
                                  ? Icons.check_circle_outline
                                  : Icons.description_outlined,
                              size: 15,
                              color: record.status == ReviewStatus.verified
                                  ? AppTheme.success
                                  : AppTheme.muted,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                record.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(record.status.label, compact: true),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
        break;
      case 2:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Evaluation ratings and comments are handled in the authorized student profile and evaluation workflow.',
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppTheme.muted,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.onOpen,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open Student Record'),
            ),
          ],
        );
        break;
      default:
        tabContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Internship Details',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            InfoRow(
              'Status',
              widget.profile?.status ?? 'Not configured',
              labelWidth: 74,
            ),
            InfoRow(
              'Placement',
              widget.profile?.companyName.isNotEmpty == true
                  ? widget.profile!.companyName
                  : 'Unassigned',
              labelWidth: 74,
            ),
            InfoRow(
              'Supervisor',
              widget.profile?.supervisorName.isNotEmpty == true
                  ? widget.profile!.supervisorName
                  : '—',
              labelWidth: 74,
            ),
            InfoRow(
              'Start Date',
              shortDate(widget.profile?.startDate),
              labelWidth: 74,
            ),
            InfoRow(
              'End Date',
              shortDate(widget.profile?.endDate),
              labelWidth: 74,
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Requirement Progress',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$verified of ${documents.length} verified',
                  style: const TextStyle(fontSize: 8.5, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.border,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Hours Rendered',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${hours.toStringAsFixed(1)} / ${widget.profile?.requiredHours ?? 400} hours',
              style: const TextStyle(fontSize: 8.8, color: AppTheme.muted),
            ),
          ],
        );
    }

    return SectionCard(
      title: 'Student Record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppTheme.surfaceBlue,
                foregroundColor: AppTheme.deepBlue,
                child: Text(
                  student.displayName.isEmpty ? '?' : student.displayName[0],
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      student.studentNumber ?? '',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                widget.profile?.status ?? 'Not configured',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 7),
          WorkspaceTabs(
            labels: const ['Overview', 'Documents', 'Evaluation'],
            selectedIndex: _tab,
            onSelected: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 9),
          tabContent,
          if (_tab != 2) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: widget.onOpen,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View Full Record'),
            ),
          ],
        ],
      ),
    );
  }
}
