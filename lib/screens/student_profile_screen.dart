import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
import 'advanced_reports_screen.dart';
import 'document_workflow_screens.dart';
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
      stream: widget.repository.watchStudentsFor(widget.actor),
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

class StudentInternshipProfileScreen extends StatefulWidget {
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
  State<StudentInternshipProfileScreen> createState() =>
      _StudentInternshipProfileScreenState();
}

class _StudentInternshipProfileScreenState
    extends State<StudentInternshipProfileScreen> {
  int _selectedTab = 0;

  AppUser get actor => widget.actor;
  AppUser get student => widget.student;
  PracticumRepository get repository => widget.repository;

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
                  if (actor.role == UserRole.admin)
                    FilledButton.icon(
                      onPressed: () => _showCoordinatorAssignment(context),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(
                        student.coordinatorId == null
                            ? 'Assign Program Coordinator'
                            : 'Change Program Coordinator',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _editProfile(context, profile),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Update profile'),
                  ),
                ],
                child: ListView(
                  children: [
                    _ProfileHeader(
                      student: student,
                      profile: profile,
                      selectedTab: _selectedTab,
                      onTabSelected: (index) {
                        if (_selectedTab != index) {
                          setState(() => _selectedTab = index);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedTab),
                        child: switch (_selectedTab) {
                          0 => LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 920;

                              final main = Column(
                                children: [
                                  _InternshipDetails(
                                    profile: profile,
                                    coordinatorName: student.coordinatorName,
                                  ),
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
                                    actor: actor,
                                    student: student,
                                    repository: repository,
                                    onEdit: () =>
                                        _editProfile(context, profile),
                                    onAssignCoordinator:
                                        actor.role == UserRole.admin
                                        ? () => _showCoordinatorAssignment(
                                            context,
                                          )
                                        : null,
                                    onRemoveCoordinator:
                                        actor.role == UserRole.admin &&
                                            student.coordinatorId != null
                                        ? () => _removeCoordinatorAssignment(
                                            context,
                                          )
                                        : null,
                                  ),
                                ],
                              );

                              if (!wide) {
                                return Column(
                                  children: [
                                    main,
                                    const SizedBox(height: 14),
                                    side,
                                  ],
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

                          1 => _DocumentsTab(records: requirements),

                          2 => _EvaluationTab(
                            actor: actor,
                            student: student,
                            repository: repository,
                          ),

                          3 => _AttendanceTab(
                            records: dtr,
                            completedHours: hours,
                            requiredHours: profile.requiredHours,
                          ),

                          4 => _RemarksTab(remarks: profile.coordinatorRemarks),

                          _ => const SizedBox.shrink(),
                        },
                      ),
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

  Future<void> _showCoordinatorAssignment(BuildContext context) async {
    if (actor.role != UserRole.admin) return;

    final coordinators =
        (await repository.watchUsers(role: UserRole.coordinator).first)
            .where(
              (coordinator) =>
                  coordinator.active && coordinator.isApprovedCoordinator,
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    if (!context.mounted) return;
    if (coordinators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No approved Program Coordinator accounts are available yet.',
          ),
        ),
      );
      return;
    }

    AppUser selected = coordinators.firstWhere(
      (item) => item.uid == student.coordinatorId,
      orElse: () => coordinators.first,
    );

    final assigned = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            student.coordinatorId == null
                ? 'Assign Program Coordinator'
                : 'Change Program Coordinator',
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign ${student.displayName} to an approved Program Coordinator.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AppUser>(
                  isExpanded: true,
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Program Coordinator',
                    prefixIcon: Icon(Icons.supervisor_account_outlined),
                  ),
                  items: coordinators
                      .map(
                        (coordinator) => DropdownMenuItem<AppUser>(
                          value: coordinator,
                          child: Text(
                            coordinator.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await repository.assignStudent(
                    actor: actor,
                    student: student,
                    coordinator: selected,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (assigned == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${student.displayName} was assigned to ${selected.displayName}.',
          ),
        ),
      );
    }
  }

  Future<void> _removeCoordinatorAssignment(BuildContext context) async {
    if (actor.role != UserRole.admin || student.coordinatorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Program Coordinator?'),
        content: Text(
          'Remove the current Program Coordinator assignment from ${student.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repository.assignStudent(
        actor: actor,
        student: student,
        coordinator: null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Program Coordinator assignment removed.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

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
    final status = profile.status;
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
                  SizedBox(
                    width: 314,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'System internship stage',
                        helperText:
                            'Updated automatically from requirements, deployment, DTR hours, and evaluation.',
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
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
      isExpanded: true,
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
  const _ProfileHeader({
    required this.student,
    required this.profile,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final AppUser student;
  final InternshipProfileRecord profile;
  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.border,
                foregroundColor: AppTheme.muted,
                child: Text(
                  student.displayName.isEmpty
                      ? '?'
                      : student.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Student ID\n${student.studentNumber ?? 'Not set'}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9.3,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _HeaderValue('Program', student.program ?? 'Not set'),
              ),
              Expanded(
                flex: 2,
                child: _HeaderValue(
                  'Year Level',
                  student.yearLevel ?? 'Not set',
                ),
              ),
              Expanded(flex: 2, child: _HeaderValue('Email', student.email)),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Internship Status',
                      style: TextStyle(fontSize: 8.8, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 3),
                    StatusBadge(profile.status, compact: true),
                    const SizedBox(height: 7),
                    const Text(
                      'Placement',
                      style: TextStyle(fontSize: 8.8, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.companyName.isEmpty
                          ? profile.placementStatus
                          : profile.companyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ProfileTabs(
              selectedIndex: selectedTab,
              onSelected: onTabSelected,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labels = [
    'Overview',
    'Documents',
    'Evaluation',
    'Attendance',
    'Remarks',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _labels.length,
        (index) => _ProfileTab(
          _labels[index],
          active: selectedIndex == index,
          onTap: () => onSelected(index),
        ),
      ),
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab(this.label, {required this.onTap, this.active = false});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? AppTheme.blue : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.blue : AppTheme.muted,
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.records});

  final List<RequirementRecord> records;

  @override
  Widget build(BuildContext context) => _RequiredDocuments(records: records);
}

class _EvaluationTab extends StatelessWidget {
  const _EvaluationTab({
    required this.actor,
    required this.student,
    required this.repository,
  });

  final AppUser actor;
  final AppUser student;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) {
    if (!actor.role.isStaff) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Supervisor evaluation details are available only to authorized staff.',
          ),
        ),
      );
    }

    return StreamBuilder<List<SupervisorEvaluationRecord>>(
      stream: repository.watchEvaluationsFor(actor),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('${snapshot.error}'),
            ),
          );
        }

        final evaluations =
            (snapshot.data ?? const <SupervisorEvaluationRecord>[])
                .where((item) => item.studentId == student.uid)
                .toList();

        if (evaluations.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: EmptyWorkflowState(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No supervisor evaluation yet',
                message:
                    'Supervisor evaluation records for this intern will appear here.',
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supervisor Evaluation',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '${evaluations.length} evaluation record'
                  '${evaluations.length == 1 ? '' : 's'} found.',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Open Supervisor Evaluations for the complete confidential evaluation details.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({
    required this.records,
    required this.completedHours,
    required this.requiredHours,
  });

  final List<DtrRecord> records;
  final double completedHours;
  final int requiredHours;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ProgressCard(
        completedHours: completedHours,
        requiredHours: requiredHours,
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: records.isEmpty
              ? const EmptyWorkflowState(
                  icon: Icons.punch_clock_outlined,
                  title: 'No attendance records',
                  message:
                      'Daily Time Record entries for this intern will appear here.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Attendance / DTR Records',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Time In')),
                          DataColumn(label: Text('Time Out')),
                          DataColumn(label: Text('Hours')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Remarks')),
                        ],
                        rows: records
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(DateFormat.yMMMd().format(item.date)),
                                  ),
                                  DataCell(
                                    Text(DateFormat.jm().format(item.timeIn)),
                                  ),
                                  DataCell(
                                    Text(DateFormat.jm().format(item.timeOut)),
                                  ),
                                  DataCell(
                                    Text(item.renderedHours.toStringAsFixed(2)),
                                  ),
                                  DataCell(Text(item.status.label)),
                                  DataCell(Text(item.remarks ?? '—')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

class _RemarksTab extends StatelessWidget {
  const _RemarksTab({required this.remarks});

  final String remarks;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coordinator Remarks',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  remarks.trim().isEmpty
                      ? 'No coordinator remarks have been added yet.'
                      : remarks,
                  style: const TextStyle(color: AppTheme.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeaderValue extends StatelessWidget {
  const _HeaderValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 8.8, color: AppTheme.muted)),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.4,
          color: AppTheme.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _InternshipDetails extends StatelessWidget {
  const _InternshipDetails({required this.profile, this.coordinatorName});
  final InternshipProfileRecord profile;

  final String? coordinatorName;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Internship Details',
    child: Column(
      children: [
        InfoRow('Company', profile.companyName, labelWidth: 105),
        InfoRow('Department', profile.department, labelWidth: 105),
        InfoRow('Position', profile.position, labelWidth: 105),
        InfoRow('Start Date', shortDate(profile.startDate), labelWidth: 105),
        InfoRow('End Date', shortDate(profile.endDate), labelWidth: 105),
        InfoRow('Required Hours', '${profile.requiredHours}', labelWidth: 105),
        InfoRow(
          'Completed Hours',
          'Calculated from verified DTR',
          labelWidth: 105,
        ),
        InfoRow(
          'Program Coordinator',
          coordinatorName ?? 'Unassigned',
          labelWidth: 105,
        ),
        InfoRow('Company Supervisor', profile.supervisorName, labelWidth: 105),
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
      title: 'Progress',
      trailing: Text(
        '${(progress * 100).round()}%',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.border,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Completed Hours: ${completedHours.toStringAsFixed(1)} / $requiredHours',
            style: const TextStyle(fontSize: 9.4, color: AppTheme.muted),
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
        ? const Text(
            'No submissions yet.',
            style: TextStyle(fontSize: 10, color: AppTheme.muted),
          )
        : Column(
            children: records.take(8).map((record) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.3),
                      ),
                    ),
                    StatusBadge(record.status.label, compact: true),
                  ],
                ),
              );
            }).toList(),
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
          return const Text(
            'No recent activity.',
            style: TextStyle(fontSize: 10, color: AppTheme.muted),
          );
        }
        return Column(
          children: records.map((record) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 15, color: AppTheme.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.3),
                    ),
                  ),
                  Text(
                    DateFormat.MMMd().format(record.createdAt),
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.profile,

    required this.actor,
    required this.student,
    required this.repository,
    required this.onEdit,
    this.onAssignCoordinator,
    this.onRemoveCoordinator,
  });

  final InternshipProfileRecord profile;

  final AppUser actor;
  final AppUser student;
  final PracticumRepository repository;
  final VoidCallback onEdit;
  final VoidCallback? onAssignCoordinator;
  final VoidCallback? onRemoveCoordinator;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Quick Actions',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onAssignCoordinator != null) ...[
          FilledButton.icon(
            onPressed: onAssignCoordinator,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
            label: Text(
              student.coordinatorId == null
                  ? 'Assign Program Coordinator'
                  : 'Change Program Coordinator',
            ),
          ),
          const SizedBox(height: 7),
        ],
        if (onRemoveCoordinator != null) ...[
          OutlinedButton.icon(
            onPressed: onRemoveCoordinator,
            icon: const Icon(Icons.person_remove_outlined, size: 15),
            label: const Text('Remove Coordinator Assignment'),
          ),
          const SizedBox(height: 7),
        ],
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Document Repository')),
                body: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DocumentRepositoryScreen(
                    user: actor,
                    repository: repository,
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.description_outlined, size: 15),
          label: const Text('View All Documents'),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Evaluations & Reports')),
                body: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AdvancedReportsScreen(
                    user: actor,
                    repository: repository,
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.assignment_turned_in_outlined, size: 15),
          label: const Text('View Evaluation'),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Update Placement / Internship Details'),
        ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Student Report')),
                body: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AdvancedReportsScreen(
                    user: actor,
                    repository: repository,
                  ),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.summarize_outlined, size: 15),
          label: const Text('Generate Student Report'),
        ),
        if (profile.coordinatorRemarks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Remarks',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            profile.coordinatorRemarks,
            style: const TextStyle(fontSize: 9.3, color: AppTheme.muted),
          ),
        ],
      ],
    ),
  );
}
