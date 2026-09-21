import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
import 'workflow_shared.dart';

class StudentStatusTrackerScreen extends StatelessWidget {
  const StudentStatusTrackerScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Status Tracker',
    subtitle: 'Track requirements, verification, deployment, internship progress, completion, and archiving.',
    eyebrow: 'My Internship  ›  Status Tracker',
    child: StreamBuilder<List<RequirementDefinition>>(
      stream: repository.watchRequirementDefinitions(),
      builder: (context, definitionSnapshot) =>
          StreamBuilder<List<RequirementRecord>>(
            stream: repository.watchRequirements(user),
            builder: (context, recordSnapshot) {
              final definitions =
                  (definitionSnapshot.data ?? const <RequirementDefinition>[])
                      .where(
                        (definition) =>
                            definition.program == 'All Programs' ||
                            definition.program == user.program,
                      )
                      .toList();
              final records =
                  recordSnapshot.data ?? const <RequirementRecord>[];
              final items = definitions.isEmpty
                  ? records
                        .map(
                          (record) => _TrackerItem(
                            title: record.title,
                            dueDate: record.dueDate,
                            record: record,
                          ),
                        )
                        .toList()
                  : definitions.map((definition) {
                      final matches = records
                          .where(
                            (record) =>
                                record.definitionId == definition.id ||
                                record.title.toLowerCase() ==
                                    definition.title.toLowerCase(),
                          )
                          .toList()
                        ..sort(
                          (a, b) => b.submittedAt.compareTo(a.submittedAt),
                        );
                      return _TrackerItem(
                        title: definition.title,
                        dueDate: definition.dueDate,
                        record: matches.firstOrNull,
                      );
                    }).toList();

              return StreamBuilder<InternshipProfileRecord?>(
                stream: repository.watchInternshipProfile(user.uid),
                builder: (context, profileSnapshot) {
                  final stage = profileSnapshot.data?.stage ??
                      InternshipStage.pendingRequirements;
                  return Column(
                    children: [
                      _InternshipStageProgress(stage: stage),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final main = _TrackerList(
                              items: items,
                              repository: repository,
                            );
                            final side = _StudentTrackerSide(
                              user: user,
                              items: items,
                            );
                            if (constraints.maxWidth < 920) {
                              return ListView(
                                children: [
                                  main,
                                  const SizedBox(height: 12),
                                  side,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: SingleChildScrollView(child: main),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(width: 285, child: side),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
    ),
  );
}

class _InternshipStageProgress extends StatelessWidget {
  const _InternshipStageProgress({required this.stage});

  final InternshipStage stage;

  @override
  Widget build(BuildContext context) {
    const stages = InternshipStage.values;
    final currentIndex = stages.indexOf(stage);
    return SectionCard(
      title: 'Internship Progress',
      subtitle: 'Current stage: ${stage.label}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          if (compact) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < stages.length; index++)
                  StatusBadge(
                    stages[index].label,
                    compact: true,
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= currentIndex
                              ? AppTheme.blue
                              : const Color(0xFFE8EDF4),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          index < currentIndex
                              ? Icons.check_rounded
                              : index == currentIndex
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: index == currentIndex ? 10 : 15,
                          color: index <= currentIndex
                              ? Colors.white
                              : AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        stages[index].label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: index == currentIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: index <= currentIndex
                              ? AppTheme.text
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 18,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 28),
                    color: index < currentIndex
                        ? AppTheme.blue
                        : const Color(0xFFE8EDF4),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TrackerItem {
  const _TrackerItem({
    required this.title,
    required this.dueDate,
    required this.record,
  });

  final String title;
  final DateTime? dueDate;
  final RequirementRecord? record;
}

class _TrackerList extends StatelessWidget {
  const _TrackerList({required this.items, required this.repository});
  final List<_TrackerItem> items;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SectionCard(
        child: EmptyWorkflowState(
          icon: Icons.track_changes_outlined,
          title: 'No requirements configured',
          message: 'Your coordinator has not configured submission bins yet.',
        ),
      );
    }
    return Column(
      children: items.map((item) {
        final record = item.record;
        final progress = record == null
            ? 0.0
            : record.status == ReviewStatus.verified
            ? 1.0
            : .62;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              record == null ? '0 / 1' : '1 / 1',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusBadge(
                              record?.status.label ?? 'Not submitted',
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record == null
                              ? 'Not yet submitted'
                              : 'Submitted on ${shortDate(record.submittedAt)}',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFEEF1F5),
                          ),
                        ),
                        if (record?.remarks?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 13,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Feedback from Coordinator\n${record!.remarks}',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 9.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (record?.storagePath != null)
                    IconButton(
                      tooltip: 'Open document',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => openStorageDocument(
                        context,
                        repository,
                        record!.storagePath,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 17),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StudentTrackerSide extends StatelessWidget {
  const _StudentTrackerSide({required this.user, required this.items});
  final AppUser user;
  final List<_TrackerItem> items;

  @override
  Widget build(BuildContext context) {
    final upcoming = items
        .where(
          (item) => item.dueDate != null && item.dueDate!.isAfter(DateTime.now()),
        )
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return Column(
      children: [
        SectionCard(
          title: 'Student Information',
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE9EDF3),
                    foregroundColor: AppTheme.muted,
                    child: Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user.studentNumber ?? 'No student number',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              InfoRow('Program', user.program ?? 'Not set', labelWidth: 72),
              InfoRow('Year Level', user.yearLevel ?? 'Not set', labelWidth: 72),
              InfoRow('Email', user.email, labelWidth: 72),
              InfoRow('Adviser', user.coordinatorName ?? 'Unassigned', labelWidth: 72),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Document Deadlines',
          child: upcoming.isEmpty
              ? const Text(
                  'No upcoming deadlines.',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.muted),
                )
              : Column(
                  children: upcoming.take(6).map((item) {
                    final days = item.dueDate!.difference(DateTime.now()).inDays;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 15,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  shortDate(item.dueDate),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            days <= 0 ? 'Due' : '$days days left',
                            style: TextStyle(
                              color: days <= 3 ? AppTheme.danger : AppTheme.muted,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFD),
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: AppTheme.muted),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Submit your documents on or before the deadline to avoid delays in your internship clearance.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 9.2,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class StudentRequirementsChecklistScreen extends StatefulWidget {
  const StudentRequirementsChecklistScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<StudentRequirementsChecklistScreen> createState() =>
      _StudentRequirementsChecklistScreenState();
}

class _StudentRequirementsChecklistScreenState
    extends State<StudentRequirementsChecklistScreen> {
  String _query = '';
  String _filter = 'All Requirements';

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Requirements Checklist',
    subtitle:
        'Review your required internship documents, deadlines, forms, and submission progress.',
    eyebrow: 'My Internship  ›  Requirements Checklist',
    child: StreamBuilder<List<RequirementDefinition>>(
      stream: widget.repository.watchRequirementDefinitions(),
      builder: (context, definitionSnapshot) =>
          StreamBuilder<List<RequirementRecord>>(
            stream: widget.repository.watchRequirements(widget.user),
            builder: (context, recordSnapshot) {
              final records =
                  recordSnapshot.data ?? const <RequirementRecord>[];
              final definitions =
                  (definitionSnapshot.data ?? const <RequirementDefinition>[])
                      .where(
                        (definition) =>
                            definition.active &&
                            (definition.program == 'All Programs' ||
                                definition.program == widget.user.program),
                      )
                      .toList()
                    ..sort((a, b) {
                      final order = a.sortOrder.compareTo(b.sortOrder);
                      if (order != 0) return order;
                      return a.dueDate.compareTo(b.dueDate);
                    });

              final items = definitions.map((definition) {
                final matches = records
                    .where(
                      (record) =>
                          record.definitionId == definition.id ||
                          record.title.toLowerCase() ==
                              definition.title.toLowerCase(),
                    )
                    .toList()
                  ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
                return _RequirementChecklistItem(
                  definition: definition,
                  record: matches.firstOrNull,
                );
              }).toList();

              final completed = items
                  .where((item) => item.record?.status == ReviewStatus.verified)
                  .length;
              final needsAttention = items.where((item) {
                final status = item.record?.status;
                return item.record == null ||
                    status == ReviewStatus.needsRevision ||
                    status == ReviewStatus.rejected;
              }).length;
              final upcoming = items
                  .where(
                    (item) =>
                        item.definition.dueDate.isAfter(DateTime.now()) &&
                        item.record?.status != ReviewStatus.verified,
                  )
                  .length;

              final visible = items.where((item) {
                final haystack =
                    '${item.definition.title} ${item.definition.description} ${item.definition.category}'
                        .toLowerCase();
                final queryMatches =
                    _query.isEmpty || haystack.contains(_query.toLowerCase());
                final status = item.record?.status;
                final filterMatches = switch (_filter) {
                  'Completed' => status == ReviewStatus.verified,
                  'Needs Attention' =>
                    item.record == null ||
                        status == ReviewStatus.needsRevision ||
                        status == ReviewStatus.rejected,
                  'Submitted' => item.record != null,
                  _ => true,
                };
                return queryMatches && filterMatches;
              }).toList();

              return ListView(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 900 ? 4 : width >= 560 ? 2 : 1;
                      final cardWidth = columns == 1
                          ? width
                          : (width - ((columns - 1) * 10)) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ChecklistSummaryCard(
                            width: cardWidth,
                            icon: Icons.fact_check_outlined,
                            label: 'Total Requirements',
                            value: '${items.length}',
                          ),
                          _ChecklistSummaryCard(
                            width: cardWidth,
                            icon: Icons.verified_outlined,
                            label: 'Completed',
                            value: '$completed',
                            accent: AppTheme.success,
                          ),
                          _ChecklistSummaryCard(
                            width: cardWidth,
                            icon: Icons.priority_high_rounded,
                            label: 'Needs Attention',
                            value: '$needsAttention',
                            accent: AppTheme.warning,
                          ),
                          _ChecklistSummaryCard(
                            width: cardWidth,
                            icon: Icons.event_outlined,
                            label: 'Upcoming',
                            value: '$upcoming',
                            accent: AppTheme.purple,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 310,
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded, size: 18),
                                hintText: 'Search requirements…',
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value),
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _filter,
                              decoration: const InputDecoration(
                                labelText: 'Checklist Status',
                              ),
                              items: const [
                                'All Requirements',
                                'Completed',
                                'Submitted',
                                'Needs Attention',
                              ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _filter = value ?? 'All Requirements',
                              ),
                            ),
                          ),
                          if (widget.user.program?.isNotEmpty == true)
                            StatusBadge(widget.user.program!, compact: true),
                          if (widget.user.academicYear?.isNotEmpty == true)
                            StatusBadge(
                              widget.user.academicYear!,
                              compact: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    const EmptyWorkflowState(
                      icon: Icons.fact_check_outlined,
                      title: 'No matching requirements',
                      message:
                          'Try another filter, or contact your coordinator if your checklist is empty.',
                    )
                  else
                    ...visible.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequirementChecklistTile(
                          item: item,
                          user: widget.user,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    ),
  );
}

class _RequirementChecklistItem {
  const _RequirementChecklistItem({
    required this.definition,
    required this.record,
  });

  final RequirementDefinition definition;
  final RequirementRecord? record;
}

class _ChecklistSummaryCard extends StatelessWidget {
  const _ChecklistSummaryCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppTheme.blue,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequirementChecklistTile extends StatelessWidget {
  const _RequirementChecklistTile({
    required this.item,
    required this.user,
    required this.repository,
  });

  final _RequirementChecklistItem item;
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) {
    final definition = item.definition;
    final record = item.record;
    final statusLabel = _studentRequirementStatusLabel(record);
    final completed = record?.status == ReviewStatus.verified;
    final needsAttention = record == null ||
        record.status == ReviewStatus.needsRevision ||
        record.status == ReviewStatus.rejected;
    final indicator = completed
        ? AppTheme.success
        : needsAttention
        ? AppTheme.warning
        : AppTheme.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final leading = Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: indicator.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                completed
                    ? Icons.check_circle_outline_rounded
                    : needsAttention
                    ? Icons.assignment_late_outlined
                    : Icons.hourglass_top_rounded,
                color: indicator,
                size: 21,
              ),
            );

            final body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    StatusBadge(statusLabel, compact: true),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  definition.description.isEmpty
                      ? definition.instructions
                      : definition.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    _ChecklistMeta(
                      icon: Icons.event_outlined,
                      text: 'Due ${shortDate(definition.dueDate)}',
                    ),
                    _ChecklistMeta(
                      icon: Icons.folder_outlined,
                      text: definition.category,
                    ),
                    if (record != null)
                      _ChecklistMeta(
                        icon: Icons.history_rounded,
                        text:
                            'Submitted ${DateFormat.MMMd().format(record.submittedAt)}',
                      ),
                  ],
                ),
              ],
            );

            final actions = Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                if (definition.officialFormUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(definition.officialFormUrl!),
                      mode: LaunchMode.externalApplication,
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.download_outlined, size: 15),
                    label: const Text('Official Form'),
                  ),
                if (definition.sampleFormUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(definition.sampleFormUrl!),
                      mode: LaunchMode.externalApplication,
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Sample'),
                  ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        backgroundColor: AppTheme.background,
                        appBar: AppBar(title: const Text('Document Submission')),
                        body: Padding(
                          padding: const EdgeInsets.all(18),
                          child: DocumentSubmissionBinScreen(
                            user: user,
                            repository: repository,
                            initialDefinitionId: definition.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 15),
                  label: Text(record == null ? 'Submit' : 'Open Submission'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: body),
                    ],
                  ),
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 13),
                Expanded(child: body),
                const SizedBox(width: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChecklistMeta extends StatelessWidget {
  const _ChecklistMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppTheme.subtle),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(color: AppTheme.muted, fontSize: 9.5),
      ),
    ],
  );
}

String _studentRequirementStatusLabel(RequirementRecord? record) {
  if (record == null) return 'Not submitted';
  if (record.status == ReviewStatus.pending) return 'Submitted';
  return record.status.label;
}

class DocumentSubmissionBinScreen extends StatefulWidget {
  const DocumentSubmissionBinScreen({
    super.key,
    required this.user,
    required this.repository,
    this.initialDefinitionId,
  });
  final AppUser user;
  final PracticumRepository repository;
  final String? initialDefinitionId;

  @override
  State<DocumentSubmissionBinScreen> createState() =>
      _DocumentSubmissionBinScreenState();
}

class _DocumentSubmissionBinScreenState
    extends State<DocumentSubmissionBinScreen> {
  String _query = '';
  String _status = 'All Statuses';
  String _category = 'All Document Types';
  RequirementDefinition? _selected;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Submission Bin',
    subtitle: 'View instructions, download forms, and upload required documents.',
    eyebrow: 'Home  ›  Document Submission Bin',
    child: StreamBuilder<List<RequirementDefinition>>(
      stream: widget.repository.watchRequirementDefinitions(),
      builder: (context, definitionSnapshot) =>
          StreamBuilder<List<RequirementRecord>>(
            stream: widget.repository.watchRequirements(widget.user),
            builder: (context, recordSnapshot) {
              final records =
                  recordSnapshot.data ?? const <RequirementRecord>[];
              final allDefinitions =
                  (definitionSnapshot.data ?? const <RequirementDefinition>[])
                      .where(
                        (definition) =>
                            definition.active &&
                            (definition.program == 'All Programs' ||
                                definition.program == widget.user.program),
                      )
                      .toList();
              final categories = {
                'All Document Types',
                ...allDefinitions.map((definition) => definition.category),
              }.toList();
              final definitions = allDefinitions.where((definition) {
                final record = _recordFor(definition, records);
                final matchesQuery = _query.isEmpty ||
                    '${definition.title} ${definition.description}'
                        .toLowerCase()
                        .contains(_query);
                final matchesStatus = _status == 'All Statuses' ||
                    (_status == 'Not submitted'
                        ? record == null
                        : _studentRequirementStatusLabel(record) == _status);
                final matchesCategory = _category == 'All Document Types' ||
                    definition.category == _category;
                return matchesQuery && matchesStatus && matchesCategory;
              }).toList();
              final initialDefinitionId = widget.initialDefinitionId;
              final selected = _selected != null &&
                      definitions.any((item) => item.id == _selected!.id)
                  ? definitions.firstWhere((item) => item.id == _selected!.id)
                  : initialDefinitionId != null &&
                        definitions.any((item) => item.id == initialDefinitionId)
                  ? definitions.firstWhere(
                      (item) => item.id == initialDefinitionId,
                    )
                  : definitions.firstOrNull;
              final selectedRecord = selected == null
                  ? null
                  : _recordFor(selected, records);

              return Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 18),
                            hintText: 'Search documents…',
                          ),
                          onChanged: (value) =>
                              setState(() => _query = value.toLowerCase()),
                        ),
                      ),
                      _filterBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: widget.user.academicYear ?? 'Current',
                          decoration: const InputDecoration(labelText: 'Academic Year'),
                          items: [widget.user.academicYear ?? 'Current']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (_) {},
                        ),
                      ),
                      _filterBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: categories.contains(_category)
                              ? _category
                              : 'All Document Types',
                          decoration: const InputDecoration(labelText: 'Document Type'),
                          items: categories
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _category = value ?? 'All Document Types',
                          ),
                        ),
                      ),
                      _filterBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            'All Statuses',
                            'Not submitted',
                            'Submitted',
                            'Under review',
                            'Verified',
                            'Needs revision',
                            'Rejected',
                          ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _status = value ?? 'All Statuses',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final grid = _SubmissionGrid(
                          definitions: definitions,
                          records: records,
                          selected: selected,
                          onSelect: (value) => setState(() => _selected = value),
                        );
                        final detail = selected == null
                            ? const EmptyWorkflowState(
                                icon: Icons.inbox_outlined,
                                title: 'No submission bins',
                                message:
                                    'Ask the coordinator to configure requirements.',
                              )
                            : _SubmissionDetail(
                                definition: selected,
                                allDefinitions: allDefinitions,
                                record: selectedRecord,
                                user: widget.user,
                                repository: widget.repository,
                              );
                        if (constraints.maxWidth < 960) {
                          return ListView(
                            children: [
                              SizedBox(height: 480, child: grid),
                              const SizedBox(height: 12),
                              detail,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: grid),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 330,
                              child: SingleChildScrollView(child: detail),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    ),
  );

  Widget _filterBox({required double width, required Widget child}) =>
      SizedBox(width: width, child: child);

  RequirementRecord? _recordFor(
    RequirementDefinition definition,
    List<RequirementRecord> records,
  ) {
    final matches = records
        .where(
          (record) =>
              record.definitionId == definition.id ||
              record.title.toLowerCase() == definition.title.toLowerCase(),
        )
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return matches.firstOrNull;
  }
}

class _SubmissionGrid extends StatelessWidget {
  const _SubmissionGrid({
    required this.definitions,
    required this.records,
    required this.selected,
    required this.onSelect,
  });

  final List<RequirementDefinition> definitions;
  final List<RequirementRecord> records;
  final RequirementDefinition? selected;
  final ValueChanged<RequirementDefinition> onSelect;

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return const EmptyWorkflowState(
        icon: Icons.inbox_outlined,
        title: 'No matching requirements',
        message: 'Adjust the filters or contact your coordinator.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1.30,
          ),
          itemCount: definitions.length,
          itemBuilder: (context, index) {
            final definition = definitions[index];
            final matches = records
                .where(
                  (record) =>
                      record.definitionId == definition.id ||
                      record.title.toLowerCase() ==
                          definition.title.toLowerCase(),
                )
                .toList()
              ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
            final record = matches.firstOrNull;
            final active = selected?.id == definition.id;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(definition),
              child: Card(
                color: active ? const Color(0xFFF1F7FF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: active ? AppTheme.blue : AppTheme.border,
                    width: active ? 1.4 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${shortDate(definition.dueDate)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          definition.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 9.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                      StatusBadge(
                        _studentRequirementStatusLabel(record),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SubmissionDetail extends StatelessWidget {
  const _SubmissionDetail({
    required this.definition,
    required this.allDefinitions,
    required this.record,
    required this.user,
    required this.repository,
  });

  final RequirementDefinition definition;
  final List<RequirementDefinition> allDefinitions;
  final RequirementRecord? record;
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SectionCard(
        title: definition.title,
        trailing: StatusBadge(_studentRequirementStatusLabel(record), compact: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Due Date: ${shortDate(definition.dueDate)}',
              style: const TextStyle(fontSize: 9.5, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              definition.instructions.isEmpty
                  ? definition.description
                  : definition.instructions,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 9.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (definition.officialFormUrl?.isNotEmpty == true)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(definition.officialFormUrl!),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Download Official Form'),
                    ),
                  ),
                if (definition.officialFormUrl?.isNotEmpty == true &&
                    definition.sampleFormUrl?.isNotEmpty == true)
                  const SizedBox(width: 7),
                if (definition.sampleFormUrl?.isNotEmpty == true)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(definition.sampleFormUrl!),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Sample Form'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Upload Your Document',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: record != null &&
                      !{
                        ReviewStatus.needsRevision,
                        ReviewStatus.rejected,
                      }.contains(record!.status)
                  ? null
                  : () => _pickAndUpload(context),
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFCFF),
                  border: Border.all(color: const Color(0xFFBFD6F6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppTheme.blue,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record == null
                          ? 'Drag and drop your file here\nor click to browse'
                          : 'Upload a corrected file',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'PDF only • Max file size: 10 MB',
              style: TextStyle(fontSize: 8.5, color: AppTheme.muted),
            ),
          ],
        ),
      ),
      if (record != null) ...[
        const SizedBox(height: 10),
        SectionCard(
          title: 'Submission History',
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Version ${record!.version}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Submitted by ${record!.studentName}\n${DateFormat.yMMMd().add_jm().format(record!.submittedAt)}',
                  style: const TextStyle(fontSize: 9),
                ),
                trailing: StatusBadge(_studentRequirementStatusLabel(record), compact: true),
                onTap: () => openStorageDocument(
                  context,
                  repository,
                  record!.storagePath,
                ),
              ),
              if (record!.remarks?.isNotEmpty == true)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Coordinator Feedback\n${record!.remarks}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 9.3,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 10),
      SectionCard(
        title: 'Upcoming Deadlines',
        trailing: TextButton(onPressed: () {}, child: const Text('View All')),
        child: Column(
          children: (allDefinitions
                  .where(
                    (item) =>
                        item.dueDate.isAfter(DateTime.now()) &&
                        item.id != definition.id,
                  )
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate)))
              .take(4)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('MMM\ndd').format(item.dueDate).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  Future<void> _pickAndUpload(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (file == null) return;
    try {
      if (record == null) {
        await repository.submitRequirement(
          user: user,
          title: definition.title,
          definition: definition,
          file: file,
        );
      } else {
        await repository.resubmitRequirement(
          user: user,
          requirement: record!,
          file: file,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.')),
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

  Future<void> _openUrl(String value) async {
    await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
}

class DocumentRepositoryScreen extends StatefulWidget {
  const DocumentRepositoryScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  State<DocumentRepositoryScreen> createState() =>
      _DocumentRepositoryScreenState();
}

class _DocumentRepositoryScreenState extends State<DocumentRepositoryScreen> {
  String _query = '';
  ReviewStatus? _status;
  String _category = 'All Categories';
  String _program = 'All Programs';
  int _tab = 0;
  RequirementRecord? _selected;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Repository & Retrieval',
    subtitle: 'Store, organize, search, preview, and retrieve internship documents.',
    eyebrow: 'Home  ›  Document Repository',
    actions: [
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
        label: const Text('Save View'),
      ),
    ],
    child: StreamBuilder<List<RequirementRecord>>(
      stream: widget.repository.watchRequirements(widget.user),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <RequirementRecord>[];
        final categories = {'All Categories', ...all.map((r) => r.category)}.toList();
        final programs = {
          'All Programs',
          ...all.map((r) => r.program).whereType<String>(),
        }.toList();
        final tabFiltered = all.where((record) {
          return switch (_tab) {
            1 => record.status == ReviewStatus.pending || record.status == ReviewStatus.underReview,
            2 => record.status == ReviewStatus.verified,
            3 => record.status == ReviewStatus.needsRevision,
            4 => record.archived,
            _ => !record.archived,
          };
        }).toList();
        final records = tabFiltered.where((record) {
          final haystack =
              '${record.title} ${record.fileName} ${record.studentName} ${record.studentNumber} ${record.institutionName}'
                  .toLowerCase();
          return (_query.isEmpty || haystack.contains(_query)) &&
              (_status == null || record.status == _status) &&
              (_category == 'All Categories' || record.category == _category) &&
              (_program == 'All Programs' || record.program == _program);
        }).toList();
        final selected = _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        final counts = [
          all.where((r) => !r.archived).length,
          all.where((r) => !r.archived && (r.status == ReviewStatus.pending || r.status == ReviewStatus.underReview)).length,
          all.where((r) => !r.archived && r.status == ReviewStatus.verified).length,
          all.where((r) => !r.archived && r.status == ReviewStatus.needsRevision).length,
          all.where((r) => r.archived).length,
        ];

        return Column(
          children: [
            WorkspaceTabs(
              labels: const [
                'All Documents',
                'For Verification',
                'Verified',
                'Needs Revision',
                'Archived',
              ],
              counts: counts,
              selectedIndex: _tab,
              onSelected: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = Column(
                    children: [
                      _RepositoryFilters(
                        queryChanged: (value) => setState(() => _query = value.toLowerCase()),
                        status: _status,
                        category: _category,
                        program: _program,
                        categories: categories,
                        programs: programs,
                        onStatus: (value) => setState(() => _status = value),
                        onCategory: (value) => setState(() => _category = value),
                        onProgram: (value) => setState(() => _program = value),
                        onReset: () => setState(() {
                          _query = '';
                          _status = null;
                          _category = 'All Categories';
                          _program = 'All Programs';
                        }),
                      ),
                      const SizedBox(height: 9),
                      Expanded(
                        child: _RepositoryList(
                          records: records,
                          selected: selected,
                          onSelect: (record) => setState(() => _selected = record),
                        ),
                      ),
                    ],
                  );
                  final details = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.folder_open_outlined,
                          title: 'No document selected',
                          message: 'Select a document to view its details.',
                        )
                      : _RepositoryDetails(
                          record: selected,
                          repository: widget.repository,
                        );
                  if (constraints.maxWidth >= 1180) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 205,
                          child: _RepositoryDirectory(
                            records: all,
                            activeCategory: _category,
                            onCategory: (value) => setState(() => _category = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: list),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 315,
                          child: SingleChildScrollView(child: details),
                        ),
                      ],
                    );
                  }
                  if (constraints.maxWidth >= 850) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 7, child: list),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(child: details),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: list),
                      const SizedBox(height: 10),
                      SizedBox(height: 360, child: SingleChildScrollView(child: details)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _RepositoryFilters extends StatelessWidget {
  const _RepositoryFilters({
    required this.queryChanged,
    required this.status,
    required this.category,
    required this.program,
    required this.categories,
    required this.programs,
    required this.onStatus,
    required this.onCategory,
    required this.onProgram,
    required this.onReset,
  });

  final ValueChanged<String> queryChanged;
  final ReviewStatus? status;
  final String category;
  final String program;
  final List<String> categories;
  final List<String> programs;
  final ValueChanged<ReviewStatus?> onStatus;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onProgram;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search by file name, student name/number, keyword…',
              ),
              onChanged: queryChanged,
            ),
          ),
          SizedBox(
            width: 145,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: programs.contains(program) ? program : 'All Programs',
              decoration: const InputDecoration(labelText: 'Program'),
              items: programs
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => onProgram(value ?? 'All Programs'),
            ),
          ),
          SizedBox(
            width: 155,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: categories.contains(category) ? category : 'All Categories',
              decoration: const InputDecoration(labelText: 'Document Category'),
              items: categories
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => onCategory(value ?? 'All Categories'),
            ),
          ),
          SizedBox(
            width: 145,
            child: DropdownButtonFormField<ReviewStatus?>(
              isExpanded: true,
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Verification Status'),
              items: [
                const DropdownMenuItem<ReviewStatus?>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...ReviewStatus.values.map(
                  (value) => DropdownMenuItem<ReviewStatus?>(
                    value: value,
                    child: Text(value.label),
                  ),
                ),
              ],
              onChanged: onStatus,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt, size: 15),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    ),
  );
}

class _RepositoryDirectory extends StatelessWidget {
  const _RepositoryDirectory({
    required this.records,
    required this.activeCategory,
    required this.onCategory,
  });

  final List<RequirementRecord> records;
  final String activeCategory;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    final programs = <String, Map<String, int>>{};
    for (final record in records) {
      final program = record.program ?? 'Other Programs';
      final categories = programs.putIfAbsent(program, () => <String, int>{});
      categories[record.category] = (categories[record.category] ?? 0) + 1;
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'File Directory',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -3),
                  leading: const Icon(Icons.folder_outlined, size: 17),
                  title: const Text('All Documents', style: TextStyle(fontSize: 10.5)),
                  selected: activeCategory == 'All Categories',
                  onTap: () => onCategory('All Categories'),
                ),
                ...programs.entries.map(
                  (program) => ExpansionTile(
                    dense: true,
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                    childrenPadding: const EdgeInsets.only(left: 16),
                    leading: const Icon(Icons.folder_open_outlined, size: 16),
                    title: Text(
                      program.key,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    children: program.value.entries
                        .map(
                          (category) => ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            leading: const Icon(Icons.folder_outlined, size: 15),
                            title: Text(category.key, style: const TextStyle(fontSize: 9.5)),
                            trailing: Text('${category.value}', style: const TextStyle(fontSize: 8.5)),
                            selected: activeCategory == category.key,
                            onTap: () => onCategory(category.key),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepositoryList extends StatelessWidget {
  const _RepositoryList({
    required this.records,
    required this.selected,
    required this.onSelect,
  });

  final List<RequirementRecord> records;
  final RequirementRecord? selected;
  final ValueChanged<RequirementRecord> onSelect;

  @override
  Widget build(BuildContext context) => Card(
    child: records.isEmpty
        ? const EmptyWorkflowState(
            icon: Icons.folder_off_outlined,
            title: 'No matching documents',
            message: 'Adjust the repository filters.',
          )
        : Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xFFF8FAFC),
                child: const Row(
                  children: [
                    SizedBox(width: 28, child: Icon(Icons.check_box_outline_blank, size: 14, color: AppTheme.muted)),
                    Expanded(flex: 3, child: Text('File Name', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Student', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Program', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Category', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('Uploaded', style: _headerStyle)),
                    SizedBox(width: 30),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final active = selected?.id == record.id;
                    return InkWell(
                      onTap: () => onSelect(record),
                      child: Container(
                        color: active ? const Color(0xFFEFF6FF) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Row(
                          children: [
                            const SizedBox(width: 28, child: Icon(Icons.check_box_outline_blank, size: 14, color: AppTheme.muted)),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  const Icon(Icons.picture_as_pdf_outlined, size: 15, color: AppTheme.danger),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      record.fileName ?? record.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(flex: 2, child: _cell(record.studentName)),
                            Expanded(flex: 2, child: _cell(record.program ?? '—')),
                            Expanded(flex: 2, child: _cell(record.category)),
                            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(record.status.label, compact: true))),
                            Expanded(flex: 2, child: _cell(shortDate(record.submittedAt))),
                            const SizedBox(width: 30, child: Icon(Icons.more_horiz, size: 16, color: AppTheme.muted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${records.length} document${records.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                    ),
                    const Spacer(),
                    const Text('Rows per page  10', style: TextStyle(fontSize: 9, color: AppTheme.muted)),
                  ],
                ),
              ),
            ],
          ),
  );

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 8.8,
    color: AppTheme.muted,
    fontWeight: FontWeight.w700,
  );

  Widget _cell(String value) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 9.2, color: AppTheme.text),
  );
}

class _RepositoryDetails extends StatelessWidget {
  const _RepositoryDetails({required this.record, required this.repository});
  final RequirementRecord record;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Document Details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.picture_as_pdf, color: AppTheme.danger, size: 24),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fileName ?? record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'PDF Document • Version ${record.version}',
                    style: const TextStyle(fontSize: 8.8, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => openStorageDocument(context, repository, record.storagePath),
          icon: const Icon(Icons.visibility_outlined, size: 15),
          label: const Text('Preview'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openStorageDocument(context, repository, record.storagePath),
                icon: const Icon(Icons.download_outlined, size: 15),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openStorageDocument(context, repository, record.storagePath),
                icon: const Icon(Icons.inventory_2_outlined, size: 15),
                label: const Text('Retrieve'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history, size: 15),
          label: const Text('View Version History'),
        ),
        const Divider(height: 22),
        const Text(
          'Document Information',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        InfoRow('Student', record.studentName, labelWidth: 80),
        InfoRow('Student No.', record.studentNumber ?? '—', labelWidth: 80),
        InfoRow('Program', record.program ?? '—', labelWidth: 80),
        InfoRow('Category', record.category, labelWidth: 80),
        InfoRow('Institution', record.institutionName ?? '—', labelWidth: 80),
        InfoRow('Uploaded', shortDate(record.submittedAt), labelWidth: 80),
        InfoRow('Version', '${record.version}', labelWidth: 80),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              const SizedBox(width: 80, child: Text('Status', style: TextStyle(fontSize: 10, color: AppTheme.muted))),
              StatusBadge(record.status.label, compact: true),
            ],
          ),
        ),
        if (record.remarks?.isNotEmpty == true) ...[
          const Divider(height: 22),
          const Text(
            'Coordinator Remarks',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            record.remarks!,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.muted, height: 1.35),
          ),
        ],
        const Divider(height: 22),
        const Text(
          'Version History',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        StreamBuilder<List<RequirementVersionRecord>>(
          stream: repository.watchRequirementVersions(record.id),
          builder: (context, snapshot) {
            final versions = snapshot.data ?? const <RequirementVersionRecord>[];
            return Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8, color: AppTheme.blue),
                  title: Text('v${record.version}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                  subtitle: Text('${shortDate(record.submittedAt)} • Current', style: const TextStyle(fontSize: 8.5)),
                ),
                ...versions.take(4).map(
                  (version) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle_outlined, size: 8, color: AppTheme.muted),
                    title: Text('v${version.version}', style: const TextStyle(fontSize: 9.5)),
                    subtitle: Text(shortDate(version.submittedAt), style: const TextStyle(fontSize: 8.5)),
                    onTap: () => openStorageDocument(context, repository, version.storagePath),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class DocumentReviewScreen extends StatefulWidget {
  const DocumentReviewScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen> {
  String _query = '';
  ReviewStatus? _status;
  String _program = 'All Programs';
  String _type = 'All Document Types';
  RequirementRecord? _selected;
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Review',
    subtitle: 'Review and verify student submissions.',
    child: StreamBuilder<List<RequirementRecord>>(
      stream: widget.repository.watchRequirements(widget.user),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <RequirementRecord>[];
        final programs = {
          'All Programs',
          ...all.map((record) => record.program).whereType<String>(),
        }.toList();
        final types = {'All Document Types', ...all.map((record) => record.category)}.toList();
        final records = all.where((record) {
          final haystack =
              '${record.studentName} ${record.studentNumber} ${record.title} ${record.fileName}'
                  .toLowerCase();
          return (_query.isEmpty || haystack.contains(_query)) &&
              (_status == null || record.status == _status) &&
              (_program == 'All Programs' || record.program == _program) &&
              (_type == 'All Document Types' || record.category == _type);
        }).toList();
        final selected = _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    SizedBox(
                      width: 175,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: programs.contains(_program) ? _program : 'All Programs',
                        decoration: const InputDecoration(labelText: 'Program'),
                        items: programs
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => _program = value ?? 'All Programs'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: types.contains(_type) ? _type : 'All Document Types',
                        decoration: const InputDecoration(labelText: 'Document Type'),
                        items: types
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => _type = value ?? 'All Document Types'),
                      ),
                    ),
                    SizedBox(
                      width: 155,
                      child: DropdownButtonFormField<ReviewStatus?>(
                        isExpanded: true,
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem<ReviewStatus?>(value: null, child: Text('All Statuses')),
                          ...ReviewStatus.values.map(
                            (value) => DropdownMenuItem<ReviewStatus?>(value: value, child: Text(value.label)),
                          ),
                        ],
                        onChanged: (value) => setState(() => _status = value),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Search by student name, ID, or document…',
                        ),
                        onChanged: (value) => setState(() => _query = value.toLowerCase()),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _query = '';
                        _status = null;
                        _program = 'All Programs';
                        _type = 'All Document Types';
                      }),
                      icon: const Icon(Icons.restart_alt, size: 15),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = _ReviewList(
                    records: records,
                    selected: selected,
                    onSelect: (record) => setState(() {
                      _selected = record;
                      _feedback.text = record.remarks ?? '';
                    }),
                  );
                  final detail = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.rate_review_outlined,
                          title: 'No submission selected',
                          message: 'Select a document to review it.',
                        )
                      : _ReviewDetail(
                          record: selected,
                          repository: widget.repository,
                          feedback: _feedback,
                          onStatus: (status) => _saveStatus(context, selected, status),
                        );
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 9),
                        SizedBox(height: 430, child: SingleChildScrollView(child: detail)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: list),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(child: detail),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _saveStatus(
    BuildContext context,
    RequirementRecord record,
    ReviewStatus status,
  ) async {
    await widget.repository.updateRequirementStatus(
      requirementId: record.id,
      status: status,
      remarks: _feedback.text,
      reviewer: widget.user,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document marked ${status.label}.')),
      );
    }
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.records,
    required this.selected,
    required this.onSelect,
  });

  final List<RequirementRecord> records;
  final RequirementRecord? selected;
  final ValueChanged<RequirementRecord> onSelect;

  @override
  Widget build(BuildContext context) => Card(
    child: records.isEmpty
        ? const EmptyWorkflowState(
            icon: Icons.inbox_outlined,
            title: 'No submissions found',
            message: 'Adjust the review filters.',
          )
        : Column(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xFFF8FAFC),
                child: const Row(
                  children: [
                    SizedBox(width: 28),
                    Expanded(flex: 3, child: Text('Student Name', style: _reviewHeader)),
                    Expanded(flex: 3, child: Text('Document', style: _reviewHeader)),
                    Expanded(flex: 2, child: Text('Date Submitted', style: _reviewHeader)),
                    Expanded(flex: 2, child: Text('Status', style: _reviewHeader)),
                    SizedBox(width: 28),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final active = selected?.id == record.id;
                    return InkWell(
                      onTap: () => onSelect(record),
                      child: Container(
                        color: active ? const Color(0xFFEFF6FF) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Icon(
                                active ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 14,
                                color: active ? AppTheme.blue : AppTheme.muted,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(record.studentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.w700)),
                                  Text(record.studentNumber ?? '', style: const TextStyle(fontSize: 8.5, color: AppTheme.muted)),
                                ],
                              ),
                            ),
                            Expanded(flex: 3, child: _reviewCell(record.title)),
                            Expanded(flex: 2, child: _reviewCell(shortDate(record.submittedAt))),
                            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(record.status.label, compact: true))),
                            const SizedBox(width: 28, child: Icon(Icons.more_horiz, size: 16, color: AppTheme.muted)),
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

  static const TextStyle _reviewHeader = TextStyle(
    fontSize: 8.8,
    color: AppTheme.muted,
    fontWeight: FontWeight.w700,
  );

  Widget _reviewCell(String value) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 9.2),
  );
}

class _ReviewDetail extends StatefulWidget {
  const _ReviewDetail({
    required this.record,
    required this.repository,
    required this.feedback,
    required this.onStatus,
  });

