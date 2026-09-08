import 'package:equatable/equatable.dart';

/// A supported ledger currency.
class CurrencyEntity extends Equatable {
  const CurrencyEntity({
    required this.code,
    required this.name,
    required this.symbol,
    required this.isBase,
  });

  final String code;
  final String name;
  final String symbol;
  final bool isBase;

  @override
  List<Object?> get props => <Object?>[code, name, symbol, isBase];
}

/// A single daily exchange rate: [baseCurrency] units per one unit of
/// [targetCurrency] (e.g. `rate = 1.7000` AZN per 1 USD).
class ExchangeRateEntity extends Equatable {
  const ExchangeRateEntity({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.rateDate,
    required this.source,
  });

  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final DateTime rateDate;
  final String source;

  @override
  List<Object?> get props =>
      <Object?>[id, baseCurrency, targetCurrency, rate, rateDate, source];
}
