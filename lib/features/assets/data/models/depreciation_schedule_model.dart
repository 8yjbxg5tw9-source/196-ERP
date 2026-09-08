import '../../domain/entities/depreciation_schedule_entity.dart';

/// SQLite mapping for the `depreciation_schedules` table.
class DepreciationScheduleModel extends DepreciationScheduleEntity {
  const DepreciationScheduleModel({
    required super.id,
    required super.assetId,
    required super.companyId,
    required super.periodDate,
    required super.depreciationAmount,
    required super.accumulatedAmount,
    required super.endingBookValue,
    super.isPosted = false,
    super.createdAt,
  });

  factory DepreciationScheduleModel.fromMap(Map<String, Object?> map) {
    return DepreciationScheduleModel(
      id: map['id']?.toString() ?? '',
      assetId: map['asset_id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      periodDate:
          DateTime.tryParse(map['period_date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      depreciationAmount: _doubleValue(map['depreciation_amount']),
      accumulatedAmount: _doubleValue(map['accumulated_amount']),
      endingBookValue: _doubleValue(map['ending_book_value']),
      isPosted: (map['is_posted'] ?? 0) == 1 ||
          map['is_posted']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory DepreciationScheduleModel.fromEntity(
    DepreciationScheduleEntity entity,
  ) {
    return DepreciationScheduleModel(
      id: entity.id,
      assetId: entity.assetId,
      companyId: entity.companyId,
      periodDate: entity.periodDate,
      depreciationAmount: entity.depreciationAmount,
      accumulatedAmount: entity.accumulatedAmount,
      endingBookValue: entity.endingBookValue,
      isPosted: entity.isPosted,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'asset_id': assetId,
      'company_id': companyId,
      'period_date': periodDate.toUtc().toIso8601String(),
      'depreciation_amount': depreciationAmount,
      'accumulated_amount': accumulatedAmount,
      'ending_book_value': endingBookValue,
      'is_posted': isPosted ? 1 : 0,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
