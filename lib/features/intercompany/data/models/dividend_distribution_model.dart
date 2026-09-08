import '../../domain/entities/dividend_distribution_entity.dart';

/// SQLite mapping for the `dividend_distributions` table.
class DividendDistributionModel extends DividendDistributionEntity {
  const DividendDistributionModel({
    required super.id,
    required super.distributingCompanyId,
    required super.recipientEntityId,
    required super.declaredAmount,
    super.dividendTaxRate,
    super.netDividendPaid,
    required super.declarationDate,
    super.createdAt,
  });

  factory DividendDistributionModel.fromMap(Map<String, Object?> map) {
    return DividendDistributionModel(
      id: map['id']?.toString() ?? '',
      distributingCompanyId:
          map['distributing_company_id']?.toString() ?? '',
      recipientEntityId: map['recipient_entity_id']?.toString() ?? '',
      declaredAmount: _double(map['declared_amount']),
      dividendTaxRate: _double(map['dividend_tax_rate']),
      netDividendPaid: _double(map['net_dividend_paid']),
      declarationDate: DateTime.tryParse(map['declaration_date']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'distributing_company_id': distributingCompanyId,
      'recipient_entity_id': recipientEntityId,
      'declared_amount': declaredAmount,
      'dividend_tax_rate': dividendTaxRate,
      'net_dividend_paid': netDividendPaid,
      'declaration_date': declarationDate.toUtc().toIso8601String(),
      'created_at': (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
