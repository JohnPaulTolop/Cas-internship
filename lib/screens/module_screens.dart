import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_feature.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'advanced_reports_screen.dart';
import 'coordinator_dashboard_screen.dart';
import 'document_workflow_screens.dart';
import 'dynamic_screens.dart';
import 'moa_management_screen.dart';
import 'notification_panel_screen.dart';
import 'student_profile_screen.dart';

class ModuleRouter extends StatelessWidget {
  const ModuleRouter({
    super.key,
    required this.feature,
    required this.user,
    required this.repository,
  });

  final AppFeature feature;
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) {
    if (!RoleAccess.canAccess(user.role, feature)) {
      return const _EmptyState(
        icon: Icons.lock_outline,
        title: 'Access denied',
        message: 'Your account is not authorized to open this module.',
      );
    }

    return switch (feature) {
      AppFeature.dashboard =>
        user.role == UserRole.student
            ? OverviewScreen(user: user, repository: repository)
            : CoordinatorDashboardScreen(user: user, repository: repository),
      AppFeature.statusTracker =>
        user.role == UserRole.student
            ? StudentStatusTrackerScreen(user: user, repository: repository)
            : DocumentReviewScreen(user: user, repository: repository),
      AppFeature.requirements =>
        user.role == UserRole.student
            ? DocumentSubmissionBinScreen(user: user, repository: repository)
            : RequirementDefinitionAdminScreen(
                user: user,
                repository: repository,
              ),
      AppFeature.documentReview => DocumentReviewScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.repository => DocumentRepositoryScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.dtr => DtrScreen(user: user, repository: repository),
      AppFeature.notifications =>
        user.role == UserRole.student
            ? StudentNotificationPanelScreen(user: user, repository: repository)
            : NotificationsScreen(user: user, repository: repository),
      AppFeature.reports => AdvancedReportsScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.tor => TorScreen(user: user, repository: repository),
      AppFeature.hours => HoursScreen(user: user, repository: repository),
      AppFeature.moa => MoaManagementScreen(user: user, repository: repository),
      AppFeature.students => StudentDirectoryScreen(
        actor: user,
        repository: repository,
      ),
      AppFeature.users => PeopleScreen(
        user: user,
        repository: repository,
        studentsOnly: false,
      ),
      AppFeature.audit => AuditLogScreen(repository: repository),
    };
  }
}

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 14,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user.displayName.split(' ').first}!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${user.role.label} workspace • ${DateFormat.yMMMMd().format(DateTime.now())}',
                  ),
                ],
              ),
              Chip(
                avatar: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(user.role.label),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      StreamBuilder<List<RequirementRecord>>(
        stream: repository.watchRequirements(user),
        builder: (context, snapshot) {
          final requirements = snapshot.data ?? const <RequirementRecord>[];
          final verified = requirements
              .where((item) => item.status == ReviewStatus.verified)
              .length;
          final pending = requirements
              .where((item) => item.status == ReviewStatus.pending)
              .length;
          return _ResponsiveStats(
            cards: [
              _StatData(
                'Requirements',
                '${requirements.length}',
                Icons.fact_check_outlined,
                AppTheme.blue,
              ),
              _StatData(
                'Verified',
                '$verified',
                Icons.verified_outlined,
                const Color(0xFF27AE60),
              ),
              _StatData(
                'Pending review',
                '$pending',
                Icons.pending_actions_outlined,
                const Color(0xFFF39C12),
              ),
              _StatData(
                'Accessible modules',
                '${RoleAccess.forRole(user.role).length}',
                Icons.apps_outlined,
                const Color(0xFF8E44AD),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your access',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: RoleAccess.forRole(user.role)
                    .map(
                      (feature) => Chip(
                        avatar: Icon(feature.icon, size: 18),
                        label: Text(feature.label),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      StreamBuilder<List<NotificationRecord>>(
        stream: repository.watchNotifications(user),
        builder: (context, snapshot) {
          final notices = (snapshot.data ?? const <NotificationRecord>[])
              .where((notice) => notice.active)
              .toList();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest notices',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (notices.isEmpty)
                    const Text('There are no notices for your account.')
                  else
                    ...notices
                        .take(3)
                        .map(
                          (notice) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.blue,
                            ),
                            title: Text(notice.title),
                            subtitle: Text(notice.message),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

class RequirementsScreen extends StatelessWidget {
  const RequirementsScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ModuleHeader(
        title: user.role == UserRole.student
            ? 'My requirements'
            : 'Requirement review queue',
        subtitle: user.role == UserRole.student
            ? 'Upload PDF, Word, or image files and track verification.'
            : 'Review submissions, verify documents, or request a revision.',
        action: user.role == UserRole.student
            ? FilledButton.icon(
                onPressed: () => _showUploadDialog(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Submit document'),
              )
            : null,
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<RequirementRecord>>(
          stream: repository.watchRequirements(user),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(error: snapshot.error!);
            }
            final records = snapshot.data ?? const <RequirementRecord>[];
            if (records.isEmpty) {
              return const _EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No submissions yet',
                message: 'Submitted requirements will appear here.',
              );
            }
            return ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = records[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.description_outlined),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.studentName} • ${item.fileName ?? 'No file'}\n'
                      'Submitted ${DateFormat.yMMMd().add_jm().format(item.submittedAt)}'
                      '${item.remarks == null || item.remarks!.isEmpty ? '' : '\nRemarks: ${item.remarks}'}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusChip(status: item.status),
                        IconButton(
                          tooltip: 'Copy secure file link',
                          onPressed: item.storagePath == null
                              ? null
                              : () async {
                                  try {
                                    final url = await repository
                                        .createDownloadUrl(item.storagePath!);
                                    await Clipboard.setData(
                                      ClipboardData(text: url),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Secure five-minute link copied.',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('$error')),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.link),
                        ),
                        if (user.role == UserRole.student &&
                            item.status == ReviewStatus.needsRevision)
                          IconButton(
                            tooltip: 'Replace corrected file',
                            onPressed: () => _resubmit(context, item),
                            icon: const Icon(Icons.upload_file_outlined),
                          ),
                        if (user.role != UserRole.student)
                          const SizedBox(width: 4),
                        if (user.role != UserRole.student)
                          IconButton(
                            tooltip: 'Review',
                            onPressed: () => _showReviewDialog(context, item),
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
      ),
    ],
  );

  Future<void> _showUploadDialog(BuildContext context) async {
    final title = TextEditingController();
    PlatformFile? selectedFile;
    var submitting = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit a requirement'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Requirement title',
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final file = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: [
                              'pdf',
                              'doc',
                              'docx',
                              'png',
                              'jpg',
                              'jpeg',
                            ],
                          );
                          if (file != null) {
                            setDialogState(() => selectedFile = file);
                          }
                        },
                  icon: const Icon(Icons.attach_file),
                  label: Text(selectedFile?.name ?? 'Choose file'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Allowed: PDF, DOC, DOCX, PNG, JPG',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty || selectedFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a title and choose a file.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await repository.submitRequirement(
                          user: user,
                          title: title.text.trim(),
                          file: selectedFile!,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Requirement submitted successfully.',
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
  }

  Future<void> _resubmit(
    BuildContext context,
    RequirementRecord requirement,
  ) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (file == null || !context.mounted) return;
    try {
      await repository.resubmitRequirement(
        user: user,
        requirement: requirement,
        file: file,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrected file submitted for review.')),
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

  Future<void> _showReviewDialog(
    BuildContext context,
    RequirementRecord item,
  ) async {
    final remarks = TextEditingController(text: item.remarks);
    ReviewStatus status = item.status;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${item.title}'),
          content: SizedBox(
            width: 480,
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
                    if (value != null) {
                      setDialogState(() => status = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
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
                  requirementId: item.id,
                  status: status,
                  remarks: remarks.text.trim(),
                  reviewer: user,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    remarks.dispose();
  }
}

class RepositoryScreen extends StatelessWidget {
  const RepositoryScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _ModuleHeader(
        title: 'Document repository',
        subtitle: 'Your submitted files and their latest verification status.',
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<RequirementRecord>>(
          stream: repository.watchRequirements(user),
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <RequirementRecord>[];
            if (records.isEmpty) {
              return const _EmptyState(
                icon: Icons.folder_off_outlined,
                title: 'Repository is empty',
                message:
                    'Upload a requirement to place a file in your repository.',
              );
            }
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 190,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final item = records[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              color: AppTheme.blue,
                              size: 30,
                            ),
                            const Spacer(),
                            _StatusChip(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          item.fileName ?? 'No file name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: item.storagePath == null
                              ? null
                              : () async {
                                  final url = await repository
                                      .createDownloadUrl(item.storagePath!);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await Clipboard.setData(
                                    ClipboardData(text: url),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'A five-minute download link was copied.',
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.link),
                          label: const Text('Copy secure link'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class DtrScreen extends StatelessWidget {
  const DtrScreen({super.key, required this.user, required this.repository});
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ModuleHeader(
        title: 'Daily Time Records',
        subtitle: 'Monitor attendance entries and calculated rendered hours.',
        action: FilledButton.icon(
          onPressed: () => _showAddDialog(context),
          icon: const Icon(Icons.add_alarm_outlined),
          label: const Text('Add time record'),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<DtrRecord>>(
          stream: repository.watchDtr(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(error: snapshot.error!);
            }
            final records = snapshot.data ?? const <DtrRecord>[];
            if (records.isEmpty) {
              return const _EmptyState(
                icon: Icons.punch_clock_outlined,
                title: 'No time records',
                message: 'Create the first DTR entry for an assigned student.',
              );
            }
            final total = records.fold<double>(
              0,
              (sum, item) => sum + item.renderedHours,
            );
            return ListView(
              children: [
                _ResponsiveStats(
                  cards: [
                    _StatData(
                      'Records',
                      '${records.length}',
                      Icons.list_alt_outlined,
                      AppTheme.blue,
                    ),
                    _StatData(
                      'Rendered hours',
                      total.toStringAsFixed(1),
                      Icons.timelapse_outlined,
                      const Color(0xFF27AE60),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Time in')),
                        DataColumn(label: Text('Time out')),
                        DataColumn(label: Text('Break')),
                        DataColumn(label: Text('Hours')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Remarks')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: records
                          .map(
                            (item) => DataRow(
                              cells: [
                                DataCell(Text(item.studentName)),
                                DataCell(
                                  Text(DateFormat.yMMMd().format(item.date)),
                                ),
                                DataCell(
                                  Text(DateFormat.jm().format(item.timeIn)),
                                ),
                                DataCell(
                                  Text(DateFormat.jm().format(item.timeOut)),
                                ),
                                DataCell(Text('${item.breakMinutes} min')),
                                DataCell(
                                  Text(item.renderedHours.toStringAsFixed(2)),
                                ),
                                DataCell(_StatusChip(status: item.status)),
                                DataCell(Text(item.remarks ?? '—')),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Review time record',
                                    onPressed: () =>
                                        _showReviewDialog(context, item),
                                    icon: const Icon(
                                      Icons.rate_review_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showAddDialog(BuildContext context) async {
    final students = (await repository.watchUsers(role: UserRole.student).first)
        .where((student) => student.active)
        .toList();
    if (!context.mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an active student account first.'),
        ),
      );
      return;
    }
    AppUser selectedStudent = students.first;
    final breakMinutes = TextEditingController(text: '60');
    var selectedDate = DateTime.now();
    var timeIn = const TimeOfDay(hour: 8, minute: 0);
    var timeOut = const TimeOfDay(hour: 17, minute: 0);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add DTR entry'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppUser>(
                  initialValue: selectedStudent,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student,
                          child: Text(
                            '${student.displayName} (${student.studentNumber ?? student.email})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedStudent = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: selectedDate,
                    );
                    if (value != null) {
                      setDialogState(() => selectedDate = value);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat.yMMMd().format(selectedDate)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: timeIn,
                          );
                          if (value != null) {
                            setDialogState(() => timeIn = value);
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: Text('In: ${timeIn.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: timeOut,
                          );
                          if (value != null) {
                            setDialogState(() => timeOut = value);
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: Text('Out: ${timeOut.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: breakMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Break minutes'),
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
                final start = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  timeIn.hour,
                  timeIn.minute,
                );
                final end = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  timeOut.hour,
                  timeOut.minute,
                );
                try {
                  await repository.addDtrEntry(
                    actor: user,
                    studentId: selectedStudent.uid,
                    studentName: selectedStudent.displayName,
                    date: selectedDate,
                    timeIn: start,
                    timeOut: end,
                    breakMinutes: int.tryParse(breakMinutes.text) ?? 0,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
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
    breakMinutes.dispose();
  }

  Future<void> _showReviewDialog(BuildContext context, DtrRecord item) async {
    var status = item.status;
    final remarks = TextEditingController(text: item.remarks);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${item.studentName} DTR'),
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
                    if (value != null) {
                      setDialogState(() => status = value);
                    }
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
                await repository.updateDtrStatus(
                  reviewer: user,
                  recordId: item.id,
                  status: status,
                  remarks: remarks.text,
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
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ModuleHeader(
        title: 'Messages & notifications',
        subtitle:
            'Publish role-targeted notices and review recent delivery content.',
        action: FilledButton.icon(
          onPressed: () => _showCreateDialog(context),
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('Create notification'),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<NotificationRecord>>(
          stream: repository.watchNotifications(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(error: snapshot.error!);
            }
            final records = snapshot.data ?? const <NotificationRecord>[];
            if (records.isEmpty) {
              return const _EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No notifications',
                message: 'New notices will appear here.',
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
                      child: Icon(Icons.notifications_active_outlined),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.message}\n${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(label: Text(item.targetRole.toUpperCase())),
                        Switch(
                          value: item.active,
                          onChanged: (active) async {
                            await repository.setNotificationActive(
                              actor: user,
                              notification: item,
                              active: active,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showCreateDialog(BuildContext context) async {
    final title = TextEditingController();
    final message = TextEditingController();
    var target = 'student';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create notification'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Students')),
                    DropdownMenuItem(
                      value: 'coordinator',
                      child: Text('Coordinators'),
                    ),
                    DropdownMenuItem(value: 'all', child: Text('All users')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => target = value);
                    }
                  },
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
                if (title.text.trim().isEmpty || message.text.trim().isEmpty) {
                  return;
                }
                await repository.sendNotification(
                  actor: user,
                  title: title.text.trim(),
                  message: message.text.trim(),
                  targetRole: target,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    message.dispose();
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
      ?action,
    ],
  );
}

class _ResponsiveStats extends StatelessWidget {
  const _ResponsiveStats({required this.cards});
  final List<_StatData> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 1100
          ? (constraints.maxWidth - (cards.length - 1) * 14) / cards.length
          : constraints.maxWidth >= 600
          ? (constraints.maxWidth - 14) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: cards
            .map(
              (card) => SizedBox(
                width: width,
                child: _StatCard(data: card),
              ),
            )
            .toList(),
      );
    },
  );
}

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: data.color.withValues(alpha: 0.12),
            foregroundColor: data.color,
            child: Icon(data.icon),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              Text(data.label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ReviewStatus.verified => (
        const Color(0xFF27AE60),
        Icons.check_circle_outline,
      ),
      ReviewStatus.needsRevision => (
        const Color(0xFFE74C3C),
        Icons.edit_note_outlined,
      ),
      ReviewStatus.rejected => (const Color(0xFFC0392B), Icons.cancel_outlined),
      ReviewStatus.underReview => (
        const Color(0xFF6C63FF),
        Icons.rate_review_outlined,
      ),
      ReviewStatus.pending => (const Color(0xFFF39C12), Icons.pending_outlined),
    };
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.black38),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => _EmptyState(
    icon: Icons.error_outline,
    title: 'Unable to load this module',
    message: '$error',
  );
}
