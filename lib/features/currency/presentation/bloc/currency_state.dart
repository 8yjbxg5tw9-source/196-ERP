import 'package:equatable/equatable.dart';

import '../../domain/entities/currency_entity.dart';

abstract class CurrencyState extends Equatable {
  const CurrencyState();

  @override
  List<Object?> get props => const <Object?>[];
}

class CurrencyInitial extends CurrencyState {
  const CurrencyInitial();
}

class CurrencyLoading extends CurrencyState {
  const CurrencyLoading();
}

class CurrencyRatesLoaded extends CurrencyState {
  const CurrencyRatesLoaded({
    required this.rates,
    required this.baseCurrency,
    required this.asOf,
    required this.source,
  });

  final List<ExchangeRateEntity> rates;
  final String baseCurrency;

  /// The most recent rate date across the loaded set.
  final DateTime? asOf;
  final String source;

  @override
  List<Object?> get props => <Object?>[rates, baseCurrency, asOf, source];
}

class CurrencyError extends CurrencyState {
  const CurrencyError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
