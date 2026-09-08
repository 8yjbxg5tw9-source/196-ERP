import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/repositories/currency_repository.dart';
import '../datasources/currency_local_data_source.dart';
import '../datasources/currency_remote_data_source.dart';

/// Cached-first currency repository. Reads always come from SQLite so the app
/// remains fully functional offline; [syncRates] opportunistically refreshes
/// the cache when connectivity is available.
class CurrencyRepositoryImpl implements CurrencyRepository {
  CurrencyRepositoryImpl({
    required CurrencyLocalDataSource localDataSource,
    required CurrencyRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  final CurrencyLocalDataSource _localDataSource;
  final CurrencyRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  @override
  Future<Either<Failure, List<CurrencyEntity>>> getCurrencies() async {
    try {
      final List<CurrencyEntity> currencies =
          await _localDataSource.getCurrencies();
      return Right<Failure, List<CurrencyEntity>>(currencies);
    } on Object catch (error) {
      return Left<Failure, List<CurrencyEntity>>(
        CacheFailure(
          message: 'Currencies could not be read from the local cache.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExchangeRateEntity>>> getLatestRates({
    String baseCurrency = 'AZN',
  }) async {
    try {
      final List<ExchangeRateEntity> rates =
          await _localDataSource.getLatestRates(baseCurrency);
      return Right<Failure, List<ExchangeRateEntity>>(rates);
    } on Object catch (error) {
      return Left<Failure, List<ExchangeRateEntity>>(
        CacheFailure(
          message: 'Exchange rates could not be read from the local cache.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ExchangeRateEntity?>> getRate(
    String baseCurrency,
    String targetCurrency,
    DateTime date,
  ) async {
    try {
      final ExchangeRateEntity? rate = await _localDataSource.getRate(
        baseCurrency: baseCurrency,
        targetCurrency: targetCurrency,
        date: date,
      );
      return Right<Failure, ExchangeRateEntity?>(rate);
    } on Object catch (error) {
      return Left<Failure, ExchangeRateEntity?>(
        CacheFailure(
          message: 'The exchange rate could not be read from the local cache.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> syncRates() async {
    try {
      final bool connected = await _networkInfo.isConnected;
      if (!connected) {
        debugPrint('[CurrencyRepository] Offline; keeping cached rates.');
        return const Right<Failure, void>(null);
      }
      final Map<String, double> rates = await _remoteDataSource.fetchRates(
        baseCurrency: 'AZN',
      );
      await _localDataSource.upsertRates(
        baseCurrency: 'AZN',
        date: DateTime.now(),
        source: 'CentralBank',
        rates: rates,
      );
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      // Offline fallback: a failed sync never breaks the app, cached rates
      // remain authoritative for conversions.
      debugPrint('[CurrencyRepository] Rate sync failed (using cache): $error');
      return const Right<Failure, void>(null);
    }
  }
}
