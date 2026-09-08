import '../../../../core/errors/failures.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/repositories/currency_repository.dart';
import '../../domain/services/currency_conversion_service.dart';

/// Base-currency conversion and FX gain/loss engine backed by the local rate
/// cache, so every calculation works offline.
class CurrencyConversionServiceImpl implements CurrencyConversionService {
  CurrencyConversionServiceImpl({
    required CurrencyRepository repository,
    this.baseCurrency = 'AZN',
  }) : _repository = repository;

  final CurrencyRepository _repository;
  final String baseCurrency;

  @override
  Future<double> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required DateTime date,
  }) async {
    if (amount == 0) {
      return 0;
    }
    final String from = fromCurrency.toUpperCase();
    final String to = toCurrency.toUpperCase();
    if (from == to) {
      return amount;
    }

    final double inBase;
    if (from == baseCurrency) {
      inBase = amount;
    } else {
      final double rate = await _rate(baseCurrency, from, date);
      inBase = amount * rate;
    }

    if (to == baseCurrency) {
      return inBase;
    }
    final double toRate = await _rate(baseCurrency, to, date);
    return inBase / toRate;
  }

  @override
  Future<void> syncExchangeRates() async {
    await _repository.syncRates();
  }

  @override
  Future<double> calculateFxGainLoss({
    required double originalAmount,
    required String currency,
    required DateTime transactionDate,
    required DateTime settlementDate,
  }) async {
    final String code = currency.toUpperCase();
    if (code == baseCurrency || originalAmount == 0) {
      return 0;
    }
    final double transactionRate = await _rate(
      baseCurrency,
      code,
      transactionDate,
    );
    final double settlementRate = await _rate(baseCurrency, code, settlementDate);
    return originalAmount * (settlementRate - transactionRate);
  }

  Future<double> _rate(
    String base,
    String target,
    DateTime date,
  ) async {
    final Either<Failure, ExchangeRateEntity?> result = await _repository.getRate(
      base,
      target,
      date,
    );
    final ExchangeRateEntity? rate = result.fold(
      (Failure failure) => throw StateError(failure.message),
      (ExchangeRateEntity? value) => value,
    );
    if (rate == null) {
      throw StateError(
        'No cached $base→$target rate on or before $date. '
        'Sync exchange rates first.',
      );
    }
    return rate.rate;
  }
}
