import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'workflow_shared.dart';

class EvaluationManagementScreen extends StatefulWidget {
  const EvaluationManagementScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<EvaluationManagementScreen> createState() =>
      _EvaluationManagementScreenState();
}

class _EvaluationManagementScreenState
    extends State<EvaluationManagementScreen> {
  final Set<String> _syncing = <String>{};

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: widget.repository.watchStudentsFor(widget.user),
    builder: (context, studentSnapshot) => StreamBuilder<List<SupervisorEvaluationRecord>>(
      stream: widget.repository.watchEvaluationsFor(widget.user),
      builder: (context, evaluationSnapshot) {
        final error = studentSnapshot.error ?? evaluationSnapshot.error;
        if (error != null) {
          return Center(child: Text('Unable to load evaluations: $error'));
        }
        final students = studentSnapshot.data ?? const <AppUser>[];
        final evaluations =
            evaluationSnapshot.data ?? const <SupervisorEvaluationRecord>[];

        for (final record in evaluations) {
          if (record.submitted && !_syncing.contains(record.id)) {
            _syncing.add(record.id);
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await widget.repository.syncInternshipStatus(
                  actor: widget.user,
                  studentId: record.studentId,
                );
              } catch (_) {
                // The evaluation remains visible even when a status sync
                // cannot run yet; a later staff visit retries it.
              }
            });
          }
        }

        final submitted = evaluations.where((item) => item.submitted).length;
        final expired = evaluations.where((item) => item.expired).length;
        final pending = evaluations.length - submitted - expired;

        return WorkflowPage(
          title: 'Supervisor Evaluations',
          subtitle:
              'Issue secure one-time evaluation links and monitor industry supervisor submissions.',
          eyebrow: 'Internship Monitoring  ›  Evaluations',
          actions: [
            FilledButton.icon(
              onPressed: students.isEmpty
                  ? null
                  : () => _createEvaluation(context, students),
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('New Evaluation Link'),
            ),
          ],
          child: ListView(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(
                    label: 'Evaluation Links',
                    value: '${evaluations.length}',
                    icon: Icons.link_rounded,
                  ),
                  StatCard(
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.pending_actions_outlined,
                  ),
                  StatCard(
                    label: 'Submitted',
                    value: '$submitted',
                    icon: Icons.task_alt_rounded,
                  ),
                  StatCard(
                    label: 'Expired',
                    value: '$expired',
                    icon: Icons.timer_off_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Evaluation Records',
                subtitle:
                    'Links are valid once, expire automatically, and lock after successful submission.',
                child: evaluations.isEmpty
                    ? const EmptyWorkflowState(
                        icon: Icons.assignment_outlined,
                        title: 'No evaluation links yet',
                        message:
                            'Create an evaluation link for an assigned student intern when the industry supervisor is ready to evaluate.',
                      )
                    : Column(
                        children: evaluations
                            .map(
                              (record) => _EvaluationTile(
                                record: record,
                                onCopy: () => _copyLink(context, record),
                                onEmail: () => _emailLink(context, record),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _createEvaluation(
    BuildContext context,
    List<AppUser> students,
  ) async {
    AppUser selected = students.first;
    final company = TextEditingController();
    final supervisor = TextEditingController();
    final email = TextEditingController();
    final validDays = TextEditingController(text: '14');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create supervisor evaluation link'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AppUser>(
                    isExpanded: true,
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Student intern',
                    ),
                    items: students
                        .map(
                          (student) => DropdownMenuItem(
                            value: student,
                            child: Text(
                              '${student.displayName} (${student.studentNumber ?? student.email})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => selected = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: company,
                    decoration: const InputDecoration(
                      labelText: 'Company / agency',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supervisor,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor email',
                      helperText:
                          'The supervisor must enter this same email before the evaluation form is unlocked.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: validDays,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Link validity (days)',
                    ),
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
                      setDialogState(() => saving = true);
                      try {
                        final token = await widget.repository
                            .createSupervisorEvaluation(
                              actor: widget.user,
                              student: selected,
                              companyName: company.text,
                              supervisorName: supervisor.text,
                              supervisorEmail: email.text,
                              validDays: int.tryParse(validDays.text) ?? 14,
                            );
                        final link = _evaluationLink(token);
                        await Clipboard.setData(ClipboardData(text: link));
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Secure evaluation link created and copied.',
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
              child: const Text('Create Link'),
            ),
          ],
        ),
      ),
    );

    company.dispose();
    supervisor.dispose();
    email.dispose();
    validDays.dispose();
  }

  String _evaluationLink(String token) {
    final base = Uri.base.replace(queryParameters: const {});
    return base.replace(queryParameters: {'evaluation': token}).toString();
  }

  Future<void> _copyLink(
    BuildContext context,
    SupervisorEvaluationRecord record,
  ) async {
    await Clipboard.setData(ClipboardData(text: _evaluationLink(record.id)));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Evaluation link copied.')));
    }
  }

  Future<void> _emailLink(
    BuildContext context,
    SupervisorEvaluationRecord record,
  ) async {
    final link = _evaluationLink(record.id);
    final uri = Uri(
      scheme: 'mailto',
      path: record.supervisorEmail,
      queryParameters: {
        'subject': 'Practicum Connect - Supervisor Evaluation',
        'body':
            'Hello ${record.supervisorName},\n\nPlease complete the Practicum Connect evaluation for ${record.studentName}:\n$link\n\nThis is a one-time secure link and may expire.',
      },
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No email application was available. Copy the secure link instead.',
            ),
          ),
        );
      }
    }
  }
}

class _EvaluationTile extends StatelessWidget {
  const _EvaluationTile({
    required this.record,
    required this.onCopy,
    required this.onEmail,
  });

  final SupervisorEvaluationRecord record;
  final VoidCallback onCopy;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final status = record.submitted
        ? 'Submitted'
        : record.expired
        ? 'Expired'
        : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
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
            child: Icon(
              record.submitted
                  ? Icons.task_alt_rounded
                  : record.expired
                  ? Icons.timer_off_outlined
                  : Icons.assignment_outlined,
              color: AppTheme.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.companyName} • ${record.supervisorName} • ${record.supervisorEmail}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  record.submitted
                      ? 'Submitted ${record.submittedAt == null ? '' : DateFormat.yMMMd().add_jm().format(record.submittedAt!)} • Rating ${record.averageRating.toStringAsFixed(2)}/5'
                      : 'Expires ${DateFormat.yMMMd().add_jm().format(record.expiresAt)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusBadge(status, compact: true),
          if (!record.submitted && !record.expired) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Copy secure link',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: 'Open email client',
              onPressed: onEmail,
              icon: const Icon(Icons.email_outlined),
            ),
          ],
        ],
      ),
    );
  }
}
