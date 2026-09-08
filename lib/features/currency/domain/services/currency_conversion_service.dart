/// Conversion and FX gain/loss calculations over the base accounting currency.
abstract interface class CurrencyConversionService {
  /// Converts [amount] from [fromCurrency] to [toCurrency] using the rate
  /// applicable on [date]. Throws [StateError] when no cached rate exists.
  Future<double> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required DateTime date,
  });

  /// Refreshes the local rate cache from the central-bank feed.
  Future<void> syncExchangeRates();

  /// Computes the FX gain or loss (in base-currency units) of holding
  /// [originalAmount] of [currency] between [transactionDate] and
  /// [settlementDate]. Positive values are gains.
  Future<double> calculateFxGainLoss({
    required double originalAmount,
    required String currency,
    required DateTime transactionDate,
    required DateTime settlementDate,
  });
}
