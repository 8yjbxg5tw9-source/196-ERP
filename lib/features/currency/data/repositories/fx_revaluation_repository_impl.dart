import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/repositories/currency_repository.dart';
import '../../domain/revaluation/fx_balance_entity.dart';
import '../../domain/revaluation/fx_revaluation_entity.dart';
import '../../domain/revaluation/fx_revaluation_repository.dart';
import '../../domain/services/fx_revaluation_engine.dart';
import '../datasources/fx_revaluation_local_data_source.dart';
import '../models/fx_balance_model.dart';
import '../models/fx_revaluation_model.dart';

/// SQLite-backed FX revaluation with automatic gain/loss journal posting.
class FxRevaluationRepositoryImpl implements FxRevaluationRepository {
  FxRevaluationRepositoryImpl(
    this._localDataSource,
    this._currencyRepository, {
    FxRevaluationEngine engine = const FxRevaluationEngine(),
  }) : _engine = engine;

  /// Posting codes (free-text account codes in the journal).
  static const String _fxGainAccount = '611';
  static const String _fxLossAccount = '731';
  static const String _assetAdjustmentAccount = '121';
  static const String _liabilityAdjustmentAccount = '211';

  final FxRevaluationLocalDataSource _localDataSource;
  final CurrencyRepository _currencyRepository;
  final FxRevaluationEngine _engine;

