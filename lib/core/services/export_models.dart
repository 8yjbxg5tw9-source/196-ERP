import '../../features/company/domain/entities/company_entity.dart';

/// One headline figure rendered on a report cover or executive summary.
class ReportMetric {
  const ReportMetric({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
}

/// A single line in a report table section.
class ReportRow {
  const ReportRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;
}

/// A titled block of report rows (e.g. "Operating expenses").
class ReportSection {
  const ReportSection({required this.title, this.rows = const <ReportRow>[]});

  final String title;
  final List<ReportRow> rows;
}

/// Payload consumed by [PdfGeneratorService] and the Excel executive summary.
class ReportData {
  const ReportData({
    this.company,
    required this.title,
    this.periodLabel,
    this.currency = 'AZN',
    this.metrics = const <ReportMetric>[],
    this.sections = const <ReportSection>[],
  });

  final CompanyEntity? company;
  final String title;
  final String? periodLabel;
  final String currency;
  final List<ReportMetric> metrics;
  final List<ReportSection> sections;
}

/// A normalized ledger line used for Excel journal exports.
class TransactionEntity {
  const TransactionEntity({
    required this.date,
    required this.description,
    this.voen,
    this.vendor,
    this.accountCode,
    this.debit = 0,
    this.credit = 0,
    this.status = '',
  });

  final DateTime date;
  final String description;
  final String? voen;
  final String? vendor;
  final String? accountCode;
  final double debit;
  final double credit;
  final String status;
}

/// Aggregated figures for the workbook's executive-summary sheet.
class ExportSummary {
  const ExportSummary({
    required this.periodLabel,
    this.metrics = const <ReportMetric>[],
  });

  final String periodLabel;
  final List<ReportMetric> metrics;
}

/// VAT and profit figures for the workbook's tax-calculation sheet.
class TaxBreakdown {
  const TaxBreakdown({
    this.totalRevenue = 0,
    this.taxableIncome = 0,
    this.vatCalculated = 0,
    this.outputVat = 0,
    this.inputVat = 0,
  });

  final double totalRevenue;
  final double taxableIncome;
  final double vatCalculated;
  final double outputVat;
  final double inputVat;
}

/// The two official e-filing declaration formats.
enum TaxDeclarationType { vat, profitTax }
