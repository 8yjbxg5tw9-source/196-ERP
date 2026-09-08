import 'package:xml/xml.dart';

import '../entities/tax_declaration_entity.dart';
import '../entities/xml_validation_issue.dart';

/// Builds and validates statutory e-Bəyannamə XML declarations against the
/// Dövlət Vergi Xidməti filing structure.
///
/// Pre-validation runs before file generation: a 10-digit VÖEN, consistent
/// filing periods, and the mathematical balance between turnover and the
/// calculated tax amounts must hold before an `.xml` file is written.
class TaxXmlEngine {
  const TaxXmlEngine();

  static final RegExp _voenPattern = RegExp(r'^\d{10}$');
  static const double _epsilon = 0.01;
  static const double _vatRate = 0.18;

  /// Serializes [declaration] into the statutory `<Beyanname>` document.
  String buildXml(TaxDeclarationEntity declaration) {
    final XmlBuilder builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.element(
      'Beyanname',
      attributes: const <String, String>{'type': 'EDV', 'version': '2026.1'},
      nest: () {
        builder.element('Header', nest: () {
          builder.element('VOEN', nest: declaration.voen);
          builder.element('PeriodYear', nest: '${declaration.periodYear}');
          builder.element(
            'PeriodMonth',
            nest: _periodValue(declaration),
          );
          builder.element(
            'TaxAuthorityCode',
            nest: declaration.taxAuthorityCode,
          );
        });
        builder.element('Body', nest: () {
          builder.element('Section1', nest: () {
            _buildSection1(builder, declaration);
          });
        });
      },
    );
    final XmlDocument document = builder.buildDocument();
    return document.toXmlString(pretty: true, indent: '  ');
  }

  void _buildSection1(XmlBuilder builder, TaxDeclarationEntity declaration) {
    switch (declaration.declarationType) {
      case TaxDeclarationType.vat2026:
        builder.element(
          'TaxableTurnover18',
          nest: _money(declaration.taxableTurnover),
        );
        builder.element(
          'ZeroRatedTurnover',
          nest: _money(declaration.zeroRatedTurnover),
        );
        builder.element(
          'ExemptTurnover',
          nest: _money(declaration.exemptTurnover),
        );
        builder.element(
          'CalculatedVat18',
          nest: _money(declaration.vatCalculated),
        );
        builder.element(
          'DeductibleVat',
          nest: _money(declaration.vatDeductible),
        );
        builder.element(
          'NetPayableVat',
          nest: _money(declaration.netVatPayable),
        );
        break;
      case TaxDeclarationType.profitTax:
        builder.element(
          'TaxableProfit',
          nest: _money(declaration.taxableTurnover),
        );
        builder.element(
          'CalculatedProfitTax',
          nest: _money(declaration.vatCalculated),
        );
        builder.element('Credits', nest: _money(declaration.vatDeductible));
        builder.element(
          'NetPayableTax',
          nest: _money(declaration.netVatPayable),
        );
        break;
      case TaxDeclarationType.simplifiedTax:
        builder.element(
          'TaxableTurnover2',
          nest: _money(declaration.taxableTurnover),
        );
        builder.element(
          'CalculatedSimplifiedTax',
          nest: _money(declaration.vatCalculated),
        );
        builder.element(
          'NetPayableTax',
          nest: _money(declaration.netVatPayable),
        );
        break;
      case TaxDeclarationType.payrollDsmf:
        builder.element(
          'GrossPayroll',
          nest: _money(declaration.taxableTurnover),
        );
        builder.element(
          'DsmfContributions',
          nest: _money(declaration.vatCalculated),
        );
        break;
    }
  }

