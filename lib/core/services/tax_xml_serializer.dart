import 'package:xml/xml.dart';

import '../../features/analytics/domain/entities/profit_and_loss_entity.dart';
import '../../features/company/domain/entities/company_entity.dart';
import 'export_models.dart';

/// Serializes computed statements into the XML trees used by the e-tax
/// authority filing systems (ƏDV/VAT bəyannaməsi and mənfəət vergisi).
class TaxXmlSerializer {
  const TaxXmlSerializer();

  /// Builds the declaration XML for [company] over [report]'s period.
  String serialize(
    CompanyEntity company,
    ProfitAndLossEntity report, {
    TaxDeclarationType type = TaxDeclarationType.vat,
  }) {
    final DateTime period = report.dateRange.end;
    final int month = period.month;
    final int year = period.year;

    final XmlBuilder builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    if (type == TaxDeclarationType.profitTax) {
      builder.element('ProfitTaxDeclaration', nest: () {
        _header(builder, company.voenTin, month, year);
        builder.element('FinancialData', nest: () {
          _decimalElement(builder, 'TaxableIncome', report.netProfit);
          _decimalElement(builder, 'TaxRate', 20);
          _decimalElement(builder, 'TaxCalculated', report.netProfit * 0.20);
        });
      });
    } else {
      builder.element('Declaration', nest: () {
        _header(builder, company.voenTin, month, year);
        builder.element('FinancialData', nest: () {
          _decimalElement(builder, 'TotalRevenue', report.totalRevenue);
          _decimalElement(builder, 'TaxableIncome', report.netProfit);
          _decimalElement(builder, 'VatCalculated', report.netPayableVat);
        });
      });
    }
    final XmlDocument document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  static void _header(
    XmlBuilder builder,
    String voen,
    int month,
    int year,
  ) {
    builder.element('Header', nest: () {
      builder.element('VOEN', nest: () => builder.text(voen));
      builder.element('PeriodMonth', nest: () => builder.text(month.toString()));
      builder.element('PeriodYear', nest: () => builder.text(year.toString()));
    });
  }

  static void _decimalElement(XmlBuilder builder, String name, double value) {
    builder.element(name, nest: () => builder.text(value.toStringAsFixed(2)));
  }
}
