import '../../domain/entities/currency_entity.dart';

/// SQLite representation of an [ExchangeRateEntity].
class ExchangeRateModel extends ExchangeRateEntity {
  const ExchangeRateModel({
    required super.id,
    required super.baseCurrency,
    required super.targetCurrency,
    required super.rate,
    required super.rateDate,
    required super.source,
  });

  factory ExchangeRateModel.fromMap(Map<String, Object?> map) {
    final String dateValue = map['rate_date']?.toString() ?? '';
    final DateTime? parsed = DateTime.tryParse(dateValue);
    return ExchangeRateModel(
      id: map['id']?.toString() ?? '',
      baseCurrency: map['base_currency']?.toString() ?? '',
      targetCurrency: map['target_currency']?.toString() ?? '',
      rate: _double(map['rate']) ?? 0,
      rateDate: parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: map['source']?.toString() ?? 'CentralBank',
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'base_currency': baseCurrency,
      'target_currency': targetCurrency,
      'rate': rate,
      'rate_date': _dateKey(rateDate),
      'source': source,
    };
  }

  static double? _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return value == null ? null : double.tryParse(value.toString());
  }

  static String _dateKey(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
