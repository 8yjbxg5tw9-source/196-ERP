import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/currency_entity.dart';
import '../models/currency_model.dart';
import '../models/exchange_rate_model.dart';

/// SQLite cache for currencies and daily exchange rates. The cache is the
/// authoritative source during offline operation.
abstract interface class CurrencyLocalDataSource {
  Future<List<CurrencyEntity>> getCurrencies();

  Future<void> upsertRates({
    required String baseCurrency,
    required DateTime date,
    required String source,
    required Map<String, double> rates,
  });

  Future<ExchangeRateEntity?> getRate({
    required String baseCurrency,
    required String targetCurrency,
    required DateTime date,
  });

  Future<List<ExchangeRateEntity>> getLatestRates(String baseCurrency);
}

class CurrencyLocalDataSourceImpl implements CurrencyLocalDataSource {
  CurrencyLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<CurrencyEntity>> getCurrencies() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.currencies,
      orderBy: 'is_base DESC, code ASC',
    );
    return rows.map(CurrencyModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> upsertRates({
    required String baseCurrency,
    required DateTime date,
    required String source,
    required Map<String, double> rates,
  }) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      for (final MapEntry<String, double> entry in rates.entries) {
        final ExchangeRateModel model = ExchangeRateModel(
          id: _rateId(baseCurrency, entry.key, date),
          baseCurrency: baseCurrency,
          targetCurrency: entry.key.toUpperCase(),
          rate: entry.value,
          rateDate: date,
          source: source,
        );
        await transaction.insert(
          DatabaseTables.exchangeRates,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<ExchangeRateEntity?> getRate({
    required String baseCurrency,
    required String targetCurrency,
    required DateTime date,
  }) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.exchangeRates,
      where: 'base_currency = ? AND target_currency = ? AND rate_date <= ?',
      whereArgs: <Object?>[
        baseCurrency,
        targetCurrency.toUpperCase(),
        _dateKey(date),
      ],
      orderBy: 'rate_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ExchangeRateModel.fromMap(rows.first);
  }

  @override
  Future<List<ExchangeRateEntity>> getLatestRates(String baseCurrency) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.exchangeRates,
      where: 'base_currency = ?',
      whereArgs: <Object?>[baseCurrency],
      orderBy: 'rate_date DESC',
    );
    final Map<String, ExchangeRateEntity> latest =
        <String, ExchangeRateEntity>{};
    for (final Map<String, Object?> row in rows) {
      final ExchangeRateModel model = ExchangeRateModel.fromMap(row);
      latest.putIfAbsent(model.targetCurrency, () => model);
    }
    final List<ExchangeRateEntity> results = latest.values.toList(growable: false);
    results.sort(
      (ExchangeRateEntity left, ExchangeRateEntity right) =>
          left.targetCurrency.compareTo(right.targetCurrency),
    );
    return results;
  }

  static String _rateId(String base, String target, DateTime date) {
    return 'rate-$base-${target.toUpperCase()}-${_dateKey(date)}';
  }

  static String _dateKey(DateTime date) {
    final DateTime local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
