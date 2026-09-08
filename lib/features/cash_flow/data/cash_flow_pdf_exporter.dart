import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/cash_flow_line_item.dart';
import '../domain/entities/cash_flow_statement_entity.dart';

/// Writes the compiled IAS 7 statement to a PDF under `reports/`.
class CashFlowPdfExporter {
  const CashFlowPdfExporter();

  Future<String> export(CashFlowStatementEntity statement) async {
    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => <pw.Widget>[
          _title('FinAI Studio — Statement of Cash Flows'),
          _subtitle(statement.dateRange),
          pw.Text(
            'Basis: ${statement.method.label} (IAS 7)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 16),
          for (final CashFlowCategory category in CashFlowCategory.values) ...<pw.Widget>[
            _section('${category.label} activities'),
            for (final CashFlowLineItem item in statement.itemsFor(category))
              _line(item.description, _signed(item)),
            _line(
              'Net ${category.label.toLowerCase()} cash flow',
              _money(_sectionTotal(statement, category)),
              bold: true,
            ),
            pw.SizedBox(height: 8),
          ],
          pw.Divider(),
          _line('Net increase / decrease in cash', _money(statement.netCashChange), bold: true),
          _line('Cash at beginning of period', _money(statement.beginningCashBalance)),
          _line('Cash at end of period', _money(statement.endingCashBalance), bold: true),
        ],
      ),
    );
    final Uint8List bytes = await document.save();
    return _writeFile(bytes);
  }

  static double _sectionTotal(
    CashFlowStatementEntity statement,
    CashFlowCategory category,
  ) {
    return switch (category) {
      CashFlowCategory.operating => statement.operatingCashFlow,
      CashFlowCategory.investing => statement.investingCashFlow,
      CashFlowCategory.financing => statement.financingCashFlow,
    };
  }

  static pw.Widget _title(String value) {
    return pw.Text(
      value,
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _subtitle(DateTimeRange range) {
    return pw.Text(
      _rangeLabel(range),
      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
    );
  }

  static pw.Widget _section(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey,
        ),
      ),
    );
  }

  static pw.Widget _line(String label, String value, {bool bold = false}) {
    final pw.FontWeight weight =
        bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, fontWeight: weight),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: weight),
          ),
        ],
      ),
    );
  }

  static String _signed(CashFlowLineItem item) {
    final String sign =
        item.activityType == CashFlowActivity.inflow ? '+' : '−';
    return '$sign${_money(item.amount)}';
  }

  static String _rangeLabel(DateTimeRange range) {
    final DateFormat format = DateFormat('dd.MM.yyyy');
    return '${format.format(range.start)} – ${format.format(range.end)}';
  }

  static String _money(double value) {
    return 'AZN ${value.toStringAsFixed(2)}';
  }

  Future<String> _writeFile(Uint8List bytes) async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory reportsDirectory = Directory(
      p.join(supportDirectory.path, 'reports'),
    );
    await reportsDirectory.create(recursive: true);
    final String fileName =
        'cash_flow_${DateTime.now().toUtc().millisecondsSinceEpoch}.pdf';
    final File file = File(p.join(reportsDirectory.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
