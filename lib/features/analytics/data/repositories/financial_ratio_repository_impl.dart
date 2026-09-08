import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/financial_ratio_entity.dart';
import '../../domain/entities/profit_and_loss_entity.dart';
import '../../domain/repositories/financial_ratio_repository.dart';
import '../../domain/repositories/financial_report_repository.dart';
import '../../domain/services/ratio_engine.dart';
import '../datasources/analytics_local_data_source.dart';

/// Assembles ledger-derived ratio inputs (transaction aggregates, documents,
/// stock ledger, fixed assets) and delegates computation to the [RatioEngine].
class FinancialRatioRepositoryImpl implements FinancialRatioRepository {
  FinancialRatioRepositoryImpl(
    this._localDataSource,
    this._financialReportRepository, {
    RatioEngine engine = const RatioEngine(),
  }) : _engine = engine;

  final AnalyticsLocalDataSource _localDataSource;
  final FinancialReportRepository _financialReportRepository;
  final RatioEngine _engine;

  static const Set<String> _interestCategories = <String>{
    'interest',
    'interestexpense',
  };
  static const Set<String> _inputVatCategories = <String>{
    'input_vat',
    'vat_input',
  };

  @override
  Future<Either<Failure, FinancialRatioEntity>> calculateRatios(
    String companyId,
    DateTimeRange dateRange,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, FinancialRatioEntity>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final FinancialRatioEntity metrics = await _computeForRange(
        companyId: normalizedCompanyId,
        start: _startOf(dateRange),
        endExclusive: _endExclusiveOf(dateRange),
        period: dateRange,
      );
      return Right<Failure, FinancialRatioEntity>(metrics);
    } on DatabaseException catch (error) {
      return Left<Failure, FinancialRatioEntity>(
        DatabaseFailure(
          message: 'The financial ratios could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, FinancialRatioEntity>(
        CacheFailure(
          message: 'The financial ratios could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, List<double>>>> fetchRatioTrends(
    String companyId,
    int numberOfPeriods,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, Map<String, List<double>>>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final int periods =
          numberOfPeriods < 1 ? 1 : (numberOfPeriods > 12 ? 12 : numberOfPeriods);
      final List<DateTimeRange> quarters = _lastQuarters(periods);
      final Map<String, List<double>> series = <String, List<double>>{
        'grossProfitMargin': <double>[],
        'netProfitMargin': <double>[],
        'currentRatio': <double>[],
        'quickRatio': <double>[],
        'daysSalesOutstanding': <double>[],
        'daysInventoryOutstanding': <double>[],
      };
      for (final DateTimeRange quarter in quarters) {
        final FinancialRatioEntity metrics = await _computeForRange(
          companyId: normalizedCompanyId,
          start: _startOf(quarter),
          endExclusive: _endExclusiveOf(quarter),
          period: quarter,
        );
        series['grossProfitMargin']!.add(metrics.grossProfitMargin);
        series['netProfitMargin']!.add(metrics.netProfitMargin);
        series['currentRatio']!.add(metrics.currentRatio);
        series['quickRatio']!.add(metrics.quickRatio);
        series['daysSalesOutstanding']!.add(metrics.daysSalesOutstanding);
        series['daysInventoryOutstanding']!.add(metrics.daysInventoryOutstanding);
      }
      return Right<Failure, Map<String, List<double>>>(series);
    } on DatabaseException catch (error) {
      return Left<Failure, Map<String, List<double>>>(
        DatabaseFailure(
          message: 'The ratio trends could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, Map<String, List<double>>>(
        CacheFailure(
          message: 'The ratio trends could not be generated.',
          cause: error,
        ),
      );
    }
  }

  Future<FinancialRatioEntity> _computeForRange({
    required String companyId,
    required DateTime start,
    required DateTime endExclusive,
    required DateTimeRange period,
  }) async {
    final Either<Failure, ProfitAndLossEntity> pnlResult =
        await _financialReportRepository.generateProfitAndLoss(
      companyId,
      period,
    );
    final ProfitAndLossEntity pnl = pnlResult.fold(
      (Failure _) => ProfitAndLossEntity(
        dateRange: period,
        totalRevenue: 0,
        cogs: 0,
        grossProfit: 0,
        operatingExpenses: const <String, double>{},
        totalExpenses: 0,
        ebitda: 0,
        netProfit: 0,
        profitMarginPercentage: 0,
      ),
      (ProfitAndLossEntity value) => value,
    );

    final List<TransactionAggregate> running =
        await _localDataSource.aggregateTransactions(
      companyId,
      endExclusive: endExclusive,
    );
    double cash = 0;
    double inputVat = 0;
    double interest = 0;
    for (final TransactionAggregate aggregate in running) {
      cash += aggregate.type == 'credit'
          ? aggregate.total
          : -aggregate.total;
      if (_inputVatCategories.contains(aggregate.category)) {
        inputVat += aggregate.total;
      }
      if (_interestCategories.contains(aggregate.category)) {
        interest += aggregate.total;
      }
    }

    final double receivables = await _localDataSource.sumDocuments(
      companyId,
      column: 'total_amount',
      endExclusive: endExclusive,
    );
    final double outputVat = await _localDataSource.sumDocuments(
      companyId,
      column: 'vat_amount',
      endExclusive: endExclusive,
    );
    final double inventory = await _localDataSource.sumInventoryValue(
      companyId,
      endExclusive: endExclusive,
    );
    final double fixedAssets =
        await _localDataSource.sumFixedAssetsBookValue(companyId);

    final double currentAssets = cash + receivables + inventory;
    final double totalAssets = currentAssets + fixedAssets;
    final double totalLiabilities = outputVat + inputVat;
    final double totalEquity = totalAssets - totalLiabilities;

    return _engine.compute(
      id: 'ratio-$companyId-${endExclusive.toUtc().microsecondsSinceEpoch}',
      companyId: companyId,
      period: period,
      input: RatioEngineInput(
        revenue: pnl.totalRevenue,
        cogs: pnl.cogs,
        grossProfit: pnl.grossProfit,
        netProfit: pnl.netProfit,
        ebit: pnl.netProfit + interest,
        interestExpense: interest,
        cashAndEquivalents: cash,
        marketableSecurities: 0,
        receivables: receivables,
        inventory: inventory,
        currentAssets: currentAssets,
        currentLiabilities: totalLiabilities,
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        totalEquity: totalEquity,
      ),
    );
  }

  static List<DateTimeRange> _lastQuarters(int count) {
    final DateTime now = DateTime.now();
    final int quarterIndex = (now.month - 1) ~/ 3;
    final DateTime currentQuarterStart =
        DateTime(now.year, quarterIndex * 3 + 1, 1);
    return <DateTimeRange>[
      for (int offset = count - 1; offset >= 0; offset--)
        _quarterRange(currentQuarterStart, offset),
    ];
  }

  static DateTimeRange _quarterRange(DateTime currentQuarterStart, int offset) {
    final DateTime start = DateTime(
      currentQuarterStart.year,
      currentQuarterStart.month - offset * 3,
      1,
    );
    final DateTime end = DateTime(start.year, start.month + 3, 0);
    return DateTimeRange(start: start, end: end);
  }

  static DateTime _startOf(DateTimeRange range) {
    return DateTime(range.start.year, range.start.month, range.start.day)
        .toUtc();
  }

  static DateTime _endExclusiveOf(DateTimeRange range) {
    return DateTime(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1))
        .toUtc();
  }
}
