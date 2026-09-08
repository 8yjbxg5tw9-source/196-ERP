import '../../domain/entities/currency_entity.dart';

/// SQLite representation of a [CurrencyEntity].
class CurrencyModel extends CurrencyEntity {
  const CurrencyModel({
    required super.code,
    required super.name,
    required super.symbol,
    required super.isBase,
  });

  factory CurrencyModel.fromMap(Map<String, Object?> map) {
    return CurrencyModel(
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      symbol: map['symbol']?.toString() ?? '',
      isBase: map['is_base'] == 1 || map['is_base'] == '1',
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code,
      'name': name,
      'symbol': symbol,
      'is_base': isBase ? 1 : 0,
    };
  }
}
