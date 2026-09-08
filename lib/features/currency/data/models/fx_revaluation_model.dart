import '../../domain/revaluation/fx_revaluation_entity.dart';

/// SQLite mapping for the `fx_revaluations` table.
class FxRevaluationModel extends FxRevaluationEntity {
  const FxRevaluationModel({
    required super.id,
    required super.companyId,
    required super.revaluationDate,
    required super.periodMonth,
    required super.periodYear,
    super.totalUnrealizedGain,
    super.totalUnrealizedLoss,
    super.netFxImpact,
    super.isPosted,
    super.createdAt,
  });

  factory FxRevaluationModel.fromMap(Map<String, Object?> map) {
    return FxRevaluationModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      revaluationDate:
          DateTime.tryParse(map['revaluation_date']?.toString() ?? '') ??
              DateTime.now().toUtc(),
      periodMonth: int.tryParse(map['period_month']?.toString() ?? '') ?? 1,
      periodYear: int.tryParse(map['period_year']?.toString() ?? '') ?? 2024,
      totalUnrealizedGain: _double(map['total_unrealized_gain']),
      totalUnrealizedLoss: _double(map['total_unrealized_loss']),
      netFxImpact: _double(map['net_fx_impact']),
      isPosted:
          map['is_posted'] == 1 || map['is_posted']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'revaluation_date': revaluationDate.toUtc().toIso8601String(),
      'period_month': periodMonth,
      'period_year': periodYear,
      'total_unrealized_gain': totalUnrealizedGain,
      'total_unrealized_loss': totalUnrealizedLoss,
      'net_fx_impact': netFxImpact,
      'is_posted': isPosted ? 1 : 0,
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
