import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
import 'workflow_shared.dart';

class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({
    super.key,
    required this.actor,
    required this.repository,
  });

  final AppUser actor;
  final PracticumRepository repository;

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Student Internship Records',
    subtitle: 'Open a student profile to monitor placement and progress.',
    child: StreamBuilder<List<AppUser>>(
      stream: widget.repository.watchUsers(role: UserRole.student),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        final students = (snapshot.data ?? const <AppUser>[])
            .where(
              (student) =>
                  _query.isEmpty ||
                  '${student.displayName} ${student.studentNumber} ${student.program}'
                      .toLowerCase()
                      .contains(_query),
            )
            .toList();
        return Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search student, number, or program',
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: students.isEmpty
                  ? const EmptyWorkflowState(
                      icon: Icons.groups_outlined,
                      title: 'No student records found',
                      message: 'Registered student accounts appear here.',
                    )
                  : ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              child: Text(_initials(student.displayName)),
                            ),
                            title: Text(
                              student.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${student.studentNumber ?? 'No student number'} • '
                              '${student.program ?? 'Program not set'}\n'
                              'Coordinator: ${student.coordinatorName ?? 'Unassigned'}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Student Profile'),
                                  ),
                                  body: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: StudentInternshipProfileScreen(
                                      actor: widget.actor,
                                      student: student,
                                      repository: widget.repository,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );

  String _initials(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
      .join();
}

class StudentInternshipProfileScreen extends StatelessWidget {
  const StudentInternshipProfileScreen({
    super.key,
    required this.actor,
    required this.student,
    required this.repository,
  });

  final AppUser actor;
  final AppUser student;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => StreamBuilder<InternshipProfileRecord?>(
    stream: repository.watchInternshipProfile(student.uid),
    builder: (context, profileSnapshot) {
      final profile =
          profileSnapshot.data ??
          InternshipProfileRecord(studentId: student.uid);
      return StreamBuilder<List<RequirementRecord>>(
        stream: repository.watchRequirements(actor),
        builder: (context, requirementSnapshot) {
          final requirements =
              (requirementSnapshot.data ?? const <RequirementRecord>[])
                  .where((item) => item.studentId == student.uid)
                  .toList();
          return StreamBuilder<List<DtrRecord>>(
            stream: repository.watchDtr(actor),
            builder: (context, dtrSnapshot) {
              final dtr = (dtrSnapshot.data ?? const <DtrRecord>[])
                  .where((item) => item.studentId == student.uid)
                  .toList();
              final hours = dtr
                  .where((item) => item.status == ReviewStatus.verified)
                  .fold<double>(0, (total, item) => total + item.renderedHours);
              return WorkflowPage(
                title: 'Student Internship Profile',
                subtitle: 'Consolidated internship and requirement record.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _editProfile(context, profile),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Update profile'),
                  ),
                ],
                child: ListView(
                  children: [
                    _ProfileHeader(student: student, profile: profile),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 920;
                        final main = Column(
                          children: [
                            _InternshipDetails(profile: profile),
                            const SizedBox(height: 14),
                            _ProgressCard(
                              completedHours: hours,
                              requiredHours: profile.requiredHours,
                            ),
                            const SizedBox(height: 14),
                            _RecentActivity(
                              student: student,
                              repository: repository,
                            ),
                          ],
                        );
                        final side = Column(
                          children: [
                            _RequiredDocuments(records: requirements),
                            const SizedBox(height: 14),
                            _QuickActions(
                              profile: profile,
                              onEdit: () => _editProfile(context, profile),
                            ),
                          ],
                        );
                        if (!wide) {
                          return Column(
                            children: [main, const SizedBox(height: 14), side],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: main),
                            const SizedBox(width: 14),
                            Expanded(child: side),
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

  Future<void> _editProfile(
    BuildContext context,
    InternshipProfileRecord profile,
  ) async {
    final program = TextEditingController(text: student.program);
    final yearLevel = TextEditingController(text: student.yearLevel);
    final academicYear = TextEditingController(text: student.academicYear);
    final company = TextEditingController(text: profile.companyName);
    final department = TextEditingController(text: profile.department);
    final position = TextEditingController(text: profile.position);
    final requiredHours = TextEditingController(
      text: '${profile.requiredHours}',
    );
    final supervisor = TextEditingController(text: profile.supervisorName);
    final supervisorEmail = TextEditingController(
      text: profile.supervisorEmail,
    );
    final supervisorPhone = TextEditingController(
      text: profile.supervisorPhone,
    );
    final remarks = TextEditingController(text: profile.coordinatorRemarks);
    var status = profile.status;
    var placementStatus = profile.placementStatus;
    var startDate = profile.startDate;
    var endDate = profile.endDate;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update ${student.displayName}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(program, 'Program'),
                  _field(yearLevel, 'Year level'),
                  _field(academicYear, 'Academic year'),
                  _dropdown('Internship status', status, const [
                    'Pending Requirements',
                    'For Verification',
                    'Ready for Deployment',
                    'Ongoing Internship',
                    'Completed',
                  ], (value) => setDialogState(() => status = value)),
                  _dropdown('Placement status', placementStatus, const [
                    'Unassigned',
                    'Processing',
                    'Confirmed',
                    'Deployed',
                  ], (value) => setDialogState(() => placementStatus = value)),
                  _field(company, 'Company / institution'),
                  _field(department, 'Department'),
                  _field(position, 'Position'),
                  _field(requiredHours, 'Required hours', number: true),
                  _dateButton(context, 'Start date', startDate, (value) {
                    setDialogState(() => startDate = value);
                  }),
                  _dateButton(context, 'End date', endDate, (value) {
                    setDialogState(() => endDate = value);
                  }),
                  _field(supervisor, 'Supervisor name'),
                  _field(supervisorEmail, 'Supervisor email'),
                  _field(supervisorPhone, 'Supervisor phone'),
                  SizedBox(
                    width: 640,
                    child: TextField(
                      controller: remarks,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Coordinator remarks',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final parsedHours = int.tryParse(requiredHours.text) ?? 400;
                await repository.saveInternshipProfile(
                  actor: actor,
                  student: student,
                  program: program.text,
                  yearLevel: yearLevel.text,
                  academicYear: academicYear.text,
                  profile: InternshipProfileRecord(
                    studentId: student.uid,
                    status: status,
                    placementStatus: placementStatus,
                    companyName: company.text,
                    department: department.text,
                    position: position.text,
                    startDate: startDate,
                    endDate: endDate,
                    requiredHours: parsedHours,
                    supervisorName: supervisor.text,
                    supervisorEmail: supervisorEmail.text,
                    supervisorPhone: supervisorPhone.text,
                    coordinatorRemarks: remarks.text,
                  ),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      program,
      yearLevel,
      academicYear,
      company,
      department,
      position,
      requiredHours,
      supervisor,
      supervisorEmail,
      supervisorPhone,
      remarks,
    ]) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) => SizedBox(
    width: 310,
    child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 310,
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (item) {
        if (item != null) {
          onChanged(item);
        }
      },
    ),
  );

  Widget _dateButton(
    BuildContext context,
    String label,
    DateTime? value,
    ValueChanged<DateTime> onChanged,
  ) => SizedBox(
    width: 310,
    child: OutlinedButton.icon(
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('$label: ${shortDate(value)}'),
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          initialDate: value ?? DateTime.now(),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student, required this.profile});
  final AppUser student;
  final InternshipProfileRecord profile;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Wrap(
      spacing: 18,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CircleAvatar(
          radius: 34,
          child: Text(
            student.displayName.isEmpty ? '?' : student.displayName[0],
          ),
        ),
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(student.studentNumber ?? 'No student number'),
              Text(student.email),
            ],
          ),
        ),
        _HeaderValue('Program', student.program ?? 'Not set'),
        _HeaderValue('Year level', student.yearLevel ?? 'Not set'),
        _HeaderValue('Academic year', student.academicYear ?? 'Not set'),
        _HeaderValue('Internship status', profile.status, badge: true),
        _HeaderValue('Placement', profile.placementStatus, badge: true),
      ],
    ),
  );
}

class _HeaderValue extends StatelessWidget {
  const _HeaderValue(this.label, this.value, {this.badge = false});
  final String label;
  final String value;
  final bool badge;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        badge
            ? StatusBadge(value)
            : Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _InternshipDetails extends StatelessWidget {
  const _InternshipDetails({required this.profile});
  final InternshipProfileRecord profile;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Internship Details',
    child: Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _detail('Company', profile.companyName),
        _detail('Department', profile.department),
        _detail('Position', profile.position),
        _detail('Start date', shortDate(profile.startDate)),
        _detail('End date', shortDate(profile.endDate)),
        _detail('Required hours', '${profile.requiredHours}'),
        _detail('Supervisor', profile.supervisorName),
        _detail('Supervisor email', profile.supervisorEmail),
      ],
    ),
  );

