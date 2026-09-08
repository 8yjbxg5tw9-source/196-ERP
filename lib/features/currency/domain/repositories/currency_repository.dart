import '../../../../core/errors/failures.dart';
import '../entities/currency_entity.dart';

/// Persistence + synchronization boundary for currencies and exchange rates.
abstract interface class CurrencyRepository {
  /// The configured currency catalogue (base currency first).
  Future<Result<List<CurrencyEntity>>> getCurrencies();

  /// The most recent cached rate for every target currency of [baseCurrency].
  Future<Result<List<ExchangeRateEntity>>> getLatestRates({
    String baseCurrency = 'AZN',
  });

  /// The rate applicable on [date] (latest on-or-before), or null if none is
  /// cached yet.
  Future<Result<ExchangeRateEntity?>> getRate(
    String baseCurrency,
    String targetCurrency,
    DateTime date,
  );

  /// Fetches fresh daily rates from the central-bank feed and stores them.
  /// Offline, this safely no-ops so cached rates remain authoritative.
  Future<Result<void>> syncRates();
}
