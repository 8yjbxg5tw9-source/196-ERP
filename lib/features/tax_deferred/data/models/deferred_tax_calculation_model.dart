import '../../domain/entities/deferred_tax_calculation_entity.dart';

/// SQLite mapping for the `deferred_tax_calculations` table.
class DeferredTaxCalculationModel extends DeferredTaxCalculationEntity {
  const DeferredTaxCalculationModel({
    required super.id,
    required super.companyId,
    required super.periodYear,
    required super.totalDta,
    required super.totalDtl,
    required super.netDeferredTaxPosition,
    required super.priorYearNetPosition,
    required super.periodDeferredTaxExpenseBenefit,
    required super.isPosted,
    super.statutoryTaxRate = 0,
    super.accountingNetProfit = 0,
    super.createdAt,
  });

  factory DeferredTaxCalculationModel.fromMap(Map<String, Object?> map) {
    return DeferredTaxCalculationModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      periodYear: _intValue(map['period_year']),
      totalDta: _doubleValue(map['total_dta']),
      totalDtl: _doubleValue(map['total_dtl']),
      netDeferredTaxPosition: _doubleValue(map['net_position']),
      priorYearNetPosition: _doubleValue(map['prior_year_net_position']),
      periodDeferredTaxExpenseBenefit:
          _doubleValue(map['period_deferred_tax_expense_benefit']),
      isPosted:
          (map['is_posted'] ?? 0) == 1 ||
              map['is_posted']?.toString() == 'true',
      statutoryTaxRate: _doubleValue(map['statutory_tax_rate']),
      accountingNetProfit: _doubleValue(map['accounting_net_profit']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory DeferredTaxCalculationModel.fromEntity(
    DeferredTaxCalculationEntity entity,
  ) {
    return DeferredTaxCalculationModel(
      id: entity.id,
      companyId: entity.companyId,
      periodYear: entity.periodYear,
      totalDta: entity.totalDta,
      totalDtl: entity.totalDtl,
      netDeferredTaxPosition: entity.netDeferredTaxPosition,
      priorYearNetPosition: entity.priorYearNetPosition,
      periodDeferredTaxExpenseBenefit:
          entity.periodDeferredTaxExpenseBenefit,
      isPosted: entity.isPosted,
      statutoryTaxRate: entity.statutoryTaxRate,
      accountingNetProfit: entity.accountingNetProfit,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'period_year': periodYear,
      'total_dta': totalDta,
      'total_dtl': totalDtl,
      'net_position': netDeferredTaxPosition,
      'prior_year_net_position': priorYearNetPosition,
      'period_deferred_tax_expense_benefit': periodDeferredTaxExpenseBenefit,
      'statutory_tax_rate': statutoryTaxRate,
      'accounting_net_profit': accountingNetProfit,
      'is_posted': isPosted ? 1 : 0,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
