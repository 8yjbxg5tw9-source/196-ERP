import 'package:equatable/equatable.dart';

/// A compiled IAS 12 deferred tax position for one company and fiscal year.
class DeferredTaxCalculationEntity extends Equatable {
  const DeferredTaxCalculationEntity({
    required this.id,
    required this.companyId,
    required this.periodYear,
    required this.totalDta,
    required this.totalDtl,
    required this.netDeferredTaxPosition,
    required this.priorYearNetPosition,
    required this.periodDeferredTaxExpenseBenefit,
    required this.isPosted,
    this.statutoryTaxRate = 0,
    this.accountingNetProfit = 0,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final int periodYear;
  final double totalDta;
  final double totalDtl;

  /// `totalDta - totalDtl`; positive means a net deferred tax asset.
  final double netDeferredTaxPosition;
  final double priorYearNetPosition;

  /// Deferred tax expense (positive) or benefit (negative) for the period,
  /// equal to `priorYearNetPosition - netDeferredTaxPosition`.
  final double periodDeferredTaxExpenseBenefit;
  final bool isPosted;

  /// Statutory profit tax rate applied to the timing differences.
  final double statutoryTaxRate;

  /// Accounting net profit for the period, used by the ETR reconciler.
  final double accountingNetProfit;
  final DateTime? createdAt;

  double get periodAdjustment =>
      netDeferredTaxPosition - priorYearNetPosition;

  double get nominalTaxExpense => accountingNetProfit * statutoryTaxRate;

  double get effectiveTaxExpense =>
      nominalTaxExpense + periodDeferredTaxExpenseBenefit;

  DeferredTaxCalculationEntity copyWith({
    String? id,
    String? companyId,
    int? periodYear,
    double? totalDta,
    double? totalDtl,
    double? netDeferredTaxPosition,
    double? priorYearNetPosition,
    double? periodDeferredTaxExpenseBenefit,
    bool? isPosted,
    double? statutoryTaxRate,
    double? accountingNetProfit,
    DateTime? createdAt,
  }) {
    return DeferredTaxCalculationEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      periodYear: periodYear ?? this.periodYear,
      totalDta: totalDta ?? this.totalDta,
      totalDtl: totalDtl ?? this.totalDtl,
      netDeferredTaxPosition:
          netDeferredTaxPosition ?? this.netDeferredTaxPosition,
      priorYearNetPosition: priorYearNetPosition ?? this.priorYearNetPosition,
      periodDeferredTaxExpenseBenefit: periodDeferredTaxExpenseBenefit ??
          this.periodDeferredTaxExpenseBenefit,
      isPosted: isPosted ?? this.isPosted,
      statutoryTaxRate: statutoryTaxRate ?? this.statutoryTaxRate,
      accountingNetProfit: accountingNetProfit ?? this.accountingNetProfit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        periodYear,
        totalDta,
        totalDtl,
        netDeferredTaxPosition,
        priorYearNetPosition,
        periodDeferredTaxExpenseBenefit,
        isPosted,
        statutoryTaxRate,
        accountingNetProfit,
        createdAt,
      ];
}
