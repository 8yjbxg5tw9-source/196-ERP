import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/cash_flow_entity.dart';
import '../../domain/entities/profit_and_loss_entity.dart';

/// Writes generated financial statements to PDF files under the platform
/// application-support directory (`reports/`).
class ReportPdfExporter {
  const ReportPdfExporter();

  Future<String> exportProfitAndLoss(ProfitAndLossEntity report) async {
    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => <pw.Widget>[
          _title('FinAI Studio — Profit & Loss'),
          _subtitle(report.dateRange),
          pw.SizedBox(height: 18),
          _line('Total revenue', _money(report.totalRevenue), bold: true),
          _line('Cost of goods sold', _money(report.cogs)),
          _line('Gross profit', _money(report.grossProfit), bold: true),
          pw.SizedBox(height: 12),
          _section('Operating expenses'),
          ...report.operatingExpenses.entries.map(
            (MapEntry<String, double> entry) =>
                _line(entry.key, _money(entry.value)),
          ),
          _line('Total expenses', _money(report.totalExpenses)),
          pw.SizedBox(height: 12),
          _line('EBITDA', _money(report.ebitda)),
          _line('Net profit', _money(report.netProfit), bold: true),
          _line(
            'Profit margin',
            '${report.profitMarginPercentage.toStringAsFixed(2)}%',
          ),
          pw.SizedBox(height: 12),
          _section('VAT'),
          _line('Output VAT', _money(report.outputVat)),
          _line('Input VAT', _money(report.inputVat)),
          _line('Net payable VAT', _money(report.netPayableVat), bold: true),
        ],
      ),
    );
    final Uint8List bytes = await document.save();
    return _writeFile('profit_and_loss', bytes);
  }

  Future<String> exportCashFlow(CashFlowEntity report) async {
    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => <pw.Widget>[
          _title('FinAI Studio — Cash Flow Statement'),
          _subtitle(report.dateRange),
          pw.SizedBox(height: 18),
          _line('Operating cash flow', _money(report.operatingCashFlow)),
          _line('Investing cash flow', _money(report.investingCashFlow)),
          _line('Financing cash flow', _money(report.financingCashFlow)),
          pw.SizedBox(height: 12),
          _line('Net cash change', _money(report.netCashChange), bold: true),
          _line(
            'Ending cash balance',
            _money(report.endingCashBalance),
            bold: true,
          ),
        ],
      ),
    );
    final Uint8List bytes = await document.save();
    return _writeFile('cash_flow', bytes);
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
      padding: const pw.EdgeInsets.only(bottom: 4),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: weight)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: weight),
          ),
        ],
      ),
    );
  }

  static String _rangeLabel(DateTimeRange range) {
    final DateFormat format = DateFormat('dd.MM.yyyy');
    return '${format.format(range.start)} – ${format.format(range.end)}';
  }

  static String _money(double value) {
    return 'AZN ${value.toStringAsFixed(2)}';
  }

  Future<String> _writeFile(String name, Uint8List bytes) async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory reportsDirectory = Directory(
      p.join(supportDirectory.path, 'reports'),
    );
    await reportsDirectory.create(recursive: true);
    final String fileName =
        '${name}_${DateTime.now().toUtc().millisecondsSinceEpoch}.pdf';
    final File file = File(p.join(reportsDirectory.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
