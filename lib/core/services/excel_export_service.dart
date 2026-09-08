import 'package:excel/excel.dart';

import 'export_models.dart';

/// Builds styled multi-sheet `.xlsx` workbooks for financial exports.
class ExcelExportService {
  const ExcelExportService();

  static const CellStyle _headerStyle = CellStyle(
    bold: true,
    backgroundColorHex: '#EEF2F7',
  );

  static const CustomNumericNumFormat _moneyFormat =
      CustomNumericNumFormat('#,##0.00');

  List<int> build(
    List<TransactionEntity> transactions, {
    ExportSummary? summary,
    TaxBreakdown? tax,
  }) {
    final Excel excel = Excel.createExcel();
    excel.rename('Sheet1', 'Executive Summary');

    _buildSummarySheet(excel['Executive Summary'], summary);
    _buildJournalSheet(excel['Journal'], transactions);
    _buildTaxSheet(excel['Tax Calculation'], tax);

    final List<int>? bytes = excel.save();
    if (bytes == null) {
      throw StateError('Excel workbook serialization returned no bytes.');
    }
    return bytes;
  }

  void _buildSummarySheet(Sheet sheet, ExportSummary? summary) {
    final List<List<CellValue?>> rows = <List<CellValue?>>[
      <CellValue?>[TextCellValue('Executive Summary')],
      <CellValue?>[
        TextCellValue('Period'),
        TextCellValue(summary?.periodLabel ?? ''),
      ],
    ];
    for (final ReportMetric metric in summary?.metrics ?? const <ReportMetric>[]) {
      rows.add(<CellValue?>[
        TextCellValue(metric.label),
        TextCellValue(metric.value),
      ]);
    }

    for (int index = 0; index < rows.length; index++) {
      sheet.appendRow(rows[index]);
    }
    _styleCell(sheet, 0, 0, _headerStyle);
    _styleCell(sheet, 1, 0, _headerStyle);
    sheet.setColumnAutoFit(0);
    sheet.setColumnAutoFit(1);
  }

  void _buildJournalSheet(Sheet sheet, List<TransactionEntity> transactions) {
    final List<CellValue?> header = <CellValue?>[
      TextCellValue('Date'),
      TextCellValue('VÖEN'),
      TextCellValue('Vendor'),
      TextCellValue('Account Code'),
      TextCellValue('Debit'),
      TextCellValue('Credit'),
      TextCellValue('Status'),
    ];
    sheet.appendRow(header);
    for (int column = 0; column < header.length; column++) {
      _styleCell(sheet, 0, column, _headerStyle);
    }

    for (int index = 0; index < transactions.length; index++) {
      final TransactionEntity transaction = transactions[index];
      sheet.appendRow(<CellValue?>[
        TextCellValue(_dateLabel(transaction.date)),
        TextCellValue(transaction.voen ?? ''),
        TextCellValue(transaction.vendor ?? ''),
        TextCellValue(transaction.accountCode ?? ''),
        DoubleCellValue(transaction.debit),
        DoubleCellValue(transaction.credit),
        TextCellValue(transaction.status),
      ]);
      final int row = index + 1;
      _applyMoneyFormat(sheet, row, 4);
      _applyMoneyFormat(sheet, row, 5);
    }

    for (int column = 0; column < header.length; column++) {
      sheet.setColumnAutoFit(column);
    }
  }

  void _buildTaxSheet(Sheet sheet, TaxBreakdown? tax) {
    final TaxBreakdown values = tax ?? const TaxBreakdown();
    final List<List<CellValue?>> rows = <List<CellValue?>>[
      <CellValue?>[TextCellValue('Tax Calculation'), TextCellValue('')],
      <CellValue?>[
        TextCellValue('Total revenue'),
        DoubleCellValue(values.totalRevenue),
      ],
      <CellValue?>[
        TextCellValue('Taxable income'),
        DoubleCellValue(values.taxableIncome),
      ],
      <CellValue?>[
        TextCellValue('Output VAT'),
        DoubleCellValue(values.outputVat),
      ],
      <CellValue?>[
        TextCellValue('Input VAT'),
        DoubleCellValue(values.inputVat),
      ],
      <CellValue?>[
        TextCellValue('VAT calculated'),
        DoubleCellValue(values.vatCalculated),
      ],
    ];

    for (int index = 0; index < rows.length; index++) {
      sheet.appendRow(rows[index]);
      _applyMoneyFormat(sheet, index, 1);
    }
    _styleCell(sheet, 0, 0, _headerStyle);
    sheet.setColumnAutoFit(0);
    sheet.setColumnAutoFit(1);
  }

  void _styleCell(Sheet sheet, int row, int column, CellStyle style) {
    final Data? cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    if (cell != null) {
      cell.cellStyle = style;
    }
  }

  void _applyMoneyFormat(Sheet sheet, int row, int column) {
    final Data? cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    if (cell != null) {
      cell.cellStyle =
          (cell.cellStyle ?? const CellStyle()).copyWith(
            numberFormat: _moneyFormat,
          );
    }
  }

  static String _dateLabel(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}
