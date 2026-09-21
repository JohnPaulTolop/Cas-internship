import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/records.dart';
import '../models/workflow_models.dart';
import '../services/practicum_repository.dart';
import '../services/report_export_service.dart';
import 'workflow_shared.dart';

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
  String _reportType = 'Student Summary';
  String _program = 'All Programs';
  String _academicYear = 'All Academic Years';
  String _status = 'All Statuses';
  String _query = '';
  DateTimeRange? _range;
  bool _exporting = false;

  static const _reportTypes = <String>[
    'Student Summary',
    'Student Deployment',
    'Document Verification',
    'DTR & Hours',
    'Supervisor Evaluations',
    'Partner & MOA',
  ];

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
    stream: widget.repository.watchStudentsFor(widget.user),
    builder: (context, studentSnapshot) =>
        StreamBuilder<List<InternshipProfileRecord>>(
      stream: widget.repository.watchInternshipProfilesFor(widget.user),
      builder: (context, profileSnapshot) =>
          StreamBuilder<List<RequirementRecord>>(
        stream: widget.repository.watchRequirements(widget.user),
        builder: (context, requirementSnapshot) =>
            StreamBuilder<List<DtrRecord>>(
          stream: widget.repository.watchDtr(widget.user),
          builder: (context, dtrSnapshot) =>
              StreamBuilder<List<SupervisorEvaluationRecord>>(
            stream: widget.repository.watchEvaluationsFor(widget.user),
            builder: (context, evaluationSnapshot) =>
                StreamBuilder<List<MoaRecord>>(
              stream: widget.repository.watchMoas(),
              builder: (context, moaSnapshot) =>
                  StreamBuilder<List<PartnerInstitutionRecord>>(
                stream: widget.repository.watchPartnerInstitutions(),
                builder: (context, partnerSnapshot) {
                  final error = studentSnapshot.error ??
                      profileSnapshot.error ??
                      requirementSnapshot.error ??
                      dtrSnapshot.error ??
                      evaluationSnapshot.error ??
                      moaSnapshot.error ??
                      partnerSnapshot.error;
                  if (error != null) {
                    return Center(child: Text('Unable to load reports: $error'));
                  }

                  final students = studentSnapshot.data ?? const <AppUser>[];
                  final profiles = profileSnapshot.data ??
                      const <InternshipProfileRecord>[];
                  final requirements = requirementSnapshot.data ??
                      const <RequirementRecord>[];
                  final dtr = dtrSnapshot.data ?? const <DtrRecord>[];
                  final evaluations = evaluationSnapshot.data ??
                      const <SupervisorEvaluationRecord>[];
                  final moas = moaSnapshot.data ?? const <MoaRecord>[];
                  final partners = partnerSnapshot.data ??
                      const <PartnerInstitutionRecord>[];

                  final programs = <String>{
                    'All Programs',
                    ...students
                        .map((student) => student.program)
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty),
                    ...moas.expand((record) => record.programs),
                  }.toList()
                    ..sort();
                  final years = <String>{
                    'All Academic Years',
                    ...students
                        .map((student) => student.academicYear)
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty),
                    ...requirements
                        .map((record) => record.academicYear)
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty),
                  }.toList()
                    ..sort();

                  final effectiveProgram = programs.contains(_program)
                      ? _program
                      : 'All Programs';
                  final effectiveYear = years.contains(_academicYear)
                      ? _academicYear
                      : 'All Academic Years';

                  final filteredStudents = students.where((student) {
                    final programMatches = effectiveProgram == 'All Programs' ||
                        student.program == effectiveProgram;
                    final yearMatches =
                        effectiveYear == 'All Academic Years' ||
                            student.academicYear == effectiveYear;
                    return programMatches && yearMatches;
                  }).toList();
                  final studentIds =
                      filteredStudents.map((student) => student.uid).toSet();
                  final studentMap = {
                    for (final student in students) student.uid: student,
                  };
                  final profileMap = {
                    for (final profile in profiles) profile.studentId: profile,
                  };

                  final data = _buildReportData(
                    reportType: _reportType,
                    students: filteredStudents,
                    studentMap: studentMap,
                    profileMap: profileMap,
                    requirements: requirements
                        .where((record) => studentIds.contains(record.studentId))
                        .where((record) => _inRange(record.submittedAt))
                        .toList(),
                    dtr: dtr
                        .where((record) => studentIds.contains(record.studentId))
                        .where((record) => _inRange(record.date))
                        .toList(),
                    evaluations: evaluations
                        .where((record) => studentIds.contains(record.studentId))
                        .where((record) => _inRange(record.createdAt))
                        .toList(),
                    moas: moas
                        .where(
                          (record) => effectiveProgram == 'All Programs' ||
                              record.programs.isEmpty ||
                              record.programs.contains(effectiveProgram),
                        )
                        .where((record) => _inRange(record.startDate))
                        .toList(),
                    partners: partners.where((record) {
                      return effectiveProgram == 'All Programs' ||
                          record.programs.isEmpty ||
                          record.programs.contains(effectiveProgram);
                    }).toList(),
                  );

                  final statuses = <String>{
                    'All Statuses',
                    ...data.rows.map((row) => row.status).where(
                          (value) => value.trim().isNotEmpty,
                        ),
                  }.toList()
                    ..sort();
                  final effectiveStatus = statuses.contains(_status)
                      ? _status
                      : 'All Statuses';
                  final visibleRows = data.rows.where((row) {
                    final statusMatches =
                        effectiveStatus == 'All Statuses' ||
                            row.status == effectiveStatus;
                    final queryMatches = _query.trim().isEmpty ||
                        row.cells.join(' ').toLowerCase().contains(
                              _query.trim().toLowerCase(),
                            );
                    return statusMatches && queryMatches;
                  }).toList();

                  return WorkflowPage(
                    title: 'Reports & Analytics',
                    subtitle:
                        'Generate filtered internship reports, review dashboard analytics, and export PDF, Excel, or CSV files.',
                    eyebrow: 'CAS Monitoring  ›  Reports & Analytics',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => _archiveAcademicYear(context),
                        icon: const Icon(Icons.archive_outlined, size: 17),
                        label: const Text('Archive Academic Year'),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_exporting && visibleRows.isNotEmpty,
                        onSelected: (format) => _export(
                          context,
                          format,
                          data.headers,
                          visibleRows,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                          PopupMenuItem(
                            value: 'excel',
                            child: Text('Export Excel'),
                          ),
                          PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                        ],
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: (!_exporting && visibleRows.isNotEmpty)
                                ? AppTheme.blue
                                : AppTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (!_exporting && visibleRows.isNotEmpty)
                                  ? AppTheme.blue
                                  : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_exporting)
                                const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.download_outlined,
                                  size: 17,
                                  color: visibleRows.isNotEmpty
                                      ? Colors.white
                                      : AppTheme.muted,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                'Export',
                                style: TextStyle(
                                  color: (!_exporting && visibleRows.isNotEmpty)
                                      ? Colors.white
                                      : AppTheme.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    child: ListView(
                      children: [
                        _ReportFilters(
                          reportType: _reportType,
                          reportTypes: _reportTypes,
                          program: effectiveProgram,
                          programs: programs,
                          academicYear: effectiveYear,
                          academicYears: years,
                          status: effectiveStatus,
                          statuses: statuses,
                          range: _range,
                          onReportType: (value) => setState(() {
                            _reportType = value;
                            _status = 'All Statuses';
                          }),
                          onProgram: (value) =>
                              setState(() => _program = value),
                          onAcademicYear: (value) =>
                              setState(() => _academicYear = value),
                          onStatus: (value) => setState(() => _status = value),
                          onQuery: (value) => setState(() => _query = value),
                          onDateRange: () => _pickRange(context),
                          onReset: () => setState(() {
                            _program = 'All Programs';
                            _academicYear = 'All Academic Years';
                            _status = 'All Statuses';
                            _query = '';
                            _range = null;
                          }),
                        ),
                        const SizedBox(height: 14),
                        _ReportMetrics(data: data, visibleCount: visibleRows.length),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: _reportType,
                          subtitle:
                              '${visibleRows.length} matching record(s) • Filters are applied before export.',
                          padding: EdgeInsets.zero,
                          child: visibleRows.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: EmptyWorkflowState(
                                    icon: Icons.query_stats_outlined,
                                    title: 'No records found',
                                    message:
                                        'Adjust the report type, date range, academic year, program, status, or search criteria.',
                                  ),
                                )
                              : _ReportTable(
                                  headers: data.headers,
                                  rows: visibleRows,
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  bool _inRange(DateTime date) {
    final range = _range;
    if (range == null) return true;
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return !date.isBefore(start) && !date.isAfter(end);
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (result != null && mounted) setState(() => _range = result);
  }

  Future<void> _export(
    BuildContext context,
    String format,
    List<String> headers,
    List<_ReportRowData> rows,
  ) async {
    setState(() => _exporting = true);
    try {
      final exporter = const ReportExportService();
      final cells = rows.map((row) => row.cells).toList();
      switch (format) {
        case 'pdf':
          await exporter.exportGenericPdf(
            title: _reportType,
            headers: headers,
            rows: cells,
          );
          break;
        case 'excel':
          await exporter.exportGenericExcel(
            title: _reportType,
            headers: headers,
            rows: cells,
          );
          break;
        default:
          await exporter.exportGenericCsv(
            title: _reportType,
            headers: headers,
            rows: cells,
          );
      }
      await widget.repository.logReportGeneration(
        actor: widget.user,
        format: format,
        rowCount: rows.length,
        startDate: _range?.start,
        endDate: _range?.end,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} report generated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to export report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _archiveAcademicYear(BuildContext context) async {
    final now = DateTime.now();
    final activeStartYear = now.month >= 6 ? now.year : now.year - 1;
    final controller = TextEditingController(text: '${activeStartYear - 1}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Completed Academic Year'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only completed and verified internship records are archived. Active or incomplete records remain in the active academic year.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Starting year (example: 2025 for AY 2025-2026)',
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
                final year = int.tryParse(controller.text.trim());
                if (year == null || year < 2000 || year > 2100) {
                  throw ArgumentError('Enter a valid academic-year starting year.');
                }
                await widget.repository.archiveAcademicYear(
                  actor: widget.user,
                  startYear: year,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$error')),
                  );
                }
              }
            },
            child: const Text('Archive Eligible Records'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

_ReportData _buildReportData({
  required String reportType,
  required List<AppUser> students,
  required Map<String, AppUser> studentMap,
  required Map<String, InternshipProfileRecord> profileMap,
  required List<RequirementRecord> requirements,
  required List<DtrRecord> dtr,
  required List<SupervisorEvaluationRecord> evaluations,
  required List<MoaRecord> moas,
  required List<PartnerInstitutionRecord> partners,
}) {
  final date = DateFormat.yMMMd();
  final time = DateFormat.jm();

  switch (reportType) {
    case 'Student Deployment':
      return _ReportData(
        headers: const [
          'Student',
          'Student No.',
          'Program',
          'Academic Year',
          'Company / Agency',
          'Placement',
          'Internship Stage',
        ],
        rows: students.map((student) {
          final profile = profileMap[student.uid];
          final stage = profile?.stage.label ??
              InternshipStage.pendingRequirements.label;
          return _ReportRowData(
            status: stage,
            cells: [
              student.displayName,
              student.studentNumber ?? '—',
              student.program ?? '—',
              student.academicYear ?? '—',
              profile?.companyName.isNotEmpty == true
                  ? profile!.companyName
                  : 'Unassigned',
              profile?.placementStatus ?? 'Unassigned',
              stage,
            ],
          );
        }).toList(),
      );

    case 'Document Verification':
      return _ReportData(
        headers: const [
          'Student',
          'Document',
          'Category',
          'Program',
          'Submitted',
          'Status',
        ],
        rows: requirements
            .map(
              (record) => _ReportRowData(
                status: record.status.label,
                cells: [
                  record.studentName,
                  record.title,
                  record.category,
                  record.program ?? studentMap[record.studentId]?.program ?? '—',
                  date.format(record.submittedAt),
                  record.status.label,
                ],
              ),
            )
            .toList(),
      );

    case 'DTR & Hours':
      return _ReportData(
        headers: const [
          'Student',
          'Date',
          'Time In',
          'Time Out',
          'Break',
          'Rendered Hours',
          'Status',
        ],
        rows: dtr
            .map(
              (record) => _ReportRowData(
                status: record.status.label,
                cells: [
                  record.studentName,
                  date.format(record.date),
                  time.format(record.timeIn),
                  time.format(record.timeOut),
                  '${record.breakMinutes} min',
                  record.renderedHours.toStringAsFixed(2),
                  record.status.label,
                ],
              ),
            )
            .toList(),
      );

    case 'Supervisor Evaluations':
      return _ReportData(
        headers: const [
          'Student',
          'Company / Agency',
          'Supervisor',
          'Status',
          'Rating',
          'Submitted',
        ],
        rows: evaluations
            .map(
              (record) => _ReportRowData(
                status: record.expired ? 'Expired' : record.status,
                cells: [
                  record.studentName,
                  record.companyName,
                  record.supervisorName,
                  record.expired ? 'Expired' : record.status,
                  record.submitted
                      ? record.averageRating.toStringAsFixed(2)
                      : '—',
                  record.submittedAt == null
                      ? '—'
                      : date.add_jm().format(record.submittedAt!),
                ],
              ),
            )
            .toList(),
      );

    case 'Partner & MOA':
      final partnerNames = {for (final partner in partners) partner.id: partner.name};
      return _ReportData(
        headers: const [
          'Institution',
          'Reference No.',
          'Programs',
          'Date Signed',
          'Expiration',
          'Status',
        ],
        rows: moas
            .map(
              (record) => _ReportRowData(
                status: record.status,
                cells: [
                  partnerNames[record.partnerId] ?? record.partnerName,
                  record.moaNumber,
                  record.programs.isEmpty
                      ? 'All Programs'
                      : record.programs.join(', '),
                  date.format(record.startDate),
                  date.format(record.endDate),
                  record.status,
                ],
              ),
            )
            .toList(),
      );

    default:
      return _ReportData(
        headers: const [
          'Student',
          'Program',
          'Academic Year',
          'Verified Requirements',
          'Approved Hours',
          'Supervisor Rating',
          'Internship Stage',
        ],
        rows: students.map((student) {
          final studentRequirements = requirements
              .where((record) => record.studentId == student.uid)
              .toList();
          final verified = studentRequirements
              .where((record) => record.status == ReviewStatus.verified)
              .length;
          final approvedHours = dtr
              .where(
                (record) =>
                    record.studentId == student.uid &&
                    record.status == ReviewStatus.verified,
              )
              .fold<double>(0, (sum, record) => sum + record.renderedHours);
          final submittedEvaluations = evaluations
              .where(
                (record) => record.studentId == student.uid && record.submitted,
              )
              .toList();
          final rating = submittedEvaluations.isEmpty
              ? '—'
              : submittedEvaluations.last.averageRating.toStringAsFixed(2);
          final stage = profileMap[student.uid]?.stage.label ??
              InternshipStage.pendingRequirements.label;
          return _ReportRowData(
            status: stage,
            cells: [
              student.displayName,
              student.program ?? '—',
              student.academicYear ?? '—',
              '$verified/${studentRequirements.length}',
              approvedHours.toStringAsFixed(2),
              rating,
              stage,
            ],
          );
        }).toList(),
      );
  }
}

class _ReportData {
  const _ReportData({required this.headers, required this.rows});

  final List<String> headers;
  final List<_ReportRowData> rows;
}

class _ReportRowData {
  const _ReportRowData({required this.status, required this.cells});

  final String status;
  final List<String> cells;
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.reportType,
    required this.reportTypes,
    required this.program,
    required this.programs,
    required this.academicYear,
    required this.academicYears,
    required this.status,
    required this.statuses,
    required this.range,
    required this.onReportType,
    required this.onProgram,
    required this.onAcademicYear,
    required this.onStatus,
    required this.onQuery,
    required this.onDateRange,
    required this.onReset,
  });

  final String reportType;
  final List<String> reportTypes;
  final String program;
  final List<String> programs;
  final String academicYear;
  final List<String> academicYears;
  final String status;
  final List<String> statuses;
  final DateTimeRange? range;
  final ValueChanged<String> onReportType;
  final ValueChanged<String> onProgram;
  final ValueChanged<String> onAcademicYear;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onQuery;
  final VoidCallback onDateRange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: reportType,
                  decoration: const InputDecoration(labelText: 'Report Type'),
                  items: reportTypes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onReportType(value);
                  },
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: academicYear,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: academicYears
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onAcademicYear(value);
                  },
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: program,
                  decoration: const InputDecoration(labelText: 'Program'),
                  items: programs
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onProgram(value);
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onStatus(value);
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    hintText: 'Search report records…',
                  ),
                  onChanged: onQuery,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onDateRange,
                icon: const Icon(Icons.date_range_outlined, size: 17),
                label: Text(
                  range == null
                      ? 'Any Date'
                      : '${DateFormat.MMMd().format(range!.start)} – ${DateFormat.MMMd().format(range!.end)}',
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
      );
}

class _ReportMetrics extends StatelessWidget {
  const _ReportMetrics({required this.data, required this.visibleCount});

  final _ReportData data;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final distinctStatuses = data.rows.map((row) => row.status).toSet().length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatCard(
          label: 'Matching Records',
          value: '$visibleCount',
          icon: Icons.table_rows_outlined,
          color: AppTheme.blue,
        ),
        StatCard(
          label: 'Available Records',
          value: '${data.rows.length}',
          icon: Icons.dataset_outlined,
          color: AppTheme.purple,
        ),
        StatCard(
          label: 'Status Groups',
          value: '$distinctStatuses',
          icon: Icons.donut_small_outlined,
          color: AppTheme.success,
        ),
      ],
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<_ReportRowData> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: headers
              .map(
                (header) => DataColumn(
                  label: Text(
                    header,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
              .toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: row.cells
                      .map(
                        (cell) => DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              cell,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      );
}
