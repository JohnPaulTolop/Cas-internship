import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
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

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: widget.repository.watchUsers(role: UserRole.student),
    builder: (context, userSnapshot) {
      final allStudents = userSnapshot.data ?? const <AppUser>[];
      final programs = {
        'All Programs',
        ...allStudents.map((student) => student.program).whereType<String>(),
      }.toList();
      final students = _program == 'All Programs'
          ? allStudents
          : allStudents
                .where((student) => student.program == _program)
                .toList();
      return StreamBuilder<List<RequirementRecord>>(
        stream: widget.repository.watchRequirements(widget.user),
        builder: (context, requirementSnapshot) {
          final requirements =
              requirementSnapshot.data ?? const <RequirementRecord>[];
          return StreamBuilder<List<MoaRecord>>(
            stream: widget.repository.watchMoas(),
            builder: (context, moaSnapshot) {
              final moas = moaSnapshot.data ?? const <MoaRecord>[];
              return StreamBuilder<List<InternshipProfileRecord>>(
                stream: widget.repository.watchInternshipProfiles(),
                builder: (context, profileSnapshot) {
                  final profiles =
                      profileSnapshot.data ?? const <InternshipProfileRecord>[];
                  return WorkflowPage(
                    title: 'Coordinator Dashboard',
                    subtitle:
                        'Monitor internship activity, documents, and partnerships.',
                    actions: [
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          initialValue: programs.contains(_program)
                              ? _program
                              : 'All Programs',
                          decoration: const InputDecoration(
                            labelText: 'Program',
                            isDense: true,
                          ),
                          items: programs
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
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
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1050;
                            final left = Column(
                              children: [
                                _RecentSubmissions(
                                  requirements: requirements,
                                  onSelect: (record) {
                                    final match = allStudents.where(
                                      (student) =>
                                          student.uid == record.studentId,
                                    );
                                    if (match.isNotEmpty)
                                      setState(
                                        () => _selectedStudent = match.first,
                                      );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _PartnerStatus(moas: moas),
                              ],
                            );
                            final middle = Column(
                              children: [
                                _NeedsAttention(requirements: requirements),
                                const SizedBox(height: 14),
                                _DashboardActivity(
                                  repository: widget.repository,
                                ),
                                const SizedBox(height: 14),
                                _InternshipDistribution(profiles: profiles),
                              ],
                            );
                            final selected =
                                _selectedStudent ??
                                (students.isEmpty ? null : students.first);
                            final right = _StudentSummary(
                              student: selected,
                              requirements: requirements,
                              profile: selected == null
                                  ? null
                                  : profiles
                                        .where(
                                          (profile) =>
                                              profile.studentId == selected.uid,
                                        )
                                        .firstOrNull,
                              onOpen: selected == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => Scaffold(
                                          appBar: AppBar(
                                            title: const Text(
                                              'Student Profile',
                                            ),
                                          ),
                                          body: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child:
                                                StudentInternshipProfileScreen(
                                                  actor: widget.user,
                                                  student: selected,
                                                  repository: widget.repository,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                            if (!wide)
                              return Column(
                                children: [
                                  left,
                                  const SizedBox(height: 14),
                                  middle,
                                  const SizedBox(height: 14),
                                  right,
                                ],
                              );
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: left),
                                const SizedBox(width: 14),
                                Expanded(flex: 4, child: middle),
                                const SizedBox(width: 14),
                                Expanded(flex: 3, child: right),
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
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({
    required this.students,
    required this.requirements,
    required this.profiles,
    required this.moas,
  });
  final List<AppUser> students;
  final List<RequirementRecord> requirements;
  final List<InternshipProfileRecord> profiles;
  final List<MoaRecord> moas;

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
        .where((item) => item.status == 'Ongoing Internship')
        .length;
    final completed = profiles
        .where((item) => item.status == 'Completed')
        .length;
    final expiring = moas
        .where((item) => item.status == 'Nearing expiration')
        .length;
    final cards = [
      StatCard(
        label: 'Total interns',
        value: '${students.length}',
        icon: Icons.groups_outlined,
        color: AppTheme.blue,
      ),
      StatCard(
        label: 'For verification',
        value: '$forVerification',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFF6C63FF),
      ),
      StatCard(
        label: 'Ongoing internship',
        value: '$ongoing',
        icon: Icons.timelapse_outlined,
        color: const Color(0xFF2584D8),
      ),
      StatCard(
        label: 'Completed',
        value: '$completed',
        icon: Icons.verified_outlined,
        color: const Color(0xFF159A61),
      ),
      StatCard(
        label: 'MOA expiring soon',
        value: '$expiring',
        icon: Icons.warning_amber_outlined,
        color: const Color(0xFFE4931A),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 1100
            ? (constraints.maxWidth - 56) / 5
            : constraints.maxWidth >= 650
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
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
  });
  final List<RequirementRecord> requirements;
  final ValueChanged<RequirementRecord> onSelect;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Recent Student Submissions',
    child: requirements.isEmpty
        ? const Text('No submissions yet.')
        : Column(
            children: requirements
                .take(8)
                .map(
                  (record) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      record.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${record.title} • ${DateFormat.MMMd().format(record.submittedAt)}',
                    ),
                    trailing: StatusBadge(record.status.label),
                    onTap: () => onSelect(record),
                  ),
                )
                .toList(),
          ),
  );
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.requirements});
  final List<RequirementRecord> requirements;

  @override
  Widget build(BuildContext context) {
    final records = requirements
        .where(
          (record) =>
              record.status == ReviewStatus.needsRevision ||
              record.status == ReviewStatus.rejected ||
              (record.dueDate?.isBefore(DateTime.now()) ?? false),
        )
        .take(7)
        .toList();
    return SectionCard(
      title: 'Requirements Needing Attention',
      child: records.isEmpty
          ? const Text('No urgent requirements.')
          : Column(
              children: records
                  .map(
                    (record) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(record.studentName),
                      subtitle: Text(record.title),
                      trailing: Text(
                        shortDate(record.dueDate),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PartnerStatus extends StatelessWidget {
  const _PartnerStatus({required this.moas});
  final List<MoaRecord> moas;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Partner Institutions & MOA Status',
    child: moas.isEmpty
        ? const Text('No MOA records.')
        : Column(
            children: moas
                .take(6)
                .map(
                  (record) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: Text(record.partnerName),
                    subtitle: Text(
                      '${record.moaNumber} • Valid until ${shortDate(record.endDate)}',
                    ),
                    trailing: StatusBadge(record.status),
                  ),
                )
                .toList(),
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
    return SectionCard(
      title: 'Internship Status Overview',
      child: counts.isEmpty
          ? const Text('No internship profiles configured.')
          : Column(
              children: counts.entries.map((entry) {
                final value = profiles.isEmpty
                    ? 0.0
                    : entry.value / profiles.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text('${entry.value}'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _DashboardActivity extends StatelessWidget {
  const _DashboardActivity({required this.repository});
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Recent Activity',
    child: StreamBuilder<List<ActivityLogRecord>>(
      stream: repository.watchActivityLogs(),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <ActivityLogRecord>[])
            .take(6)
            .toList();
        if (records.isEmpty) {
          return const Text('No recent activity.');
        }
        return Column(
          children: records
              .map(
                (record) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 19),
                  title: Text(
                    record.action,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(record.userName),
                  trailing: Text(
                    DateFormat.MMMd().format(record.createdAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _StudentSummary extends StatelessWidget {
  const _StudentSummary({
    required this.student,
    required this.requirements,
    required this.profile,
    required this.onOpen,
  });
  final AppUser? student;
  final List<RequirementRecord> requirements;
  final InternshipProfileRecord? profile;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (student == null) {
      return const SectionCard(
        child: Text('Select a student submission to view the record.'),
      );
    }
    final documents = requirements
        .where((record) => record.studentId == student!.uid)
        .toList();
    final verified = documents
        .where((record) => record.status == ReviewStatus.verified)
        .length;
    final progress = documents.isEmpty ? 0.0 : verified / documents.length;
    return SectionCard(
      title: 'Student Record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 30,
            child: Text(
              student!.displayName.isEmpty ? '?' : student!.displayName[0],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            student!.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(student!.studentNumber ?? '', textAlign: TextAlign.center),
          const Divider(height: 28),
          _row('Status', profile?.status ?? 'Not configured'),
          _row('Program', student!.program ?? 'Not set'),
          _row(
            'Placement',
            profile?.companyName.isNotEmpty == true
                ? profile!.companyName
                : 'Unassigned',
          ),
          const SizedBox(height: 14),
          Text('Requirement progress: $verified/${documents.length}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('View full record'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
