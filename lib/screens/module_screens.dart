import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_feature.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'account_settings_screen.dart';
import 'advanced_reports_screen.dart';
import 'archived_records_screen.dart';
import 'coordinator_dashboard_screen.dart';
import 'document_workflow_screens.dart';
import 'evaluation_management_screen.dart';
import 'dynamic_screens.dart';
import 'moa_management_screen.dart';
import 'notification_panel_screen.dart';
import 'student_profile_screen.dart';
import 'workflow_shared.dart';

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
            ? StudentRequirementsChecklistScreen(
                user: user,
                repository: repository,
              )
            : RequirementDefinitionAdminScreen(
                user: user,
                repository: repository,
              ),
      AppFeature.documentReview => DocumentReviewScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.repository =>
        user.role == UserRole.student
            ? DocumentSubmissionBinScreen(
                user: user,
                repository: repository,
              )
            : DocumentRepositoryScreen(
                user: user,
                repository: repository,
              ),
      AppFeature.dtr => DtrScreen(user: user, repository: repository),
      AppFeature.notifications =>
        user.role == UserRole.admin
            ? NotificationsScreen(user: user, repository: repository)
            : StudentNotificationPanelScreen(user: user, repository: repository),
      AppFeature.reports => AdvancedReportsScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.archivedRecords => ArchivedRecordsScreen(
        user: user,
        repository: repository,
      ),
      AppFeature.evaluations => EvaluationManagementScreen(
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
      AppFeature.settings => AccountSettingsScreen(user: user),
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
        subtitle: user.role == UserRole.student
            ? 'Record your daily attendance, submit it for review, and monitor approved rendered hours.'
            : 'Review assigned interns\' Daily Time Records and monitor approved rendered hours.',
        action: user.role == UserRole.student
            ? FilledButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add_alarm_outlined),
                label: const Text('New DTR entry'),
              )
            : null,
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
              return _EmptyState(
                icon: Icons.punch_clock_outlined,
                title: 'No time records',
                message: user.role == UserRole.student
                    ? 'Create your first Daily Time Record entry.'
                    : 'Submitted DTR entries from assigned interns will appear here.',
              );
            }
            final approved = records
                .where((item) => item.status == ReviewStatus.verified)
                .toList();
            final total = approved.fold<double>(
              0,
              (sum, item) => sum + item.renderedHours,
            );
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final weekStart = today.subtract(Duration(days: today.weekday - 1));
            final monthStart = DateTime(now.year, now.month, 1);
            final weekly = approved
                .where((item) => !item.date.isBefore(weekStart))
                .fold<double>(0, (sum, item) => sum + item.renderedHours);
            final monthly = approved
                .where((item) => !item.date.isBefore(monthStart))
                .fold<double>(0, (sum, item) => sum + item.renderedHours);
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
                      'Weekly Hours',
                      weekly.toStringAsFixed(1),
                      Icons.view_week_outlined,
                      const Color(0xFF2584D8),
                    ),
                    _StatData(
                      'Monthly Hours',
                      monthly.toStringAsFixed(1),
                      Icons.calendar_month_outlined,
                      const Color(0xFF8E44AD),
                    ),
                    _StatData(
                      'Total Approved Hours',
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
                                  user.role == UserRole.student
                                      ? IconButton(
                                          tooltip:
                                              item.status == ReviewStatus.needsRevision ||
                                                      item.status == ReviewStatus.rejected
                                                  ? 'Correct and resubmit'
                                                  : 'Awaiting coordinator review',
                                          onPressed:
                                              item.status == ReviewStatus.needsRevision ||
                                                      item.status == ReviewStatus.rejected
                                                  ? () => _showAddDialog(
                                                        context,
                                                        record: item,
                                                      )
                                                  : null,
                                          icon: const Icon(Icons.edit_outlined),
                                        )
                                      : IconButton(
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

  Future<void> _showAddDialog(
    BuildContext context, {
    DtrRecord? record,
  }) async {
    if (user.role != UserRole.student) return;

    final breakMinutes = TextEditingController(
      text: '${record?.breakMinutes ?? 60}',
    );
    var selectedDate = record?.date ?? DateTime.now();
    var timeIn = record == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay.fromDateTime(record.timeIn);
    var timeOut = record == null
        ? const TimeOfDay(hour: 17, minute: 0)
        : TimeOfDay.fromDateTime(record.timeOut);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'New Daily Time Record' : 'Correct Daily Time Record'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(user.studentNumber ?? user.email),
                ),
                const SizedBox(height: 8),
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
                  decoration: const InputDecoration(
                    labelText: 'Break minutes',
                    helperText:
                        'Rendered hours are calculated automatically after subtracting the break.',
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
            FilledButton.icon(
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
                  if (record == null) {
                    await repository.addDtrEntry(
                      actor: user,
                      studentId: user.uid,
                      studentName: user.displayName,
                      date: selectedDate,
                      timeIn: start,
                      timeOut: end,
                      breakMinutes: int.tryParse(breakMinutes.text) ?? 0,
                    );
                  } else {
                    await repository.updateDtrEntry(
                      student: user,
                      record: record,
                      date: selectedDate,
                      timeIn: start,
                      timeOut: end,
                      breakMinutes: int.tryParse(breakMinutes.text) ?? 0,
                    );
                  }
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
              icon: const Icon(Icons.send_outlined),
              label: Text(record == null ? 'Submit DTR' : 'Resubmit correction'),
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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) => StreamBuilder<List<NotificationRecord>>(
    stream: widget.repository.watchNotifications(widget.user),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _ErrorState(error: snapshot.error!);
      }
      final all = snapshot.data ?? const <NotificationRecord>[];
      final records = all.where((item) {
        if (_query.isEmpty) return true;
        final haystack =
            '${item.title} ${item.message} ${item.targetRole} ${item.priority}'
                .toLowerCase();
        return haystack.contains(_query);
      }).toList();
      final active = all.where((item) => item.active && item.isDue).length;
      final scheduled = all
          .where((item) => item.active && item.scheduledFor != null && !item.isDue)
          .length;

      return WorkflowPage(
        title: 'Notification Management',
        subtitle:
            'Create, schedule, edit, deactivate, delete, and review delivery activity for internship notifications.',
        eyebrow: 'Administration  ›  Notifications',
        actions: [
          FilledButton.icon(
            onPressed: () => _showEditor(context),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Create Notification'),
          ),
        ],
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatCard(
                  label: 'Total Notifications',
                  value: '${all.length}',
                  icon: Icons.notifications_outlined,
                ),
                StatCard(
                  label: 'Active / Sent',
                  value: '$active',
                  icon: Icons.send_outlined,
                ),
                StatCard(
                  label: 'Scheduled',
                  value: '$scheduled',
                  icon: Icons.schedule_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search title, message, audience, or priority',
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: records.isEmpty
                  ? const _EmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'No notifications found',
                      message: 'Create a notification or adjust the search.',
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = records[index];
                        final state = !item.active
                            ? 'Inactive'
                            : item.scheduledFor != null && !item.isDue
                            ? 'Scheduled'
                            : 'Sent';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceBlue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppTheme.blue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Chip(
                                            visualDensity: VisualDensity.compact,
                                            label: Text(state),
                                          ),
                                          Chip(
                                            visualDensity: VisualDensity.compact,
                                            label: Text(item.priority.toUpperCase()),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Audience: ${item.targetRole}  •  '
                                        '${item.scheduledFor == null ? 'Created' : 'Scheduled'} '
                                        '${DateFormat.yMMMd().add_jm().format(item.scheduledFor ?? item.createdAt)}  •  '
                                        'Read by ${item.readBy.length}',
                                        style: const TextStyle(
                                          color: AppTheme.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Notification actions',
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _showEditor(context, existing: item);
                                    } else if (value == 'toggle') {
                                      await widget.repository.setNotificationActive(
                                        actor: widget.user,
                                        notification: item,
                                        active: !item.active,
                                      );
                                    } else if (value == 'delete') {
                                      await _confirmDelete(context, item);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        item.active ? 'Deactivate' : 'Activate',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _showEditor(
    BuildContext context, {
    NotificationRecord? existing,
  }) async {
    final title = TextEditingController(text: existing?.title);
    final message = TextEditingController(text: existing?.message);
    final link = TextEditingController(text: existing?.linkUrl);
    var target = existing?.targetRole ?? 'student';
    if (target.startsWith('user:')) target = 'student';
    var priority = existing?.priority ?? 'normal';
    DateTime? scheduledFor = existing?.scheduledFor;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Create notification' : 'Edit notification',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: target,
                          decoration: const InputDecoration(labelText: 'Audience'),
                          items: const [
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Student Interns'),
                            ),
                            DropdownMenuItem(
                              value: 'coordinator',
                              child: Text('Program Coordinators'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All signed-in users'),
                            ),
                          ],
                          onChanged: existing == null
                              ? (value) => setDialogState(
                                    () => target = value ?? 'student',
                                  )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: const [
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => priority = value ?? 'normal',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: link,
                    decoration: const InputDecoration(
                      labelText: 'Related link (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 3),
                              initialDate: scheduledFor ?? now,
                            );
                            if (date == null || !context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: scheduledFor == null
                                  ? TimeOfDay.fromDateTime(now)
                                  : TimeOfDay.fromDateTime(scheduledFor!),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              scheduledFor = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            scheduledFor == null
                                ? 'Send immediately'
                                : DateFormat.yMMMd()
                                    .add_jm()
                                    .format(scheduledFor!),
                          ),
                        ),
                      ),
                      if (scheduledFor != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Send immediately instead',
                          onPressed: () =>
                              setDialogState(() => scheduledFor = null),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          message.text.trim().isEmpty) {
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (existing == null) {
                          await widget.repository.sendNotification(
                            actor: widget.user,
                            title: title.text,
                            message: message.text,
                            targetRole: target,
                            priority: priority,
                            scheduledFor: scheduledFor,
                            linkUrl: link.text,
                          );
                        } else {
                          await widget.repository.updateNotification(
                            actor: widget.user,
                            notification: existing,
                            title: title.text,
                            message: message.text,
                            priority: priority,
                            scheduledFor: scheduledFor,
                            linkUrl: link.text,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      }
                    },
              child: Text(existing == null ? 'Publish' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    message.dispose();
    link.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NotificationRecord item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text(
          'Delete “${item.title}”? This removes the notification from the dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteNotification(
        actor: widget.user,
        notification: item,
      );
    }
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final heading = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
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
        ),
      );
      if (action == null) return heading;
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 12), action!],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 18),
          action!,
        ],
      );
    },
  );
}

class _ResponsiveStats extends StatelessWidget {
  const _ResponsiveStats({required this.cards});
  final List<_StatData> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 1040
          ? (constraints.maxWidth - (cards.length - 1) * 16) / cards.length
          : constraints.maxWidth >= 600
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: data.color.withValues(alpha: 0.12),
            foregroundColor: data.color,
            child: Icon(data.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
              ),
            ],
          ),
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
  Widget build(BuildContext context) {
    final raw = '$error';
    final permissionDenied = raw.contains('permission-denied') ||
        raw.toLowerCase().contains('insufficient permissions');
    return _EmptyState(
      icon: Icons.error_outline,
      title: 'Unable to load this module',
      message: permissionDenied
          ? 'Firestore denied access to this module. Deploy the updated '
              'firestore.rules, then sign out and sign back in so the latest '
              'coordinator permissions are used.'
          : raw,
    );
  }
}
