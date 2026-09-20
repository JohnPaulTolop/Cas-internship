import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
        : 'Activate or deactivate existing Firebase accounts.',
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
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = users[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: CircleAvatar(
                  child: Text(
                    item.displayName.isEmpty
                        ? '?'
                        : item.displayName[0].toUpperCase(),
                  ),
                ),
                title: Text(item.displayName),
                subtitle: Text(
                  '${item.email}'
                  '${item.studentNumber == null ? '' : '\n${item.studentNumber}'}'
                  '${!studentsOnly ? '' : '\nCoordinator: ${item.coordinatorName ?? 'Unassigned'}'}',
                ),
                isThreeLine: studentsOnly || item.studentNumber != null,
                trailing: studentsOnly
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(item.active ? 'Active' : 'Inactive'),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Coordinator assignment',
                            onSelected: (value) async {
                              if (value == 'assign') {
                                await _assignCoordinator(context, item);
                              } else {
                                await repository.assignStudent(
                                  actor: user,
                                  student: item,
                                  coordinator: null,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'assign',
                                child: Text(
                                  user.role == UserRole.coordinator
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
                    : Switch(
                        value: item.active,
                        onChanged: item.uid == user.uid
                            ? null
                            : (active) async {
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
                              },
                      ),
              ),
            );
          },
        );
      },
    ),
  );

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
            .where((coordinator) => coordinator.active)
            .toList();
    if (!context.mounted) return;
    if (coordinators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active coordinators were found.')),
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
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Coordinator'),
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
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
      const SizedBox(height: 16),
      Expanded(child: child),
    ],
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
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.black38),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
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
