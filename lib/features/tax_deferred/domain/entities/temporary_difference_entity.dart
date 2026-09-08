import 'package:equatable/equatable.dart';

/// IAS 12 classification of a timing difference.
enum TemporaryDifferenceType { taxableTemporary, deductibleTemporary }

extension TemporaryDifferenceTypeLabel on TemporaryDifferenceType {
  String get label => switch (this) {
        TemporaryDifferenceType.taxableTemporary =>
          'Taxable temporary difference',
        TemporaryDifferenceType.deductibleTemporary =>
          'Deductible temporary difference',
      };
}

/// Whether the timing difference yields a deferred tax asset or liability.
enum DeferredTaxType { deferredTaxAsset, deferredTaxLiability }

extension DeferredTaxTypeLabel on DeferredTaxType {
  String get label => switch (this) {
        DeferredTaxType.deferredTaxAsset => 'Deferred Tax Asset',
        DeferredTaxType.deferredTaxLiability => 'Deferred Tax Liability',
      };

  String get shortLabel => switch (this) {
        DeferredTaxType.deferredTaxAsset => 'DTA',
        DeferredTaxType.deferredTaxLiability => 'DTL',
      };
}

/// One itemized accounting-vs-tax temporary difference and its deferred tax
/// consequence. [temporaryDifferenceAmount] is the absolute book/tax gap and
/// [deferredAmount] is that gap multiplied by the statutory rate.
class TemporaryDifferenceEntity extends Equatable {
  const TemporaryDifferenceEntity({
    required this.id,
    required this.companyId,
    required this.calculationId,
    required this.assetLiabilityName,
    required this.accountingBookValue,
    required this.taxCarryingBase,
    required this.differenceType,
    required this.temporaryDifferenceAmount,
    required this.statutoryTaxRate,
    required this.deferredTaxType,
    required this.deferredAmount,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String calculationId;
  final String assetLiabilityName;
  final double accountingBookValue;
  final double taxCarryingBase;
  final TemporaryDifferenceType differenceType;
  final double temporaryDifferenceAmount;
  final double statutoryTaxRate;
  final DeferredTaxType deferredTaxType;
  final double deferredAmount;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        calculationId,
        assetLiabilityName,
        accountingBookValue,
        taxCarryingBase,
        differenceType,
        temporaryDifferenceAmount,
        statutoryTaxRate,
        deferredTaxType,
        deferredAmount,
        createdAt,
      ];
}
