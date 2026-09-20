import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/records.dart';

class ReportExportService {
  const ReportExportService();

  List<ReportRow> buildRows({
    required List<RequirementRecord> requirements,
    required List<DtrRecord> dtr,
    required List<SupervisorEvaluationRecord> evaluations,
  }) {
    final rows = <String, _MutableReportRow>{};
    for (final record in requirements) {
      final row = rows.putIfAbsent(
        record.studentId,
        () => _MutableReportRow(record.studentName),
      );
      row.requirements++;
      if (record.status == ReviewStatus.verified) row.verified++;
    }
    for (final record in dtr) {
      final row = rows.putIfAbsent(
        record.studentId,
        () => _MutableReportRow(record.studentName),
      );
      row.hours += record.renderedHours;
    }
    for (final record in evaluations.where((item) => item.submitted)) {
      final row = rows.putIfAbsent(
        record.studentId,
        () => _MutableReportRow(record.studentName),
      );
      row.evaluation = record.averageRating;
    }
    final result = rows.values
        .map(
          (row) => ReportRow(
            studentName: row.studentName,
            requirements: row.requirements,
            verified: row.verified,
            renderedHours: row.hours,
            evaluationAverage: row.evaluation,
          ),
        )
        .toList();
    result.sort((a, b) => a.studentName.compareTo(b.studentName));
    return result;
  }

  Future<void> exportCsv(List<ReportRow> rows) async {
    final buffer = StringBuffer(
      'Student,Requirements,Verified,Rendered Hours,Supervisor Rating\r\n',
    );
    for (final row in rows) {
      buffer.writeln(
        '${_csv(row.studentName)},${row.requirements},${row.verified},'
        '${row.renderedHours.toStringAsFixed(2)},'
        '${row.evaluationAverage?.toStringAsFixed(2) ?? ''}',
      );
    }
    await _save(
      'practicum-report-${_stamp()}.csv',
      Uint8List.fromList(utf8.encode(buffer.toString())),
    );
  }

  Future<void> exportExcel(List<ReportRow> rows) async {
    final dataRows = rows.map(
      (row) =>
          '<Row>'
          '<Cell><Data ss:Type="String">${_xml(row.studentName)}</Data></Cell>'
          '<Cell><Data ss:Type="Number">${row.requirements}</Data></Cell>'
          '<Cell><Data ss:Type="Number">${row.verified}</Data></Cell>'
          '<Cell><Data ss:Type="Number">${row.renderedHours.toStringAsFixed(2)}</Data></Cell>'
          '<Cell><Data ss:Type="${row.evaluationAverage == null ? 'String' : 'Number'}">'
          '${row.evaluationAverage?.toStringAsFixed(2) ?? ''}</Data></Cell>'
          '</Row>',
    );
    final xml =
        '''<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Worksheet ss:Name="Practicum Report"><Table>
 <Row><Cell><Data ss:Type="String">Student</Data></Cell>
 <Cell><Data ss:Type="String">Requirements</Data></Cell>
 <Cell><Data ss:Type="String">Verified</Data></Cell>
 <Cell><Data ss:Type="String">Rendered Hours</Data></Cell>
 <Cell><Data ss:Type="String">Supervisor Rating</Data></Cell></Row>
 ${dataRows.join('\n')}
 </Table></Worksheet></Workbook>''';
    await _save(
      'practicum-report-${_stamp()}.xls',
      Uint8List.fromList(utf8.encode(xml)),
    );
  }

  Future<void> exportPdf(List<ReportRow> rows) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Practicum Connect Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              _pdfRow(const [
                'Student',
                'Requirements',
                'Verified',
                'Rendered Hours',
                'Supervisor Rating',
              ], header: true),
              ...rows.map(
                (row) => _pdfRow([
                  row.studentName,
                  '${row.requirements}',
                  '${row.verified}',
                  row.renderedHours.toStringAsFixed(2),
                  row.evaluationAverage?.toStringAsFixed(2) ?? '—',
                ]),
              ),
            ],
          ),
        ],
      ),
    );
    await _save('practicum-report-${_stamp()}.pdf', await document.save());
  }

  pw.TableRow _pdfRow(List<String> values, {bool header = false}) =>
      pw.TableRow(
        decoration: header
            ? const pw.BoxDecoration(color: PdfColors.blueGrey100)
            : null,
        children: values
            .map(
              (value) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontWeight: header ? pw.FontWeight.bold : null,
                  ),
                ),
              ),
            )
            .toList(),
      );

  Future<void> _save(String fileName, Uint8List bytes) async {
    await FilePicker.saveFile(
      dialogTitle: 'Save practicum report',
      fileName: fileName,
      bytes: bytes,
    );
  }

  String _stamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class ReportRow {
  const ReportRow({
    required this.studentName,
    required this.requirements,
    required this.verified,
    required this.renderedHours,
    required this.evaluationAverage,
  });

  final String studentName;
  final int requirements;
  final int verified;
  final double renderedHours;
  final double? evaluationAverage;
}

class _MutableReportRow {
  _MutableReportRow(this.studentName);

  final String studentName;
  int requirements = 0;
  int verified = 0;
  double hours = 0;
  double? evaluation;
}
