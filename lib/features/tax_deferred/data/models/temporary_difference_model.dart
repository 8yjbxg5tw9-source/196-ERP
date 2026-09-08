import '../../domain/entities/temporary_difference_entity.dart';

/// SQLite mapping for the `temporary_differences` table.
class TemporaryDifferenceModel extends TemporaryDifferenceEntity {
  const TemporaryDifferenceModel({
    required super.id,
    required super.companyId,
    required super.calculationId,
    required super.assetLiabilityName,
    required super.accountingBookValue,
    required super.taxCarryingBase,
    required super.differenceType,
    required super.temporaryDifferenceAmount,
    required super.statutoryTaxRate,
    required super.deferredTaxType,
    required super.deferredAmount,
    super.createdAt,
  });

  factory TemporaryDifferenceModel.fromMap(Map<String, Object?> map) {
    return TemporaryDifferenceModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      calculationId: map['calculation_id']?.toString() ?? '',
      assetLiabilityName: map['asset_liability_name']?.toString() ?? '',
      accountingBookValue: _doubleValue(map['accounting_book_value']),
      taxCarryingBase: _doubleValue(map['tax_carrying_base']),
      differenceType: _differenceTypeFrom(map['difference_type']),
      temporaryDifferenceAmount:
          _doubleValue(map['temporary_difference_amount']),
      statutoryTaxRate: _doubleValue(map['statutory_tax_rate']),
      deferredTaxType: _deferredTaxTypeFrom(map['deferred_tax_type']),
      deferredAmount: _doubleValue(map['deferred_amount']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory TemporaryDifferenceModel.fromEntity(
    TemporaryDifferenceEntity entity,
  ) {
    return TemporaryDifferenceModel(
      id: entity.id,
      companyId: entity.companyId,
      calculationId: entity.calculationId,
      assetLiabilityName: entity.assetLiabilityName,
      accountingBookValue: entity.accountingBookValue,
      taxCarryingBase: entity.taxCarryingBase,
      differenceType: entity.differenceType,
      temporaryDifferenceAmount: entity.temporaryDifferenceAmount,
      statutoryTaxRate: entity.statutoryTaxRate,
      deferredTaxType: entity.deferredTaxType,
      deferredAmount: entity.deferredAmount,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'calculation_id': calculationId,
      'asset_liability_name': assetLiabilityName,
      'accounting_book_value': accountingBookValue,
      'tax_carrying_base': taxCarryingBase,
      'difference_type': differenceType.name,
      'temporary_difference_amount': temporaryDifferenceAmount,
      'statutory_tax_rate': statutoryTaxRate,
      'deferred_tax_type': deferredTaxType.name,
      'deferred_amount': deferredAmount,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static TemporaryDifferenceType _differenceTypeFrom(Object? value) {
    return value?.toString() == TemporaryDifferenceType.taxableTemporary.name
        ? TemporaryDifferenceType.taxableTemporary
        : TemporaryDifferenceType.deductibleTemporary;
  }

  static DeferredTaxType _deferredTaxTypeFrom(Object? value) {
    return value?.toString() == DeferredTaxType.deferredTaxLiability.name
        ? DeferredTaxType.deferredTaxLiability
        : DeferredTaxType.deferredTaxAsset;
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