  Widget _detail(String label, String value) => SizedBox(
    width: 220,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completedHours,
    required this.requiredHours,
  });
  final double completedHours;
  final int requiredHours;

  @override
  Widget build(BuildContext context) {
    final progress = requiredHours <= 0
        ? 0.0
        : (completedHours / requiredHours).clamp(0, 1).toDouble();
    return SectionCard(
      title: 'Internship Progress',
      trailing: Text(
        '${(progress * 100).round()}%',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            '${completedHours.toStringAsFixed(1)} of $requiredHours verified hours',
          ),
        ],
      ),
    );
  }
}

class _RequiredDocuments extends StatelessWidget {
  const _RequiredDocuments({required this.records});
  final List<RequirementRecord> records;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Required Documents',
    child: records.isEmpty
        ? const Text('No submissions yet.')
        : Column(
            children: records
                .take(8)
                .map(
                  (record) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, size: 20),
                    title: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: StatusBadge(record.status.label),
                  ),
                )
                .toList(),
          ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.student, required this.repository});
  final AppUser student;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Recent Activity',
    child: StreamBuilder<List<ActivityLogRecord>>(
      stream: repository.watchActivityLogs(),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <ActivityLogRecord>[])
            .where(
              (record) =>
                  record.userId == student.uid ||
                  record.action.contains(student.displayName),
            )
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
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(record.action),
                  trailing: Text(DateFormat.MMMd().format(record.createdAt)),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile, required this.onEdit});
  final InternshipProfileRecord profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Quick Actions',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Update internship status'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.business_outlined),
          label: const Text('Update placement'),
        ),
        if (profile.coordinatorRemarks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Remarks', style: Theme.of(context).textTheme.labelLarge),
          Text(profile.coordinatorRemarks),
        ],
      ],
    ),
  );
}
