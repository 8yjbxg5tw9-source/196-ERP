import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'export_models.dart';

/// Reusable document theme and layout engine for exported PDF reports.
///
/// Every template shares the same header (company identity + report title),
/// zebra-striped right-aligned tables, and a footer with page numbers, a
/// security hash, and the confidentiality notice.
class PdfGeneratorService {
  const PdfGeneratorService();

  Future<Uint8List> build(ReportData data, String templateType) async {
    final pw.Document document = pw.Document();
    final String securityHash = _securityHash(data, templateType);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) => _buildHeader(data),
        footer: (pw.Context context) => _buildFooter(context, securityHash),
        build: (pw.Context context) => _buildBody(data, templateType),
      ),
    );
    return document.save();
  }

  /// Opens the platform print-preview dialog for the generated document.
  Future<bool> printReport(ReportData data, String templateType) async {
    final Uint8List bytes = await build(data, templateType);
    return Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${templateType}_report.pdf',
    );
  }

  pw.Widget _buildHeader(ReportData data) {
    final String companyName = data.company?.name ?? 'FinAI Studio';
    final String? voen = data.company?.voenTin;
    final String generatedAt = DateFormat('dd.MM.yyyy HH:mm').format(
      DateTime.now(),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          _logoMark(),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (voen != null && voen.isNotEmpty)
                  pw.Text(
                    'VÖEN/TIN: $voen',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                data.title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated $generatedAt',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
              pw.Text(
                'Currency ${data.currency}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, String securityHash) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Opacity(
            opacity: 0.25,
            child: _logoMark(size: 16),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'Confidential — for authorized personnel only.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
                pw.Text(
                  'Security hash: $securityHash',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                ),
              ],
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _logoMark({double size = 26}) {
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF059669),
        borderRadius: pw.BorderRadius.circular(size * 0.28),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'F',
        style: pw.TextStyle(
          fontSize: size * 0.56,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  List<pw.Widget> _buildBody(ReportData data, String templateType) {
    final List<pw.Widget> body = <pw.Widget>[
      if (data.periodLabel != null && data.periodLabel!.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            data.periodLabel!,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey,
            ),
          ),
        ),
    ];

    if (data.metrics.isNotEmpty) {
      body.add(_buildMetricStrip(data));
      body.add(pw.SizedBox(height: 14));
    }

    for (final ReportSection section in data.sections) {
      body.add(_buildSection(section));
      body.add(pw.SizedBox(height: 12));
    }

    if (body.isEmpty) {
      body.add(
        pw.Text(
          'No data available for the selected reporting period.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
      );
    }
    return body;
  }

  pw.Widget _buildMetricStrip(ReportData data) {
    final List<pw.Widget> cards = data.metrics
        .map(
          (ReportMetric metric) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    metric.label,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    metric.value,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(growable: false);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: cards,
    );
  }

  pw.Widget _buildSection(ReportSection section) {
    final List<List<String>> rows = section.rows
        .map((ReportRow row) => <String>[row.label, row.value])
        .toList(growable: false);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          section.title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const <String>['Item', 'Amount'],
          data: rows,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromHex('#EEF2F7'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromHex('#F1F5F9'),
          ),
          cellAlignments: const <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
          },
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
        ),
      ],
    );
  }

  static String _securityHash(ReportData data, String templateType) {
    final String payload = <String>[
      templateType,
      data.title,
      data.periodLabel ?? '',
      data.company?.voenTin ?? '',
      DateTime.now().toUtc().toIso8601String(),
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString().substring(0, 16);
  }
}