  /// Pre-submission validation of the mandatory statutory fields.
  List<XmlValidationIssue> validateDeclaration(TaxDeclarationEntity declaration) {
    final List<XmlValidationIssue> issues = <XmlValidationIssue>[];

    if (!_voenPattern.hasMatch(declaration.voen.trim())) {
      issues.add(
        XmlValidationIssue(
          field: 'VOEN',
          message: 'VÖEN must be exactly 10 digits.',
        ),
      );
    }

    if (declaration.taxAuthorityCode.trim().isEmpty) {
      issues.add(
        const XmlValidationIssue(
          field: 'TaxAuthorityCode',
          message: 'Tax authority code is missing.',
        ),
      );
    }

    if (declaration.periodYear < 2000 || declaration.periodYear > 2100) {
      issues.add(
        XmlValidationIssue(
          field: 'PeriodYear',
          message: 'Period year ${declaration.periodYear} is out of range.',
        ),
      );
    }

    if (!_validPeriodValue(declaration)) {
      issues.add(
        XmlValidationIssue(
          field: 'PeriodMonth',
          message: 'Period value ${declaration.periodQuarterMonth} is invalid '
              'for a ${declaration.taxPeriod.label.toLowerCase()} filing.',
        ),
      );
    }

    final double expectedTax = declaration.taxableTurnover * _vatRate;
    if (declaration.declarationType == TaxDeclarationType.vat2026 &&
        declaration.taxableTurnover > 0 &&
        (declaration.vatCalculated - expectedTax).abs() > _epsilon) {
      issues.add(
        XmlValidationIssue(
          field: 'CalculatedVat18',
          message: 'Calculated VAT does not balance with taxable turnover '
              '(expected ${_money(expectedTax)}, got '
              '${_money(declaration.vatCalculated)}).',
          severity: XmlValidationSeverity.warning,
        ),
      );
    }

    final double netDifference =
        declaration.vatCalculated - declaration.vatDeductible;
    if ((declaration.netVatPayable - netDifference).abs() > _epsilon) {
      issues.add(
        XmlValidationIssue(
          field: 'NetPayableVat',
          message: 'Net payable does not equal calculated tax minus '
              'deductible tax.',
          severity: XmlValidationSeverity.warning,
        ),
      );
    }

    return issues;
  }

  /// Structural validation of an already-serialized declaration document.
  List<XmlValidationIssue> validateXml(String xmlContent) {
    final String content = xmlContent.trim();
    if (content.isEmpty) {
      return const <XmlValidationIssue>[
        XmlValidationIssue(
          field: 'document',
          message: 'The XML document is empty.',
        ),
      ];
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException catch (error) {
      return <XmlValidationIssue>[
        XmlValidationIssue(
          field: 'document',
          message: 'The XML document is malformed: ${error.message}',
        ),
      ];
    }

    final List<XmlValidationIssue> issues = <XmlValidationIssue>[];
    final XmlElement? root = document.rootElement;
    if (root == null || root.name.local != 'Beyanname') {
      issues.add(
        const XmlValidationIssue(
          field: 'document',
          message: 'The root element must be <Beyanname>.',
        ),
      );
      return issues;
    }

    final Iterable<XmlElement> headers = root.findAllElements('Header');
    if (headers.isEmpty) {
      issues.add(
        const XmlValidationIssue(
          field: 'Header',
          message: 'The <Header> section is missing.',
        ),
      );
    } else {
      issues.addAll(_validateHeader(headers.first));
    }

    if (root.findAllElements('Body').isEmpty) {
      issues.add(
        const XmlValidationIssue(
          field: 'Body',
          message: 'The <Body> section is missing.',
        ),
      );
    }
    return issues;
  }

  List<XmlValidationIssue> _validateHeader(XmlElement header) {
    final List<XmlValidationIssue> issues = <XmlValidationIssue>[];
    for (final String field in const <String>[
      'VOEN',
      'PeriodYear',
      'PeriodMonth',
      'TaxAuthorityCode',
    ]) {
      final Iterable<XmlElement> matches = header.findElements(field);
      final XmlElement? node = matches.isEmpty ? null : matches.first;
      if (node == null || node.innerText.trim().isEmpty) {
        issues.add(
          XmlValidationIssue(
            field: field,
            message: 'The <$field> field is missing or empty.',
          ),
        );
      }
    }
    return issues;
  }

  static bool _validPeriodValue(TaxDeclarationEntity declaration) {
    switch (declaration.taxPeriod) {
      case TaxPeriod.monthly:
        return declaration.periodQuarterMonth >= 1 &&
            declaration.periodQuarterMonth <= 12;
      case TaxPeriod.quarterly:
        return declaration.periodQuarterMonth >= 1 &&
            declaration.periodQuarterMonth <= 4;
      case TaxPeriod.annual:
        return declaration.periodQuarterMonth == 1 ||
            declaration.periodQuarterMonth == 0;
    }
  }

  static String _periodValue(TaxDeclarationEntity declaration) {
    final int value = declaration.periodQuarterMonth;
    return value.toString().padLeft(2, '0');
  }

  static String _money(double value) {
    return value.toStringAsFixed(2);
  }
}
