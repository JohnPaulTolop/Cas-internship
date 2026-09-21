import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';

import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';

class TorScreen extends StatelessWidget {
  const TorScreen({super.key, required this.user, required this.repository});

  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => _ModulePage(
    title: 'Transcript of Records',
    subtitle: 'Live TOR submissions from the requirements collection.',
    child: StreamBuilder<List<RequirementRecord>>(
      stream: repository.watchRequirements(user),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Error(error: snapshot.error!);
        final records = (snapshot.data ?? const <RequirementRecord>[]).where((
          record,
        ) {
          final title = record.title.toLowerCase();
          return title.contains('tor') ||
              title.contains('transcript of records');
        }).toList();
        if (records.isEmpty) {
          return const _Empty(
            icon: Icons.school_outlined,
            title: 'No TOR submissions',
            message:
                'TOR documents submitted through Requirements appear here.',
          );
        }
        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = records[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const CircleAvatar(
                  child: Icon(Icons.description_outlined),
                ),
                title: Text(item.studentName),
                subtitle: Text(
                  '${item.fileName ?? item.title}\n'
                  '${DateFormat.yMMMd().format(item.submittedAt)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(label: Text(item.status.label)),
                    IconButton(
                      tooltip: 'Copy secure file link',
                      onPressed: item.storagePath == null
                          ? null
                          : () => _copyDownloadLink(
                              context,
                              repository,
                              item.storagePath!,
                            ),
                      icon: const Icon(Icons.link),
                    ),
                    IconButton(
                      tooltip: 'Review TOR',
                      onPressed: () =>
                          _reviewRequirement(context, repository, user, item),
                      icon: const Icon(Icons.rate_review_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class HoursScreen extends StatelessWidget {
  const HoursScreen({super.key, required this.user, required this.repository});

  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => _ModulePage(
    title: 'Rendered hours',
    subtitle: 'Live totals calculated from submitted DTR entries.',
    child: StreamBuilder<List<DtrRecord>>(
      stream: repository.watchDtr(user),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Error(error: snapshot.error!);
        final records = snapshot.data ?? const <DtrRecord>[];
        if (records.isEmpty) {
          return const _Empty(
            icon: Icons.timelapse_outlined,
            title: 'No rendered hours yet',
            message: 'Totals appear after DTR records are added.',
          );
        }
        final now = DateTime.now();
        final totals = <String, ({String name, double all, double month})>{};
        for (final item in records) {
          final old = totals[item.studentId];
          final inMonth =
              item.date.year == now.year && item.date.month == now.month;
          totals[item.studentId] = (
            name: item.studentName,
            all: (old?.all ?? 0) + item.renderedHours,
            month: (old?.month ?? 0) + (inMonth ? item.renderedHours : 0),
          );
        }
        final rows = totals.entries.toList()
          ..sort((a, b) => a.value.name.compareTo(b.value.name));
        return Card(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('This month')),
                  DataColumn(label: Text('All hours')),
                ],
                rows: rows
                    .map(
                      (entry) => DataRow(
                        cells: [
                          DataCell(Text(entry.value.name)),
                          DataCell(Text(entry.value.month.toStringAsFixed(2))),
                          DataCell(Text(entry.value.all.toStringAsFixed(2))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class MoaScreen extends StatelessWidget {
  const MoaScreen({super.key, required this.user, required this.repository});

  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => _ModulePage(
    title: 'MOA management',
    subtitle: 'Partner agreements, validity dates, and expiry monitoring.',
    action: FilledButton.icon(
      onPressed: () => _showCreateDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Add MOA'),
    ),
    child: StreamBuilder<List<MoaRecord>>(
      stream: repository.watchMoas(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Error(error: snapshot.error!);
        final records = snapshot.data ?? const <MoaRecord>[];
        if (records.isEmpty) {
          return const _Empty(
            icon: Icons.handshake_outlined,
            title: 'No MOA records',
            message: 'Add the first partner agreement to begin tracking.',
          );
        }
        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = records[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const CircleAvatar(
                  child: Icon(Icons.business_outlined),
                ),
                title: Text(item.partnerName),
                subtitle: Text(
                  '${item.moaNumber}\n'
                  '${DateFormat.yMMMd().format(item.startDate)} – '
                  '${DateFormat.yMMMd().format(item.endDate)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(item.isExpired ? 'Expired' : 'Active'),
                      backgroundColor:
                          (item.isExpired ? Colors.red : Colors.green)
                              .withValues(alpha: 0.10),
                    ),
                    IconButton(
                      tooltip: 'Copy secure file link',
                      onPressed: item.storagePath == null
                          ? null
                          : () => _copyDownloadLink(
                              context,
                              repository,
                              item.storagePath!,
                            ),
                      icon: const Icon(Icons.link),
                    ),
                    IconButton(
                      tooltip: 'Renew MOA',
                      onPressed: () => _showRenewDialog(context, item),
                      icon: const Icon(Icons.event_repeat_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _showCreateDialog(BuildContext context) async {
    final partner = TextEditingController();
    final number = TextEditingController();
    PlatformFile? selectedFile;
    var startDate = DateTime.now();
    var endDate = DateTime.now().add(const Duration(days: 365));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add MOA record'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: partner,
                  decoration: const InputDecoration(
                    labelText: 'Partner institution',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: number,
                  decoration: const InputDecoration(labelText: 'MOA number'),
                ),
                const SizedBox(height: 12),
                _DateTile(
                  label: 'Start date',
                  date: startDate,
                  onChanged: (value) => setDialogState(() => startDate = value),
                ),
                _DateTile(
                  label: 'Expiry date',
                  date: endDate,
                  onChanged: (value) => setDialogState(() => endDate = value),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx'],
                    );
                    if (file != null) {
                      setDialogState(() => selectedFile = file);
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(selectedFile?.name ?? 'Choose MOA document'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (selectedFile == null) {
                    throw ArgumentError('Choose the MOA document first.');
                  }
                  await repository.addMoa(
                    actor: user,
                    partnerName: partner.text,
                    moaNumber: number.text,
                    startDate: startDate,
                    endDate: endDate,
                    file: selectedFile!,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    partner.dispose();
    number.dispose();
  }

  Future<void> _showRenewDialog(BuildContext context, MoaRecord record) async {
    var endDate = record.endDate.isAfter(DateTime.now())
        ? record.endDate.add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 365));
    PlatformFile? replacementFile;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Renew ${record.moaNumber}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DateTile(
                  label: 'New expiry date',
                  date: endDate,
                  onChanged: (value) => setDialogState(() => endDate = value),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx'],
                    );
                    if (file != null) {
                      setDialogState(() => replacementFile = file);
                    }
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    replacementFile?.name ?? 'Replace document (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await repository.renewMoa(
                    actor: user,
                    record: record,
                    endDate: endDate,
                    replacementFile: replacementFile,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    );
  }
}

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.studentsOnly,
  });

  final AppUser user;
  final PracticumRepository repository;
  final bool studentsOnly;

  @override
  Widget build(BuildContext context) => _ModulePage(
    title: studentsOnly ? 'Student list' : 'User management',
    subtitle: studentsOnly
        ? 'Live student profiles registered in Firebase.'
        : 'Review coordinator registrations and manage active school accounts.',
    child: StreamBuilder<List<AppUser>>(
      stream: repository.watchUsers(
        role: studentsOnly ? UserRole.student : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Error(error: snapshot.error!);
        final users = snapshot.data ?? const <AppUser>[];
        if (users.isEmpty) {
          return _Empty(
            icon: Icons.groups_outlined,
            title: studentsOnly ? 'No students' : 'No users',
            message: 'Profiles created in Firebase appear here.',
          );
        }

        final pending = !studentsOnly && user.role == UserRole.admin
            ? users.where((item) => item.isPendingCoordinator).toList()
            : const <AppUser>[];
        final visibleUsers = studentsOnly
            ? users
            : users.where((item) => !item.isPendingCoordinator).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending.isNotEmpty) ...[
              _CoordinatorRequestPanel(
                requests: pending,
                onReview: (target, approve) =>
                    _reviewCoordinator(context, target, approve),
              ),
              const SizedBox(height: 16),
            ],
            if (!studentsOnly)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 10),
                child: Row(
                  children: [
                    const Text(
                      'Accounts',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${visibleUsers.length}',
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: visibleUsers.isEmpty
                  ? const _Empty(
                      icon: Icons.manage_accounts_outlined,
                      title: 'No approved accounts yet',
                      message:
                          'Pending coordinator requests can be reviewed above.',
                    )
                  : ListView.separated(
                      itemCount: visibleUsers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = visibleUsers[index];
                        return _AccountCard(
                          item: item,
                          studentsOnly: studentsOnly,
                          currentUser: user,
                          onAssignCoordinator: studentsOnly
                              ? () => _assignCoordinator(context, item)
                              : null,
                          onUnassignCoordinator:
                              studentsOnly && item.coordinatorId != null
                              ? () => repository.assignStudent(
                                  actor: user,
                                  student: item,
                                  coordinator: null,
                                )
                              : null,
                          onActiveChanged: !studentsOnly &&
                                  item.uid != user.uid &&
                                  item.approvalStatus == 'approved'
                              ? (active) async {
                                  try {
                                    await repository.setUserActive(
                                      actor: user,
                                      target: item,
                                      active: active,
                                    );
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$error')),
                                      );
                                    }
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _reviewCoordinator(
    BuildContext context,
    AppUser target,
    bool approve,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          approve ? Icons.verified_user_outlined : Icons.person_off_outlined,
          color: approve ? AppTheme.success : AppTheme.danger,
        ),
        title: Text(approve ? 'Approve coordinator?' : 'Reject request?'),
        content: Text(
          approve
              ? 'Approve ${target.displayName} as a school coordinator? This will activate the account and grant coordinator permissions.'
              : 'Reject ${target.displayName}\'s coordinator registration request? The account will remain unable to access the system.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: !approve
                ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
                : null,
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await repository.reviewCoordinatorRegistration(
        actor: user,
        target: target,
        approve: approve,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? '${target.displayName} is now an approved coordinator.'
                  : '${target.displayName}\'s coordinator request was rejected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _assignCoordinator(BuildContext context, AppUser student) async {
    if (user.role == UserRole.coordinator) {
      await repository.assignStudent(
        actor: user,
        student: student,
        coordinator: user,
      );
      return;
    }
    final coordinators =
        (await repository.watchUsers(role: UserRole.coordinator).first)
            .where(
              (coordinator) =>
                  coordinator.active && coordinator.isApprovedCoordinator,
            )
            .toList();
    if (!context.mounted) return;
    if (coordinators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No approved coordinators were found.')),
      );
      return;
    }
    AppUser selected = coordinators.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign ${student.displayName}'),
          content: DropdownButtonFormField<AppUser>(
            isExpanded: true,
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Program Coordinator'),
            items: coordinators
                .map(
                  (coordinator) => DropdownMenuItem(
                    value: coordinator,
                    child: Text(coordinator.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await repository.assignStudent(
                  actor: user,
                  student: student,
                  coordinator: selected,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinatorRequestPanel extends StatelessWidget {
  const _CoordinatorRequestPanel({
    required this.requests,
    required this.onReview,
  });

  final List<AppUser> requests;
  final Future<void> Function(AppUser target, bool approve) onReview;

  @override
  Widget build(BuildContext context) {
    final height = (requests.length * 104.0 + 70).clamp(174.0, 360.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_outlined,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Program Coordinator verification requests',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${requests.length} request${requests.length == 1 ? '' : 's'} waiting for CAS College Coordinator / SIP Admin review',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: height - 70,
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 650;
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.email,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Staff ID: ${item.staffId ?? 'Not supplied'}  •  ${item.department ?? 'Department not supplied'}',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        );
                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => onReview(item, false),
                              icon: const Icon(Icons.close_rounded, size: 17),
                              label: const Text('Reject'),
                            ),
                            FilledButton.icon(
                              onPressed: () => onReview(item, true),
                              icon: const Icon(Icons.check_rounded, size: 17),
                              label: const Text('Approve'),
                            ),
                          ],
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: actions,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: details),
                            const SizedBox(width: 16),
                            actions,
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.item,
    required this.studentsOnly,
    required this.currentUser,
    this.onAssignCoordinator,
    this.onUnassignCoordinator,
    this.onActiveChanged,
  });

  final AppUser item;
  final bool studentsOnly;
  final AppUser currentUser;
  final VoidCallback? onAssignCoordinator;
  final VoidCallback? onUnassignCoordinator;
  final ValueChanged<bool>? onActiveChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final identity = Row(
            children: [
              CircleAvatar(
                child: Text(
                  item.displayName.isEmpty
                      ? '?'
                      : item.displayName[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.email,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11.5,
                      ),
                    ),
                    if (item.studentNumber != null)
                      Text(
                        'Student no. ${item.studentNumber}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    if (!studentsOnly && item.staffId != null)
                      Text(
                        'Staff ID ${item.staffId} • ${item.department ?? 'No department'}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    if (studentsOnly)
                      Text(
                        'Coordinator: ${item.coordinatorName ?? 'Unassigned'}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

          final controls = studentsOnly
              ? Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _AccountStatusChip(item: item),
                    PopupMenuButton<String>(
                      tooltip: 'Coordinator assignment',
                      onSelected: (value) async {
                        if (value == 'assign') {
                          onAssignCoordinator?.call();
                        } else {
                          onUnassignCoordinator?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'assign',
                          child: Text(
                            currentUser.role == UserRole.coordinator
                                ? 'Assign to me'
                                : 'Assign coordinator',
                          ),
                        ),
                        if (item.coordinatorId != null)
                          const PopupMenuItem(
                            value: 'unassign',
                            child: Text('Remove assignment'),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AccountStatusChip(item: item),
                    const SizedBox(width: 10),
                    Switch(
                      value: item.active,
                      onChanged: onActiveChanged,
                    ),
                  ],
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    ),
  );
}

class _AccountStatusChip extends StatelessWidget {
  const _AccountStatusChip({required this.item});

  final AppUser item;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = item.isRejectedCoordinator
        ? ('Rejected', AppTheme.danger, Icons.cancel_outlined)
        : !item.active
        ? ('Inactive', AppTheme.muted, Icons.pause_circle_outline)
        : item.role == UserRole.coordinator
        ? ('Program Coordinator', AppTheme.success, Icons.verified_user_outlined)
        : item.role == UserRole.admin
        ? ('CAS College Coordinator / SIP Admin', AppTheme.blue, Icons.admin_panel_settings_outlined)
        : ('Student', AppTheme.blue, Icons.school_outlined);
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: .08),
      side: BorderSide(color: color.withValues(alpha: .18)),
    );
  }
}

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key, required this.repository});

  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => _ModulePage(
    title: 'Audit logs',
    subtitle: 'Recent account and record changes stored in Firestore.',
    child: StreamBuilder<List<ActivityLogRecord>>(
      stream: repository.watchActivityLogs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Error(error: snapshot.error!);
        final records = snapshot.data ?? const <ActivityLogRecord>[];
        if (records.isEmpty) {
          return const _Empty(
            icon: Icons.history_outlined,
            title: 'No audit events',
            message: 'New backend changes will be recorded here.',
          );
        }
        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = records[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text(item.action),
                subtitle: Text(
                  '${item.userName} • '
                  '${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

Future<void> _copyDownloadLink(
  BuildContext context,
  PracticumRepository repository,
  String path,
) async {
  try {
    final url = await repository.createDownloadUrl(path);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secure five-minute link copied.')),
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

Future<void> _reviewRequirement(
  BuildContext context,
  PracticumRepository repository,
  AppUser reviewer,
  RequirementRecord record,
) async {
  var status = record.status;
  final remarks = TextEditingController(text: record.remarks);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Review ${record.title}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ReviewStatus>(
                isExpanded: true,
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ReviewStatus.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => status = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarks,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await repository.updateRequirementStatus(
                requirementId: record.id,
                status: status,
                remarks: remarks.text,
                reviewer: reviewer,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save review'),
          ),
        ],
      ),
    ),
  );
  remarks.dispose();
}

class _ModulePage extends StatelessWidget {
  const _ModulePage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : 23,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      );

      final header = action == null
          ? heading
          : compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), action!],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 18),
                action!,
              ],
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      );
    },
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(DateFormat.yMMMd().format(date)),
    onTap: () async {
      final value = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: date,
      );
      if (value != null) onChanged(value);
    },
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: AppTheme.blue),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => _Empty(
    icon: Icons.error_outline,
    title: 'Unable to load records',
    message: '$error',
  );
}
