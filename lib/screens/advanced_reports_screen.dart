import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/records.dart';
import '../services/practicum_repository.dart';
import '../services/report_export_service.dart';

class AdvancedReportsScreen extends StatefulWidget {
  const AdvancedReportsScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final PracticumRepository repository;

  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> {
  DateTimeRange? _range;

  AppUser get user => widget.user;
  PracticumRepository get repository => widget.repository;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<RequirementRecord>>(
    stream: repository.watchRequirements(user),
    builder: (context, requirementSnapshot) => StreamBuilder<List<DtrRecord>>(
      stream: repository.watchDtr(user),
      builder: (context, dtrSnapshot) =>
          StreamBuilder<List<SupervisorEvaluationRecord>>(
            stream: repository.watchEvaluations(),
            builder: (context, evaluationSnapshot) =>
                StreamBuilder<List<AcademicArchiveRecord>>(
                  stream: repository.watchAcademicArchives(),
                  builder: (context, archiveSnapshot) {
                    final error =
                        requirementSnapshot.error ??
                        dtrSnapshot.error ??
                        evaluationSnapshot.error ??
                        archiveSnapshot.error;
                    if (error != null) {
                      return Center(
                        child: Text('Unable to load reports: $error'),
                      );
                    }
                    final requirements =
                        (requirementSnapshot.data ??
                                const <RequirementRecord>[])
                            .where((record) => _includes(record.submittedAt))
                            .toList();
                    final dtr = (dtrSnapshot.data ?? const <DtrRecord>[])
                        .where((record) => _includes(record.date))
                        .toList();
                    final evaluations =
                        (evaluationSnapshot.data ??
                                const <SupervisorEvaluationRecord>[])
                            .where((record) => _includes(record.createdAt))
                            .toList();
                    final archives =
                        archiveSnapshot.data ?? const <AcademicArchiveRecord>[];
                    final exporter = const ReportExportService();
                    final rows = exporter.buildRows(
                      requirements: requirements,
                      dtr: dtr,
                      evaluations: evaluations,
                    );
                    final verified = requirements
                        .where(
                          (record) => record.status == ReviewStatus.verified,
                        )
                        .length;
                    final submittedEvaluations = evaluations
                        .where((record) => record.submitted)
                        .length;
                    return ListView(
                      children: [
                        _Header(
                          onCreateEvaluation: () => _createEvaluation(context),
                          onArchive: () => _archive(context),
                          range: _range,
                          onFilter: () => _pickRange(context),
                          onClearFilter: _range == null
                              ? null
                              : () => setState(() => _range = null),
                          onExport: rows.isEmpty
                              ? null
                              : (format) =>
                                    _export(context, exporter, rows, format),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Metric(
                              label: 'Students',
                              value: '${rows.length}',
                              icon: Icons.groups_outlined,
                            ),
                            _Metric(
                              label: 'Verified requirements',
                              value: '$verified/${requirements.length}',
                              icon: Icons.verified_outlined,
                            ),
                            _Metric(
                              label: 'Rendered hours',
                              value: dtr
                                  .fold<double>(
                                    0,
                                    (sum, record) => sum + record.renderedHours,
                                  )
                                  .toStringAsFixed(1),
                              icon: Icons.schedule_outlined,
                            ),
                            _Metric(
                              label: 'Evaluations submitted',
                              value:
                                  '$submittedEvaluations/${evaluations.length}',
                              icon: Icons.assignment_turned_in_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ReportTable(rows: rows),
                        const SizedBox(height: 16),
                        _EvaluationList(
                          evaluations: evaluations,
                          onCopy: (record) =>
                              _copyEvaluationLink(context, record.id),
                        ),
                        const SizedBox(height: 16),
                        _ArchiveList(
                          archives: archives,
                          repository: repository,
                        ),
                      ],
                    );
                  },
                ),
          ),
    ),
  );

  bool _includes(DateTime date) {
    final range = _range;
    if (range == null) return true;
    final inclusiveEnd = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return !date.isBefore(range.start) && !date.isAfter(inclusiveEnd);
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange:
          _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (value != null && mounted) setState(() => _range = value);
  }

  Future<void> _export(
    BuildContext context,
    ReportExportService exporter,
    List<ReportRow> rows,
    String format,
  ) async {
    try {
      switch (format) {
        case 'pdf':
          await exporter.exportPdf(rows);
          break;
        case 'excel':
          await exporter.exportExcel(rows);
          break;
        default:
          await exporter.exportCsv(rows);
          break;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _createEvaluation(BuildContext context) async {
    final pageContext = context;
    final students = (await repository.watchUsers(role: UserRole.student).first)
        .where((student) => student.active)
        .toList();
    if (!context.mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an active student first.')),
      );
      return;
    }
    AppUser selected = students.first;
    final company = TextEditingController();
    final supervisor = TextEditingController();
    final email = TextEditingController();
    final days = TextEditingController(text: '14');
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
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: students
                        .map(
                          (student) => DropdownMenuItem(
                            value: student,
                            child: Text(student.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Link validity in days',
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
                try {
                  final token = await repository.createSupervisorEvaluation(
                    actor: user,
                    student: selected,
                    companyName: company.text,
                    supervisorName: supervisor.text,
                    supervisorEmail: email.text,
                    validDays: int.tryParse(days.text) ?? 14,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _showEvaluationLink(pageContext, token);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Create link'),
            ),
          ],
        ),
      ),
    );
    company.dispose();
    supervisor.dispose();
    email.dispose();
    days.dispose();
  }

  Future<void> _showEvaluationLink(BuildContext context, String token) async {
    final link = _evaluationLink(token);
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Evaluation link created'),
        content: SelectableText(link),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEvaluationLink(BuildContext context, String token) async {
    await Clipboard.setData(ClipboardData(text: _evaluationLink(token)));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Evaluation link copied.')));
    }
  }

  String _evaluationLink(String token) =>
      Uri.base.replace(queryParameters: {'evaluation': token}).toString();

  Future<void> _archive(BuildContext context) async {
    final now = DateTime.now();
    final activeStartYear = now.month >= 6 ? now.year : now.year - 1;
    final defaultYear = activeStartYear - 1;
    final year = TextEditingController(text: '$defaultYear');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive academic year'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This moves matching June–May requirements, DTR entries, and evaluations out of active dashboards.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Starting year (example: 2025)',
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
                final value = int.tryParse(year.text);
                if (value == null || value < 2000 || value > 2100) {
                  throw ArgumentError('Enter a valid starting year.');
                }
                await repository.archiveAcademicYear(
                  actor: user,
                  startYear: value,
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
            child: const Text('Archive records'),
          ),
        ],
      ),
    );
    year.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onCreateEvaluation,
    required this.onArchive,
    required this.onExport,
    required this.range,
    required this.onFilter,
    required this.onClearFilter,
  });

  final VoidCallback onCreateEvaluation;
  final VoidCallback onArchive;
  final ValueChanged<String>? onExport;
  final DateTimeRange? range;
  final VoidCallback onFilter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports & advanced workflows',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Text(
            'Exports, supervisor evaluations, and academic-year archives.',
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onFilter,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              range == null
                  ? 'Date filter'
                  : '${DateFormat.yMMMd().format(range!.start)} – ${DateFormat.yMMMd().format(range!.end)}',
            ),
          ),
          if (onClearFilter != null)
            IconButton(
              tooltip: 'Clear date filter',
              onPressed: onClearFilter,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          FilledButton.icon(
            onPressed: onCreateEvaluation,
            icon: const Icon(Icons.add_link),
            label: const Text('Evaluation link'),
          ),
          OutlinedButton.icon(
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive year'),
          ),
          PopupMenuButton<String>(
            enabled: onExport != null,
            onSelected: onExport,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'excel', child: Text('Export Excel')),
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            ],
            child: const Chip(
              avatar: Icon(Icons.download_outlined),
              label: Text('Export'),
            ),
          ),
        ],
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 245,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.rows});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student report', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('No active report data is available.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Requirements')),
                  DataColumn(label: Text('Verified')),
                  DataColumn(label: Text('Hours')),
                  DataColumn(label: Text('Supervisor rating')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.studentName)),
                          DataCell(Text('${row.requirements}')),
                          DataCell(Text('${row.verified}')),
                          DataCell(Text(row.renderedHours.toStringAsFixed(2))),
                          DataCell(
                            Text(
                              row.evaluationAverage?.toStringAsFixed(2) ?? '—',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}

class _EvaluationList extends StatelessWidget {
  const _EvaluationList({required this.evaluations, required this.onCopy});

  final List<SupervisorEvaluationRecord> evaluations;
  final ValueChanged<SupervisorEvaluationRecord> onCopy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supervisor evaluations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (evaluations.isEmpty)
            const Text('No evaluation links have been created.')
          else
            ...evaluations
                .take(10)
                .map(
                  (record) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      record.submitted
                          ? Icons.task_alt
                          : record.expired
                          ? Icons.timer_off_outlined
                          : Icons.pending_actions_outlined,
                    ),
                    title: Text(record.studentName),
                    subtitle: Text(
                      '${record.companyName} • ${record.supervisorName}\n'
                      '${record.submitted
                          ? 'Submitted • ${record.averageRating.toStringAsFixed(2)}/5'
                          : record.expired
                          ? 'Expired'
                          : 'Pending'}',
                    ),
                    isThreeLine: true,
                    trailing: record.submitted
                        ? null
                        : IconButton(
                            tooltip: 'Copy evaluation link',
                            onPressed: () => onCopy(record),
                            icon: const Icon(Icons.copy),
                          ),
                  ),
                ),
        ],
      ),
    ),
  );
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({required this.archives, required this.repository});

  final List<AcademicArchiveRecord> archives;
  final PracticumRepository repository;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic archives',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (archives.isEmpty)
            const Text('No academic years have been archived.')
          else
            ...archives.map(
              (archive) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('AY ${archive.academicYear}'),
                subtitle: Text(
                  '${archive.requirementCount} requirements • '
                  '${archive.dtrCount} DTR entries • '
                  '${archive.evaluationCount} evaluations\n'
                  '${DateFormat.yMMMd().format(archive.createdAt)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showArchive(context, archive),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _showArchive(
    BuildContext context,
    AcademicArchiveRecord archive,
  ) async {
    final future = repository.loadAcademicArchive(archive.academicYear);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('AY ${archive.academicYear} records'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: FutureBuilder<AcademicArchiveContents>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final contents = snapshot.data!;
              return ListView(
                children: [
                  _ArchiveSection(
                    title: 'Requirements',
                    children: contents.requirements
                        .map(
                          (record) => ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(record.title),
                            subtitle: Text(
                              '${record.studentName} • ${record.status.label}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _ArchiveSection(
                    title: 'Daily time records',
                    children: contents.dtr
                        .map(
                          (record) => ListTile(
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(record.studentName),
                            subtitle: Text(
                              '${DateFormat.yMMMd().format(record.date)} • '
                              '${record.renderedHours.toStringAsFixed(2)} hours',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _ArchiveSection(
                    title: 'Supervisor evaluations',
                    children: contents.evaluations
                        .map(
                          (record) => ListTile(
                            leading: const Icon(
                              Icons.assignment_turned_in_outlined,
                            ),
                            title: Text(record.studentName),
                            subtitle: Text(
                              '${record.companyName} • ${record.status}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: true,
    title: Text('$title (${children.length})'),
    children: children.isEmpty
        ? const [ListTile(title: Text('No records'))]
        : children,
  );
}
