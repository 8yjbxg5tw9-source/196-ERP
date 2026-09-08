import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../analytics/domain/entities/profit_and_loss_entity.dart';
import '../../../analytics/domain/repositories/financial_report_repository.dart';
import '../../domain/entities/deferred_tax_calculation_entity.dart';
import '../../domain/entities/deferred_tax_journal_entry.dart';
import '../../domain/entities/tax_base_comparison.dart';
import '../../domain/entities/temporary_difference_entity.dart';
import '../../domain/repositories/deferred_tax_repository.dart';
import '../../domain/services/deferred_tax_engine.dart';
import '../datasources/deferred_tax_local_data_source.dart';
import '../models/deferred_tax_calculation_model.dart';
import '../models/temporary_difference_model.dart';

/// Assembles asset/provision tax-base comparisons, runs the IAS 12 engine,
/// and persists calculations and their itemized differences.
class DeferredTaxRepositoryImpl implements DeferredTaxRepository {
  DeferredTaxRepositoryImpl(
    this._localDataSource,
    this._financialReportRepository, {
    DeferredTaxEngine engine = const DeferredTaxEngine(),
  }) : _engine = engine;

  final DeferredTaxLocalDataSource _localDataSource;
  final FinancialReportRepository _financialReportRepository;
  final DeferredTaxEngine _engine;

  @override
  Future<Either<Failure, List<TaxBaseComparison>>> fetchTaxBaseComparisons(
    String companyId,
    int year,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<TaxBaseComparison>>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final DateTime asOfDate = DateTime(year, 12, 31);
      final List<TaxBaseComparison> assets =
          await _localDataSource.loadAssetComparisons(
        normalizedCompanyId,
        asOfDate,
      );
      final List<TaxBaseComparison> provisions =
          await _localDataSource.loadProvisionComparisons(normalizedCompanyId);
      return Right<Failure, List<TaxBaseComparison>>(<TaxBaseComparison>[
        ...assets,
        ...provisions,
      ]);
    } on DatabaseException catch (error) {
      return Left<Failure, List<TaxBaseComparison>>(
        DatabaseFailure(
          message: 'Tax base comparisons could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<TaxBaseComparison>>(
        CacheFailure(
          message: 'Tax base comparisons could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, DeferredTaxComputation>> calculate({
    required String companyId,
    required int year,
    required double taxRate,
    List<TaxBaseComparison> manualComparisons = const <TaxBaseComparison>[],
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, DeferredTaxComputation>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }
    if (taxRate < 0 || taxRate > 1) {
      return Left<Failure, DeferredTaxComputation>(
        const ValidationFailure(
          message: 'Tax rate must be between 0% and 100%.',
        ),
      );
    }

    try {
      final DateTime asOfDate = DateTime(year, 12, 31);
      final List<TaxBaseComparison> assets =
          await _localDataSource.loadAssetComparisons(
        normalizedCompanyId,
        asOfDate,
      );
      final List<TaxBaseComparison> provisions =
          await _localDataSource.loadProvisionComparisons(normalizedCompanyId);

      final DeferredTaxCalculationEntity? prior = (await _localDataSource
              .getLatestCalculation(normalizedCompanyId, year - 1));
      final double priorYearNetPosition =
          prior?.netDeferredTaxPosition ?? 0;

      final double accountingNetProfit = await _accountingNetProfit(
        normalizedCompanyId,
        year,
      );

      final String id = 'dtc-$normalizedCompanyId-$year';
      final DeferredTaxComputation computation = _engine.compute(
        id: id,
        companyId: normalizedCompanyId,
        periodYear: year,
        taxRate: taxRate,
        priorYearNetPosition: priorYearNetPosition,
        accountingNetProfit: accountingNetProfit,
        comparisons: <TaxBaseComparison>[
          ...assets,
          ...provisions,
          ...manualComparisons,
        ],
        asOfDate: asOfDate,
      );

      await _localDataSource.replaceCalculation(
        DeferredTaxCalculationModel.fromEntity(computation.calculation),
      );
      await _localDataSource.replaceDifferences(
        computation.calculation.id,
        <TemporaryDifferenceModel>[
          for (final TemporaryDifferenceEntity item in computation.items)
            TemporaryDifferenceModel.fromEntity(item),
        ],
      );

      return Right<Failure, DeferredTaxComputation>(computation);
    } on DatabaseException catch (error) {
      return Left<Failure, DeferredTaxComputation>(
        DatabaseFailure(
          message: 'The deferred tax calculation could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, DeferredTaxComputation>(
        CacheFailure(
          message: 'The deferred tax calculation could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, DeferredTaxCalculationEntity>> postJournal({
    required DeferredTaxCalculationEntity calculation,
    required DeferredTaxJournalEntry journal,
  }) async {
    try {
      await _localDataSource.writeJournalEntry(journal);
      await _localDataSource.markCalculationPosted(calculation.id);
      return Right<Failure, DeferredTaxCalculationEntity>(
        calculation.copyWith(isPosted: true),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, DeferredTaxCalculationEntity>(
        DatabaseFailure(
          message: 'The deferred tax journal could not be posted.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, DeferredTaxCalculationEntity>(
        CacheFailure(
          message: 'The deferred tax journal could not be posted.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, DeferredTaxCalculationEntity?>> getLatestCalculation(
    String companyId,
    int year,
  ) async {
    try {
      final DeferredTaxCalculationModel? model =
          await _localDataSource.getLatestCalculation(companyId.trim(), year);
      return Right<Failure, DeferredTaxCalculationEntity?>(model);
    } on DatabaseException catch (error) {
      return Left<Failure, DeferredTaxCalculationEntity?>(
        DatabaseFailure(
          message: 'The deferred tax calculation could not be read.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, DeferredTaxCalculationEntity?>(
        CacheFailure(
          message: 'The deferred tax calculation could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TemporaryDifferenceEntity>>> getDifferences(
    String calculationId,
  ) async {
    try {
      final List<TemporaryDifferenceModel> models =
          await _localDataSource.getDifferences(calculationId);
      return Right<Failure, List<TemporaryDifferenceEntity>>(
        <TemporaryDifferenceEntity>[
          for (final TemporaryDifferenceModel model in models) model,
        ],
      );
    } on DatabaseException catch (error) {
      return Left<Failure, List<TemporaryDifferenceEntity>>(
        DatabaseFailure(
          message: 'The temporary differences could not be read.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<TemporaryDifferenceEntity>>(
        CacheFailure(
          message: 'The temporary differences could not be read.',
          cause: error,
        ),
      );
    }
  }

  Future<double> _accountingNetProfit(String companyId, int year) async {
    final DateTimeRange range = DateTimeRange(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
    final Either<Failure, ProfitAndLossEntity> result =
        await _financialReportRepository.generateProfitAndLoss(
      companyId,
      range,
    );
    return result.fold(
      (Failure _) => 0,
      (ProfitAndLossEntity report) => report.netProfit,
    );
  }
}