  final RequirementRecord record;
  final PracticumRepository repository;
  final TextEditingController feedback;
  final ValueChanged<ReviewStatus> onStatus;

  @override
  State<_ReviewDetail> createState() => _ReviewDetailState();
}

class _ReviewDetailState extends State<_ReviewDetail> {
  int _tab = 0;

  @override
  void didUpdateWidget(covariant _ReviewDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _tab = 0;
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: widget.record.title,
    trailing: const Icon(Icons.description_outlined, size: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.record.studentName}   ${widget.record.studentNumber ?? ''}',
          style: const TextStyle(fontSize: 9.5, color: AppTheme.muted),
        ),
        const SizedBox(height: 7),
        WorkspaceTabs(
          labels: const [
            'Document',
            'Student Info',
            'Submission Details',
            'History',
            'Comments',
          ],
          selectedIndex: _tab,
          onSelected: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey('${widget.record.id}-$_tab'),
            child: _tabBody(context),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.feedback,
          minLines: 3,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Coordinator Feedback',
            hintText: 'Write your feedback here…',
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onStatus(ReviewStatus.needsRevision),
                child: const Text('Request Revision'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () => widget.onStatus(ReviewStatus.rejected),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: () => widget.onStatus(ReviewStatus.verified),
                child: const Text('Approve'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tabBody(BuildContext context) => switch (_tab) {
    1 => _studentInfo(),
    2 => _submissionDetails(),
    3 => _history(),
    4 => _comments(),
    _ => _documentPreview(context),
  };

  Widget _documentPreview(BuildContext context) => Container(
    height: 245,
    decoration: BoxDecoration(
      color: const Color(0xFFF3F5F7),
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 14, color: AppTheme.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.record.fileName ?? 'Submitted document',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.8, color: AppTheme.muted),
                ),
              ),
              IconButton(
                tooltip: 'Open document',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () => openStorageDocument(
                  context,
                  widget.repository,
                  widget.record.storagePath,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              width: 250,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.record.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 6, width: 170, color: const Color(0xFFE7EAF0)),
                  const SizedBox(height: 7),
                  Container(height: 5, width: double.infinity, color: const Color(0xFFEEF1F5)),
                  const SizedBox(height: 5),
                  Container(height: 5, width: 210, color: const Color(0xFFEEF1F5)),
                  const Spacer(),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: widget.record.storagePath?.isNotEmpty == true
                          ? () => openStorageDocument(
                                context,
                                widget.repository,
                                widget.record.storagePath,
                              )
                          : null,
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('Open full document'),
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

  Widget _studentInfo() => _detailPanel(
    children: [
      const _DetailHeading('Student Information'),
      InfoRow('Name', widget.record.studentName, labelWidth: 110),
      InfoRow('Student ID', widget.record.studentNumber ?? '—', labelWidth: 110),
      InfoRow('Program', widget.record.program ?? '—', labelWidth: 110),
      InfoRow('Institution', widget.record.institutionName ?? '—', labelWidth: 110),
    ],
  );

  Widget _submissionDetails() => _detailPanel(
    children: [
      const _DetailHeading('Submission Details'),
      InfoRow('Document', widget.record.title, labelWidth: 110),
      InfoRow('File', widget.record.fileName ?? '—', labelWidth: 110),
      InfoRow('Category', widget.record.category, labelWidth: 110),
      InfoRow('Submitted', shortDate(widget.record.submittedAt), labelWidth: 110),
      InfoRow('Due date', shortDate(widget.record.dueDate), labelWidth: 110),
      InfoRow('Version', 'v${widget.record.version}', labelWidth: 110),
      const SizedBox(height: 5),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusBadge(widget.record.status.label, compact: true),
      ),
    ],
  );

  Widget _history() => Container(
    height: 245,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: StreamBuilder<List<RequirementVersionRecord>>(
      stream: widget.repository.watchRequirementVersions(widget.record.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load version history: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          );
        }
        final versions = snapshot.data ?? const <RequirementVersionRecord>[];
        return ListView(
          children: [
            const _DetailHeading('Submission History'),
            _historyTile(
              version: widget.record.version,
              fileName: widget.record.fileName ?? widget.record.title,
              date: widget.record.submittedAt,
              status: widget.record.status.label,
              current: true,
            ),
            ...versions.map(
              (item) => _historyTile(
                version: item.version,
                fileName: item.fileName,
                date: item.submittedAt,
                status: ReviewStatusLabel.parse(item.status).label,
                current: false,
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _historyTile({
    required int version,
    required String fileName,
    required DateTime date,
    required String status,
    required bool current,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: current ? const Color(0xFFF4F8FF) : const Color(0xFFF8FAFC),
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        const Icon(Icons.history, size: 15, color: AppTheme.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version $version${current ? ' • Current' : ''}',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(shortDate(date), style: const TextStyle(fontSize: 8.5, color: AppTheme.muted)),
            Text(status, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    ),
  );

  Widget _comments() => _detailPanel(
    children: [
      const _DetailHeading('Review Comments'),
      Text(
        widget.record.remarks?.trim().isNotEmpty == true
            ? widget.record.remarks!
            : 'No coordinator feedback has been saved for this submission yet.',
        style: const TextStyle(fontSize: 10.2, color: AppTheme.muted, height: 1.45),
      ),
      const SizedBox(height: 12),
      InfoRow('Reviewed by', widget.record.reviewedBy ?? '—', labelWidth: 110),
      InfoRow('Reviewed on', shortDate(widget.record.reviewedAt), labelWidth: 110),
    ],
  );

  Widget _detailPanel({required List<Widget> children}) => Container(
    height: 245,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class RequirementDefinitionAdminScreen extends StatelessWidget {
  const RequirementDefinitionAdminScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Requirement Submission Bins',
    subtitle:
        'Configure document instructions, forms, programs, and deadlines.',
    actions: [
      FilledButton.icon(
        onPressed: () => _showEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New requirement'),
      ),
    ],
    child: StreamBuilder<List<RequirementDefinition>>(
      stream: repository.watchRequirementDefinitions(),
      builder: (context, snapshot) {
        final definitions = snapshot.data ?? const <RequirementDefinition>[];
        if (definitions.isEmpty) {
          return const EmptyWorkflowState(
            icon: Icons.inbox_outlined,
            title: 'No submission bins configured',
            message:
                'Create requirements so students can upload their documents.',
          );
        }
        return GridView.builder(
          primary: false,
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 390,
            mainAxisExtent: 228,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: definitions.length,
          itemBuilder: (context, index) {
            final definition = definitions[index];
            return SectionCard(
              title: definition.title,
              trailing: IconButton(
                tooltip: 'Edit requirement',
                onPressed: () => _showEditor(context, existing: definition),
                icon: const Icon(Icons.edit_outlined),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Category: ${definition.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Program: ${definition.program}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Due: ${shortDate(definition.dueDate)}'),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _showEditor(
    BuildContext context, {
    RequirementDefinition? existing,
  }) async {
    final title = TextEditingController(text: existing?.title);
    final description = TextEditingController(text: existing?.description);
    final instructions = TextEditingController(text: existing?.instructions);
    final category = TextEditingController(text: existing?.category);
    final program = TextEditingController(
      text: existing?.program ?? 'All Programs',
    );
    final officialForm = TextEditingController(text: existing?.officialFormUrl);
    final sampleForm = TextEditingController(text: existing?.sampleFormUrl);
    var dueDate =
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'New requirement bin' : 'Edit requirement bin',
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Requirement title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short description',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructions,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Submission instructions',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: program,
                          decoration: const InputDecoration(
                            labelText: 'Program',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: officialForm,
                          decoration: const InputDecoration(
                            labelText: 'Official form URL',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sampleForm,
                          decoration: const InputDecoration(
                            labelText: 'Sample form URL',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Due date: ${shortDate(dueDate)}'),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        initialDate: dueDate,
                      );
                      if (selected != null) {
                        setDialogState(() => dueDate = selected);
                      }
                    },
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
                await repository.saveRequirementDefinition(
                  actor: user,
                  id: existing?.id,
                  title: title.text,
                  description: description.text,
                  instructions: instructions.text,
                  category: category.text,
                  dueDate: dueDate,
                  program: program.text,
                  officialFormUrl: officialForm.text,
                  sampleFormUrl: sampleForm.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save requirement'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      title,
      description,
      instructions,
      category,
      program,
      officialForm,
      sampleForm,
    ]) {
      controller.dispose();
    }
  }
}
