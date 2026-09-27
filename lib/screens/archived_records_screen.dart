import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import 'workflow_shared.dart';

class ArchivedRecordsScreen extends StatefulWidget {
  const ArchivedRecordsScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<ArchivedRecordsScreen> createState() => _ArchivedRecordsScreenState();
}

class _ArchivedRecordsScreenState extends State<ArchivedRecordsScreen> {
  AcademicArchiveRecord? _selectedArchive;
  String _query = '';
  String _recordType = 'All Records';

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<AcademicArchiveRecord>>(
    stream: widget.repository.watchAcademicArchives(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to load archives: ${snapshot.error}'),
        );
      }
      final archives = snapshot.data ?? const <AcademicArchiveRecord>[];
      final selected =
          _selectedArchive ?? (archives.isEmpty ? null : archives.first);

      return WorkflowPage(
        title: 'Archived Records',
        subtitle: widget.user.role == UserRole.admin
            ? 'Retrieve completed internship records by academic year while preserving documents, metadata, and verification history.'
            : 'Retrieve archived internship records for interns assigned to your Program Coordinator account.',
        eyebrow: 'Records  ›  Academic Archives',
        child: archives.isEmpty
            ? const EmptyWorkflowState(
                icon: Icons.inventory_2_outlined,
                title: 'No archived academic years',
                message:
                    'Completed and verified internship records will appear here after the CAS College Coordinator archives an academic year.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final archiveList = SectionCard(
                    title: 'Academic Years',
                    subtitle: '${archives.length} archive set(s)',
                    child: Column(
                      children: archives
                          .map(
                            (archive) => ListTile(
                              selected: selected?.id == archive.id,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text('AY ${archive.academicYear}'),
                              subtitle: Text(
                                '${archive.requirementCount} documents • ${archive.dtrCount} DTR • ${archive.evaluationCount} evaluations',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  setState(() => _selectedArchive = archive),
                            ),
                          )
                          .toList(),
                    ),
                  );

                  final detail = selected == null
                      ? const EmptyWorkflowState(
                          icon: Icons.folder_open_outlined,
                          title: 'Select an academic year',
                          message:
                              'Choose an archive set to retrieve its records.',
                        )
                      : _ArchiveDetail(
                          archive: selected,
                          user: widget.user,
                          repository: widget.repository,
                          query: _query,
                          recordType: _recordType,
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                          onRecordTypeChanged: (value) =>
                              setState(() => _recordType = value),
                        );

                  if (constraints.maxWidth < 900) {
                    return ListView(
                      children: [
                        archiveList,
                        const SizedBox(height: 14),
                        detail,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 310,
                        child: SingleChildScrollView(child: archiveList),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: detail),
                    ],
                  );
                },
              ),
      );
    },
  );
}

class _ArchiveDetail extends StatelessWidget {
  const _ArchiveDetail({
    required this.archive,
    required this.user,
    required this.repository,
    required this.query,
    required this.recordType,
    required this.onQueryChanged,
    required this.onRecordTypeChanged,
  });

  final AcademicArchiveRecord archive;
  final AppUser user;
  final PracticumRepository repository;
  final String query;
  final String recordType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onRecordTypeChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<AcademicArchiveContents>(
    future: repository.loadAcademicArchive(archive.academicYear, actor: user),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to retrieve archive: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final contents = snapshot.data!;
      final needle = query.trim().toLowerCase();
      final requirements = contents.requirements.where((record) {
        if (needle.isEmpty) return true;
        return record.studentName.toLowerCase().contains(needle) ||
            record.title.toLowerCase().contains(needle) ||
            (record.studentNumber ?? '').toLowerCase().contains(needle) ||
            record.category.toLowerCase().contains(needle) ||
            (record.program ?? '').toLowerCase().contains(needle);
      }).toList();
      final dtr = contents.dtr.where((record) {
        if (needle.isEmpty) return true;
        return record.studentName.toLowerCase().contains(needle) ||
            DateFormat.yMMMd()
                .format(record.date)
                .toLowerCase()
                .contains(needle);
      }).toList();
      final evaluations = contents.evaluations.where((record) {
        if (needle.isEmpty) return true;
        return record.studentName.toLowerCase().contains(needle) ||
            record.companyName.toLowerCase().contains(needle) ||
            record.supervisorName.toLowerCase().contains(needle);
      }).toList();

      return SectionCard(
        title: 'AY ${archive.academicYear}',
        subtitle:
            'Archived ${DateFormat.yMMMd().format(archive.createdAt)} • Read-only retrieval',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText:
                          'Search student, program, document, company, or date',
                    ),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: recordType,
                    decoration: const InputDecoration(labelText: 'Record Type'),
                    items:
                        const [
                              'All Records',
                              'Documents',
                              'DTR & Hours',
                              'Supervisor Evaluations',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) onRecordTypeChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (recordType == 'All Records' || recordType == 'Documents')
              _ArchiveSection(
                title: 'Documents',
                count: requirements.length,
                children: requirements
                    .map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(record.title),
                        subtitle: Text(
                          '${record.studentName} • ${record.category} • ${record.status.label}',
                        ),
                        trailing: record.storagePath == null
                            ? null
                            : IconButton(
                                tooltip: 'Preview archived document',
                                onPressed: () => _openDocument(context, record),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                      ),
                    )
                    .toList(),
              ),
            if (recordType == 'All Records' || recordType == 'DTR & Hours')
              _ArchiveSection(
                title: 'Daily Time Records',
                count: dtr.length,
                children: dtr
                    .map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_outlined),
                        title: Text(record.studentName),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(record.date)} • ${record.renderedHours.toStringAsFixed(2)} approved hours',
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (recordType == 'All Records' ||
                recordType == 'Supervisor Evaluations')
              _ArchiveSection(
                title: 'Supervisor Evaluations',
                count: evaluations.length,
                children: evaluations
                    .map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.assignment_turned_in_outlined,
                        ),
                        title: Text(record.studentName),
                        subtitle: Text(
                          '${record.companyName} • ${record.supervisorName} • ${record.status}',
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _openDocument(
    BuildContext context,
    RequirementRecord record,
  ) async {
    try {
      final url = await repository.createDownloadUrl(record.storagePath!);
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault)) {
        throw StateError('The document could not be opened.');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: true,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    title: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count', style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
    children: children.isEmpty
        ? const [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('No matching records.'),
            ),
          ]
        : children,
  );
}
