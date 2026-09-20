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
    subtitle: 'Check the status and coordinator feedback for every document.',
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
                          .toList();
                      matches.sort(
                        (a, b) => b.submittedAt.compareTo(a.submittedAt),
                      );
                      return _TrackerItem(
                        title: definition.title,
                        dueDate: definition.dueDate,
                        record: matches.firstOrNull,
                      );
                    }).toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final content = _TrackerList(
                    items: items,
                    repository: repository,
                  );
                  final side = _StudentTrackerSide(user: user, items: items);
                  if (constraints.maxWidth < 900) {
                    return ListView(
                      children: [content, const SizedBox(height: 14), side],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: content),
                      const SizedBox(width: 14),
                      Expanded(flex: 3, child: side),
                    ],
                  );
                },
              );
            },
          ),
    ),
  );
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
  Widget build(BuildContext context) => items.isEmpty
      ? const EmptyWorkflowState(
          icon: Icons.track_changes,
          title: 'No requirements configured',
          message: 'Your coordinator has not configured submission bins yet.',
        )
      : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final record = item.record;
            final progress = record == null
                ? 0.0
                : record.status == ReviewStatus.verified
                ? 1.0
                : .62;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(child: Icon(Icons.description_outlined)),
                    const SizedBox(width: 14),
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                record?.status.label ?? 'Not submitted',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            record == null
                                ? 'No submission yet'
                                : 'Submitted ${shortDate(record.submittedAt)} • Version ${record.version}',
                          ),
                          const SizedBox(height: 9),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          if (record?.remarks?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Coordinator feedback: ${record!.remarks}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (record?.storagePath != null)
                      IconButton(
                        tooltip: 'Open document',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => openStorageDocument(
                          context,
                          repository,
                          record!.storagePath,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
}

class _StudentTrackerSide extends StatelessWidget {
  const _StudentTrackerSide({required this.user, required this.items});
  final AppUser user;
  final List<_TrackerItem> items;

  @override
  Widget build(BuildContext context) {
    final verified = items
        .where((item) => item.record?.status == ReviewStatus.verified)
        .length;
    final upcoming =
        items
            .where(
              (item) =>
                  item.dueDate != null && item.dueDate!.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return Column(
      children: [
        SectionCard(
          title: 'Student Information',
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(
                  user.displayName.isEmpty ? '?' : user.displayName[0],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(user.studentNumber ?? ''),
              const Divider(height: 24),
              _sideRow('Program', user.program ?? 'Not set'),
              _sideRow('Year level', user.yearLevel ?? 'Not set'),
              _sideRow('Coordinator', user.coordinatorName ?? 'Unassigned'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Document Progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$verified of ${items.length} verified'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: items.isEmpty ? 0 : verified / items.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const Divider(height: 24),
              ...upcoming
                  .take(5)
                  .map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      trailing: Text(shortDate(item.dueDate)),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class DocumentSubmissionBinScreen extends StatefulWidget {
  const DocumentSubmissionBinScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  final AppUser user;
  final PracticumRepository repository;

  @override
  State<DocumentSubmissionBinScreen> createState() =>
      _DocumentSubmissionBinScreenState();
}

class _DocumentSubmissionBinScreenState
    extends State<DocumentSubmissionBinScreen> {
  String _query = '';
  String _status = 'All Statuses';
  RequirementDefinition? _selected;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Submission Bin',
    subtitle:
        'View instructions, download forms, and submit internship documents.',
    child: StreamBuilder<List<RequirementDefinition>>(
      stream: widget.repository.watchRequirementDefinitions(),
      builder: (context, definitionSnapshot) =>
          StreamBuilder<List<RequirementRecord>>(
            stream: widget.repository.watchRequirements(widget.user),
            builder: (context, recordSnapshot) {
              final records =
                  recordSnapshot.data ?? const <RequirementRecord>[];
              var definitions =
                  (definitionSnapshot.data ?? const <RequirementDefinition>[])
                      .where(
                        (definition) =>
                            definition.program == 'All Programs' ||
                            definition.program == widget.user.program,
                      )
                      .toList();
              definitions = definitions.where((definition) {
                final record = _recordFor(definition, records);
                final matchesQuery =
                    _query.isEmpty ||
                    '${definition.title} ${definition.description}'
                        .toLowerCase()
                        .contains(_query);
                final matchesStatus =
                    _status == 'All Statuses' ||
                    (_status == 'Not submitted'
                        ? record == null
                        : record?.status.label == _status);
                return matchesQuery && matchesStatus;
              }).toList();
              final selected = _selected ?? definitions.firstOrNull;
              final selectedRecord = selected == null
                  ? null
                  : _recordFor(selected, records);
              return Column(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search documents',
                          ),
                          onChanged: (value) =>
                              setState(() => _query = value.toLowerCase()),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items:
                              [
                                    'All Statuses',
                                    'Not submitted',
                                    ...ReviewStatus.values.map(
                                      (value) => value.label,
                                    ),
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => _status = value ?? 'All Statuses'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final grid = _SubmissionGrid(
                          definitions: definitions,
                          records: records,
                          selected: selected,
                          onSelect: (value) =>
                              setState(() => _selected = value),
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
                                allDefinitions: definitions,
                                record: selectedRecord,
                                user: widget.user,
                                repository: widget.repository,
                              );
                        if (constraints.maxWidth < 950) {
                          return ListView(
                            children: [
                              SizedBox(height: 520, child: grid),
                              const SizedBox(height: 14),
                              detail,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: grid),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
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
        .toList();
    matches.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 850
          ? 3
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
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
              .toList();
          matches.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
          final record = matches.firstOrNull;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(definition),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected?.id == definition.id
                      ? AppTheme.blue
                      : const Color(0xFFE0E6ED),
                  width: selected?.id == definition.id ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Due: ${shortDate(definition.dueDate)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        definition.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    StatusBadge(record?.status.label ?? 'Not submitted'),
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
        trailing: StatusBadge(record?.status.label ?? 'Not submitted'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Due date: ${shortDate(definition.dueDate)}'),
            const SizedBox(height: 10),
            const Text(
              'Instructions',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              definition.instructions.isEmpty
                  ? definition.description
                  : definition.instructions,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (definition.officialFormUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(definition.officialFormUrl!),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Official form'),
                  ),
                if (definition.sampleFormUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(definition.sampleFormUrl!),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Sample form'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  record != null &&
                      !{
                        ReviewStatus.needsRevision,
                        ReviewStatus.rejected,
                      }.contains(record!.status)
                  ? null
                  : () => _pickAndUpload(context),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                record == null
                    ? 'Choose and upload file'
                    : 'Upload corrected file',
              ),
            ),
            if (record?.remarks?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Coordinator feedback: ${record!.remarks}'),
                ),
              ),
            ],
          ],
        ),
      ),
      if (record != null) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'Submission History',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Version ${record!.version}'),
                subtitle: Text(
                  '${record!.fileName ?? ''}\n${shortDate(record!.submittedAt)}',
                ),
                trailing: IconButton(
                  onPressed: () => openStorageDocument(
                    context,
                    repository,
                    record!.storagePath,
                  ),
                  icon: const Icon(Icons.open_in_new),
                ),
              ),
              StreamBuilder<List<RequirementVersionRecord>>(
                stream: repository.watchRequirementVersions(record!.id),
                builder: (context, snapshot) => Column(
                  children: (snapshot.data ?? const <RequirementVersionRecord>[])
                      .map(
                        (version) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Version ${version.version}'),
                          subtitle: Text(
                            '${version.fileName}\n${shortDate(version.submittedAt)}',
                          ),
                          trailing: IconButton(
                            onPressed: () => openStorageDocument(
                              context,
                              repository,
                              version.storagePath,
                            ),
                            icon: const Icon(Icons.history),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      SectionCard(
        title: 'Upcoming Deadlines',
        child: Column(
          children:
              (allDefinitions
                      .where(
                        (item) =>
                            item.dueDate.isAfter(DateTime.now()) &&
                            item.id != definition.id,
                      )
                      .toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate)))
                  .take(4)
                  .map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      trailing: Text(shortDate(item.dueDate)),
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
    if (file == null) {
      return;
    }
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
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.')),
        );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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
  RequirementRecord? _selected;

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Repository & Retrieval',
    subtitle: 'Search, organize, preview, and retrieve internship documents.',
    child: StreamBuilder<List<RequirementRecord>>(
      stream: widget.repository.watchRequirements(widget.user),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <RequirementRecord>[];
        final categories = {
          'All Categories',
          ...all.map((record) => record.category),
        }.toList();
        final records = all.where((record) {
          final haystack =
              '${record.title} ${record.studentName} ${record.studentNumber} ${record.institutionName}'
                  .toLowerCase();
          return (_query.isEmpty || haystack.contains(_query)) &&
              (_status == null || record.status == _status) &&
              (_category == 'All Categories' || record.category == _category);
        }).toList();
        final selected =
            _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        return Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search documents or students',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.toLowerCase()),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<ReviewStatus?>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<ReviewStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...ReviewStatus.values.map(
                        (status) => DropdownMenuItem<ReviewStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: categories.contains(_category)
                        ? _category
                        : 'All Categories',
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? 'All Categories'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = _RepositoryList(
                    records: records,
                    selected: selected,
                    onSelect: (record) => setState(() => _selected = record),
                  );
                  final details = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.folder_open,
                          title: 'No document selected',
                          message: 'Select a document to see its details.',
                        )
                      : _RepositoryDetails(
                          record: selected,
                          repository: widget.repository,
                        );
                  if (constraints.maxWidth < 980)
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 420,
                          child: SingleChildScrollView(child: details),
                        ),
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: list),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(child: details),
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
        : ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: records.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                selected: selected?.id == record.id,
                selectedTileColor: AppTheme.blue.withValues(alpha: .08),
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.redAccent,
                ),
                title: Text(
                  record.fileName ?? record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${record.studentName} • ${record.category} • ${shortDate(record.submittedAt)}',
                ),
                trailing: StatusBadge(record.status.label),
                onTap: () => onSelect(record),
              );
            },
          ),
  );
}

class _RepositoryDetails extends StatelessWidget {
  const _RepositoryDetails({required this.record, required this.repository});
  final RequirementRecord record;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SectionCard(
        title: 'Document Details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.picture_as_pdf, size: 48, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              record.fileName ?? record.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  openStorageDocument(context, repository, record.storagePath),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview / Download'),
            ),
            const Divider(height: 28),
            _detailRow('Student', record.studentName),
            _detailRow('Student no.', record.studentNumber ?? '—'),
            _detailRow('Program', record.program ?? '—'),
            _detailRow('Institution', record.institutionName ?? '—'),
            _detailRow('Category', record.category),
            _detailRow('Uploaded', shortDate(record.submittedAt)),
            _detailRow('Version', '${record.version}'),
            _detailRow('Status', record.status.label),
            if (record.remarks?.isNotEmpty == true) ...[
              const Divider(height: 28),
              const Text(
                'Coordinator Remarks',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(record.remarks!),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Version History',
        child: StreamBuilder<List<RequirementVersionRecord>>(
          stream: repository.watchRequirementVersions(record.id),
          builder: (context, snapshot) {
            final versions =
                snapshot.data ?? const <RequirementVersionRecord>[];
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('v${record.version} • Current'),
                  subtitle: Text(shortDate(record.submittedAt)),
                ),
                ...versions.map(
                  (version) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text('v${version.version} • ${version.fileName}'),
                    subtitle: Text(shortDate(version.submittedAt)),
                    onTap: () => openStorageDocument(
                      context,
                      repository,
                      version.storagePath,
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

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
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
  RequirementRecord? _selected;
  String _query = '';
  ReviewStatus? _status;
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkflowPage(
    title: 'Document Review & Verification',
    subtitle:
        'Preview submissions, provide feedback, and update verification status.',
    child: StreamBuilder<List<RequirementRecord>>(
      stream: widget.repository.watchRequirements(widget.user),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <RequirementRecord>[];
        final records = all
            .where(
              (record) =>
                  (_query.isEmpty ||
                      '${record.studentName} ${record.title} ${record.studentNumber}'
                          .toLowerCase()
                          .contains(_query)) &&
                  (_status == null || record.status == _status),
            )
            .toList();
        final selected =
            _selected != null &&
                records.any((record) => record.id == _selected!.id)
            ? records.firstWhere((record) => record.id == _selected!.id)
            : records.firstOrNull;
        if (selected?.id != _selected?.id) {
          _selected = selected;
          _feedback.text = selected?.remarks ?? '';
        }
        return Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search student or document',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.toLowerCase()),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<ReviewStatus?>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<ReviewStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...ReviewStatus.values.map(
                        (status) => DropdownMenuItem<ReviewStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final list = Card(
                    child: ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return ListTile(
                          selected: selected?.id == record.id,
                          selectedTileColor: AppTheme.blue.withValues(
                            alpha: .08,
                          ),
                          title: Text(record.studentName),
                          subtitle: Text(
                            '${record.title} • ${DateFormat.MMMd().format(record.submittedAt)}',
                          ),
                          trailing: StatusBadge(record.status.label),
                          onTap: () => setState(() {
                            _selected = record;
                            _feedback.text = record.remarks ?? '';
                          }),
                        );
                      },
                    ),
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
                          onStatus: (status) =>
                              _saveStatus(context, selected, status),
                        );
                  if (constraints.maxWidth < 900)
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 440,
                          child: SingleChildScrollView(child: detail),
                        ),
                      ],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: list),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 4,
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
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document marked ${status.label}.')),
      );
  }
}

class _ReviewDetail extends StatelessWidget {
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
  Widget build(BuildContext context) => SectionCard(
    title: record.title,
    trailing: StatusBadge(record.status.label),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${record.studentName} • ${record.studentNumber ?? 'No student number'}',
        ),
        Text(
          'Submitted ${shortDate(record.submittedAt)} • Version ${record.version}',
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE4EC)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 58,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 8),
              Text(record.fileName ?? 'Submitted document'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openStorageDocument(
                  context,
                  repository,
                  record.storagePath,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open document preview'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: feedback,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Coordinator feedback',
            hintText: 'Write feedback for the student…',
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Submission history'),
          children: [
            StreamBuilder<List<RequirementVersionRecord>>(
              stream: repository.watchRequirementVersions(record.id),
              builder: (context, snapshot) => Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Version ${record.version} (current)'),
                    subtitle: Text(shortDate(record.submittedAt)),
                  ),
                  ...(snapshot.data ?? const <RequirementVersionRecord>[]).map(
                    (version) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Version ${version.version}'),
                      subtitle: Text(shortDate(version.submittedAt)),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => openStorageDocument(
                          context,
                          repository,
                          version.storagePath,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => onStatus(ReviewStatus.needsRevision),
              child: const Text('Request revision'),
            ),
            OutlinedButton(
              onPressed: () => onStatus(ReviewStatus.rejected),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => onStatus(ReviewStatus.verified),
              child: const Text('Verify document'),
            ),
          ],
        ),
      ],
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
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 390,
            mainAxisExtent: 235,
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
                  const Spacer(),
                  Text('Category: ${definition.category}'),
                  Text('Program: ${definition.program}'),
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
                      if (selected != null)
                        setDialogState(() => dueDate = selected);
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
