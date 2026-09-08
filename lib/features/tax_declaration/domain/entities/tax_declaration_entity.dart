import 'package:equatable/equatable.dart';

/// Statutory e-filing declaration forms supported by the exporter.
enum TaxDeclarationType { vat2026, profitTax, simplifiedTax, payrollDsmf }

extension TaxDeclarationTypeLabel on TaxDeclarationType {
  String get label => switch (this) {
        TaxDeclarationType.vat2026 => 'ƏDV Bəyannaməsi',
        TaxDeclarationType.profitTax => 'Mənfəət Vergisi Bəyannaməsi',
        TaxDeclarationType.simplifiedTax => 'Sadələşdirilmiş Vergi Bəyannaməsi',
        TaxDeclarationType.payrollDsmf => 'DSMF İşçi Hesabatı',
      };

  String get shortCode => switch (this) {
        TaxDeclarationType.vat2026 => 'EDV',
        TaxDeclarationType.profitTax => 'PROFIT',
        TaxDeclarationType.simplifiedTax => 'SIMPLE',
        TaxDeclarationType.payrollDsmf => 'DSMF',
      };

  /// The statutory filing cadence for this form.
  TaxPeriod get defaultPeriod => switch (this) {
        TaxDeclarationType.vat2026 => TaxPeriod.monthly,
        TaxDeclarationType.profitTax => TaxPeriod.annual,
        TaxDeclarationType.simplifiedTax => TaxPeriod.quarterly,
        TaxDeclarationType.payrollDsmf => TaxPeriod.monthly,
      };
}

/// Filing cadence of a declaration form.
enum TaxPeriod { monthly, quarterly, annual }

extension TaxPeriodLabel on TaxPeriod {
  String get label => switch (this) {
        TaxPeriod.monthly => 'Monthly',
        TaxPeriod.quarterly => 'Quarterly',
        TaxPeriod.annual => 'Annual',
      };

  int get monthSpan => switch (this) {
        TaxPeriod.monthly => 1,
        TaxPeriod.quarterly => 3,
        TaxPeriod.annual => 12,
      };
}

/// A compiled statutory tax declaration ready for XML export.
///
/// The turnover/VAT fields are reused across declaration types: [taxableTurnover]
/// carries the taxable base (turnover for VAT/simplified, profit for profit
/// tax, gross payroll for DSMF), [vatCalculated] the calculated tax, and
/// [netVatPayable] the net payable amount.
class TaxDeclarationEntity extends Equatable {
  const TaxDeclarationEntity({
    required this.id,
    required this.companyId,
    required this.declarationType,
    required this.taxPeriod,
    required this.periodYear,
    required this.periodQuarterMonth,
    required this.voen,
    required this.taxAuthorityCode,
    this.taxableTurnover = 0,
    this.zeroRatedTurnover = 0,
    this.exemptTurnover = 0,
    this.vatCalculated = 0,
    this.vatDeductible = 0,
    this.netVatPayable = 0,
    this.rawXmlOutput,
    this.isValidated = false,
  });

  final String id;
  final String companyId;
  final TaxDeclarationType declarationType;
  final TaxPeriod taxPeriod;
  final int periodYear;

  /// Month (1–12) for monthly, quarter (1–4) for quarterly, 1 for annual.
  final int periodQuarterMonth;
  final String voen;
  final String taxAuthorityCode;

  final double taxableTurnover;
  final double zeroRatedTurnover;
  final double exemptTurnover;
  final double vatCalculated;
  final double vatDeductible;
  final double netVatPayable;

  final String? rawXmlOutput;
  final bool isValidated;

  TaxDeclarationEntity copyWith({
    double? taxableTurnover,
    double? zeroRatedTurnover,
    double? exemptTurnover,
    double? vatCalculated,
    double? vatDeductible,
    double? netVatPayable,
    String? rawXmlOutput,
    bool? isValidated,
  }) {
    return TaxDeclarationEntity(
      id: id,
      companyId: companyId,
      declarationType: declarationType,
      taxPeriod: taxPeriod,
      periodYear: periodYear,
      periodQuarterMonth: periodQuarterMonth,
      voen: voen,
      taxAuthorityCode: taxAuthorityCode,
      taxableTurnover: taxableTurnover ?? this.taxableTurnover,
      zeroRatedTurnover: zeroRatedTurnover ?? this.zeroRatedTurnover,
      exemptTurnover: exemptTurnover ?? this.exemptTurnover,
      vatCalculated: vatCalculated ?? this.vatCalculated,
      vatDeductible: vatDeductible ?? this.vatDeductible,
      netVatPayable: netVatPayable ?? this.netVatPayable,
      rawXmlOutput: rawXmlOutput ?? this.rawXmlOutput,
      isValidated: isValidated ?? this.isValidated,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        declarationType,
        taxPeriod,
        periodYear,
        periodQuarterMonth,
        voen,
        taxAuthorityCode,
        taxableTurnover,
        zeroRatedTurnover,
        exemptTurnover,
        vatCalculated,
        vatDeductible,
        netVatPayable,
        rawXmlOutput,
        isValidated,
      ];
}