  @override
  Future<Either<Failure, List<FxBalanceEntity>>> getBalances(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<FxBalanceEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }
    try {
      final List<FxBalanceModel> balances =
          await _localDataSource.getBalances(normalizedCompanyId);
      return Right<Failure, List<FxBalanceEntity>>(balances);
    } on DatabaseException catch (error) {
      return Left<Failure, List<FxBalanceEntity>>(
        DatabaseFailure(message: 'FX balances could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<FxBalanceEntity>>(
        CacheFailure(message: 'FX balances could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, FxBalanceEntity>> upsertBalance(
    FxBalanceEntity balance,
  ) async {
    if (balance.companyId.trim().isEmpty || balance.accountId.trim().isEmpty) {
      return Left<Failure, FxBalanceEntity>(
        const ValidationFailure(message: 'Company and account are required.'),
      );
    }
    if (balance.foreignAmount <= 0) {
      return Left<Failure, FxBalanceEntity>(
        const ValidationFailure(message: 'Foreign amount must be positive.'),
      );
    }
    try {
      final FxBalanceModel model = FxBalanceModel(
        id: balance.id.isEmpty
            ? 'fxbalance-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : balance.id,
        companyId: balance.companyId,
        accountId: balance.accountId,
        foreignCurrency: balance.foreignCurrency.toUpperCase(),
        foreignAmount: balance.foreignAmount,
        bookValueBaseCurrency: balance.bookValueBaseCurrency,
        balanceType: balance.balanceType,
        currentExchangeRate: balance.currentExchangeRate,
        revaluedValueBaseCurrency: balance.revaluedValueBaseCurrency,
        unrealizedGainLoss: balance.unrealizedGainLoss,
        createdAt: balance.createdAt ?? DateTime.now().toUtc(),
      );
      await _localDataSource.upsertBalance(model);
      return Right<Failure, FxBalanceEntity>(model);
    } on DatabaseException catch (error) {
      return Left<Failure, FxBalanceEntity>(
        DatabaseFailure(message: 'The FX balance could not be saved.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, FxBalanceEntity>(
        CacheFailure(message: 'The FX balance could not be saved locally.'),
      );
    }
  }

  @override
  Future<Either<Failure, FxRevaluationEntity>> calculateRevaluation({
    required String companyId,
    required DateTime date,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, FxRevaluationEntity>(
        const ValidationFailure(message: 'Select a company before revaluing.'),
      );
    }

    try {
      final List<FxBalanceModel> balances =
          await _localDataSource.getBalances(normalizedCompanyId);
      if (balances.isEmpty) {
        return Left<Failure, FxRevaluationEntity>(
          const ValidationFailure(
            message: 'No open foreign balances to revalue.',
          ),
        );
      }

      final Map<String, double> rates = await _closingRates(date);
      double totalGain = 0;
      double totalLoss = 0;
      final List<FxBalanceModel> updatedBalances = <FxBalanceModel>[];

      for (final FxBalanceModel balance in balances) {
        final double closingRate =
            rates[balance.foreignCurrency] ?? balance.currentExchangeRate;
        if (closingRate <= 0) {
          updatedBalances.add(balance);
          continue;
        }
        final FxRevaluationResult result = _engine.evaluate(
          balance,
          closingRate,
        );
        if (result.type == FxGainLossType.gain) {
          totalGain += result.unrealizedGainLoss;
        } else if (result.type == FxGainLossType.loss) {
          totalLoss += -result.unrealizedGainLoss;
        }
        updatedBalances.add(
          FxBalanceModel(
            id: balance.id,
            companyId: balance.companyId,
            accountId: balance.accountId,
            foreignCurrency: balance.foreignCurrency,
            foreignAmount: balance.foreignAmount,
            bookValueBaseCurrency: balance.bookValueBaseCurrency,
            balanceType: balance.balanceType,
            currentExchangeRate: result.currentExchangeRate,
            revaluedValueBaseCurrency: result.revaluedValueBaseCurrency,
            unrealizedGainLoss: result.unrealizedGainLoss,
            createdAt: balance.createdAt,
          ),
        );
      }

      final DateTime normalizedDate = DateTime(
        date.year,
        date.month,
        date.day,
      ).toUtc();
      final FxRevaluationModel revaluation = FxRevaluationModel(
        id: 'fxreval-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        companyId: normalizedCompanyId,
        revaluationDate: normalizedDate,
        periodMonth: date.month,
        periodYear: date.year,
        totalUnrealizedGain: _round(totalGain),
        totalUnrealizedLoss: _round(totalLoss),
        netFxImpact: _round(totalGain - totalLoss),
        isPosted: false,
        createdAt: DateTime.now().toUtc(),
      );

      await _localDataSource.insertRevaluation(revaluation);
      for (final FxBalanceModel balance in updatedBalances) {
        await _localDataSource.upsertBalance(balance);
      }
      return Right<Failure, FxRevaluationEntity>(revaluation);
    } on DatabaseException catch (error) {
      return Left<Failure, FxRevaluationEntity>(
        DatabaseFailure(message: 'The revaluation could not be saved.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, FxRevaluationEntity>(
        CacheFailure(message: 'The revaluation could not be computed.'),
      );
    }
  }

  @override
  Future<Either<Failure, FxRevaluationEntity>> postRevaluation(
    FxRevaluationEntity revaluation,
  ) async {
    if (revaluation.isPosted) {
      return Right<Failure, FxRevaluationEntity>(revaluation);
    }
    try {
      if (revaluation.netFxImpact != 0) {
        final double amount = revaluation.netFxImpact.abs();
        if (revaluation.netFxImpact > 0) {
          await _localDataSource.writeJournalEntry(
            FxJournalEntryInput(
              companyId: revaluation.companyId,
              entryDate: revaluation.revaluationDate,
              description: 'FX revaluation gain '
                  '(${revaluation.periodYear}-${revaluation.periodMonth})',
              debitAccount: _assetAdjustmentAccount,
              creditAccount: _fxGainAccount,
              amount: amount,
              sourceType: 'fx_revaluation',
              sourceId: revaluation.id,
            ),
          );
        } else {
          await _localDataSource.writeJournalEntry(
            FxJournalEntryInput(
              companyId: revaluation.companyId,
              entryDate: revaluation.revaluationDate,
              description: 'FX revaluation loss '
                  '(${revaluation.periodYear}-${revaluation.periodMonth})',
              debitAccount: _fxLossAccount,
              creditAccount: _liabilityAdjustmentAccount,
              amount: amount,
              sourceType: 'fx_revaluation',
              sourceId: revaluation.id,
            ),
          );
        }
      }

      final FxRevaluationModel updated = FxRevaluationModel(
        id: revaluation.id,
        companyId: revaluation.companyId,
        revaluationDate: revaluation.revaluationDate,
        periodMonth: revaluation.periodMonth,
        periodYear: revaluation.periodYear,
        totalUnrealizedGain: revaluation.totalUnrealizedGain,
        totalUnrealizedLoss: revaluation.totalUnrealizedLoss,
        netFxImpact: revaluation.netFxImpact,
        isPosted: true,
        createdAt: revaluation.createdAt,
      );
      await _localDataSource.updateRevaluation(updated);
      return Right<Failure, FxRevaluationEntity>(updated);
    } on DatabaseException catch (error) {
      return Left<Failure, FxRevaluationEntity>(
        DatabaseFailure(message: 'The revaluation could not be posted.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, FxRevaluationEntity>(
        CacheFailure(message: 'The revaluation could not be posted locally.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> postReversal(
    FxRevaluationEntity revaluation,
  ) async {
    try {
      final DateTime reversalDate = _firstDayOfNextPeriod(
        revaluation.revaluationDate,
      );
      if (revaluation.netFxImpact > 0) {
        await _localDataSource.writeJournalEntry(
          FxJournalEntryInput(
            companyId: revaluation.companyId,
            entryDate: reversalDate,
            description: 'Reversal of FX revaluation gain '
                '(${revaluation.periodYear}-${revaluation.periodMonth})',
            debitAccount: _fxGainAccount,
            creditAccount: _assetAdjustmentAccount,
            amount: revaluation.netFxImpact.abs(),
            sourceType: 'fx_revaluation_reversal',
            sourceId: revaluation.id,
          ),
        );
      } else if (revaluation.netFxImpact < 0) {
        await _localDataSource.writeJournalEntry(
          FxJournalEntryInput(
            companyId: revaluation.companyId,
            entryDate: reversalDate,
            description: 'Reversal of FX revaluation loss '
                '(${revaluation.periodYear}-${revaluation.periodMonth})',
            debitAccount: _liabilityAdjustmentAccount,
            creditAccount: _fxLossAccount,
            amount: revaluation.netFxImpact.abs(),
            sourceType: 'fx_revaluation_reversal',
            sourceId: revaluation.id,
          ),
        );
      }
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(message: 'The reversal could not be posted.'),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'The reversal could not be posted locally.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<FxRevaluationEntity>>> getHistory(
    String companyId,
  ) async {
    try {
      final List<FxRevaluationModel> history =
          await _localDataSource.getHistory(companyId);
      return Right<Failure, List<FxRevaluationEntity>>(history);
    } on DatabaseException catch (error) {
      return Left<Failure, List<FxRevaluationEntity>>(
        DatabaseFailure(message: 'Revaluation history could not be loaded.'),
      );
    } on Object catch (error) {
      return Left<Failure, List<FxRevaluationEntity>>(
        CacheFailure(message: 'Revaluation history could not be read locally.'),
      );
    }
  }

  Future<Map<String, double>> _closingRates(DateTime date) async {
    final Map<String, double> rates = <String, double>{};
    final Either<Failure, List<ExchangeRateEntity>> result =
        await _currencyRepository.getLatestRates(baseCurrency: 'AZN');
    result.fold(
      (Failure _) => null,
      (List<ExchangeRateEntity> values) {
        for (final ExchangeRateEntity rate in values) {
          rates[rate.targetCurrency] = rate.rate;
        }
        return null;
      },
    );
    return rates;
  }

  static DateTime _firstDayOfNextPeriod(DateTime date) {
    final DateTime next = DateTime(date.year, date.month + 1, 1);
    return next.toUtc();
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 100).roundToDouble() / 100;
  }
}
