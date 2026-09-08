import '../../domain/entities/interest_schedule_entity.dart';

/// SQLite mapping for the `interest_schedules` table.
class InterestScheduleModel extends InterestScheduleEntity {
  const InterestScheduleModel({
    required super.id,
    required super.loanId,
    required super.periodDate,
    required super.grossInterest,
    required super.withholdingTax,
    required super.netInterest,
    super.isAccrued,
    super.createdAt,
  });

  factory InterestScheduleModel.fromMap(Map<String, Object?> map) {
    return InterestScheduleModel(
      id: map['id']?.toString() ?? '',
      loanId: map['loan_id']?.toString() ?? '',
      periodDate: DateTime.tryParse(map['period_date']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      grossInterest: _double(map['gross_interest']),
      withholdingTax: _double(map['withholding_tax']),
      netInterest: _double(map['net_interest']),
      isAccrued:
          map['is_accrued'] == 1 || map['is_accrued']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'loan_id': loanId,
      'period_date': periodDate.toUtc().toIso8601String(),
      'gross_interest': grossInterest,
      'withholding_tax': withholdingTax,
      'net_interest': netInterest,
      'is_accrued': isAccrued ? 1 : 0,
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
