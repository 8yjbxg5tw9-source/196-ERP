import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';
import '../../domain/entities/cash_flow_entity.dart';
import '../../domain/entities/chart_of_accounts.dart';
import '../../domain/entities/profit_and_loss_entity.dart';
import '../../domain/repositories/financial_report_repository.dart';
import '../datasources/analytics_local_data_source.dart';

/// Real-time financial statement engine backed by raw SQLite aggregations.
///
/// The ledger is the `transactions` table grouped by `category` and
/// `transaction_type`; approved OCR invoices in `documents` contribute sales
/// revenue, receivables, and output VAT until a dedicated ledger-posting step
/// migrates them into `transactions`.
class FinancialReportRepositoryImpl implements FinancialReportRepository {
  FinancialReportRepositoryImpl(this._localDataSource);

  final AnalyticsLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, ProfitAndLossEntity>> generateProfitAndLoss(
    String companyId,
    DateTimeRange dateRange,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, ProfitAndLossEntity>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final List<AccountEntity> accounts =
          await _localDataSource.getAccounts(normalizedCompanyId);
      final Map<String, AccountEntity> accountsByCode = _indexByCode(accounts);
      final DateTime start = _startOf(dateRange);
      final DateTime endExclusive = _endExclusiveOf(dateRange);

      final List<TransactionAggregate> aggregates =
          await _localDataSource.aggregateTransactions(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final double documentsRevenue = await _localDataSource.sumDocuments(
        normalizedCompanyId,
        column: 'total_amount',
        start: start,
        endExclusive: endExclusive,
      );
      final double documentsVat = await _localDataSource.sumDocuments(
        normalizedCompanyId,
        column: 'vat_amount',
        start: start,
        endExclusive: endExclusive,
      );

      final Map<String, double> totalsByCategory = _totalsByCategory(
        aggregates,
      );

      final double revenueTransactions = _sumOf(
        totalsByCategory,
        const <String>{'revenue', 'sales', 'income'},
      );
      final double cogs = _sumOf(
        totalsByCategory,
        const <String>{'cogs', 'costofgoodssold', 'costofsales'},
      );
      final double inputVat = _sumOf(
        totalsByCategory,
        const <String>{'input_vat', 'vat_input'},
      );

      final Map<String, double> operatingExpenses = <String, double>{};
      for (final MapEntry<String, String> entry
          in _expenseCategoryToCode.entries) {
        final double value = totalsByCategory[entry.key] ?? 0;
        if (value.abs() <= _epsilon) {
          continue;
        }
        final AccountEntity? account = accountsByCode[entry.value];
        final String name = account?.name ?? entry.value;
        operatingExpenses[name] = (operatingExpenses[name] ?? 0) + value;
      }

      final double totalRevenue = documentsRevenue + revenueTransactions;
      final double grossProfit = totalRevenue - cogs;
      final double totalOperatingExpenses = operatingExpenses.values.fold<double>(
        0,
        (double sum, double value) => sum + value,
      );
      final double totalExpenses = cogs + totalOperatingExpenses;
      final double ebitda = grossProfit - totalOperatingExpenses;
      final double netProfit = totalRevenue - totalExpenses;
      final double profitMargin = totalRevenue.abs() <= _epsilon
          ? 0
          : netProfit / totalRevenue * 100;

      return Right<Failure, ProfitAndLossEntity>(
        ProfitAndLossEntity(
          dateRange: dateRange,
          totalRevenue: totalRevenue,
          cogs: cogs,
          grossProfit: grossProfit,
          operatingExpenses: operatingExpenses,
          totalExpenses: totalExpenses,
          ebitda: ebitda,
          netProfit: netProfit,
          profitMarginPercentage: profitMargin,
          outputVat: documentsVat,
          inputVat: inputVat,
          netPayableVat: documentsVat - inputVat,
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, ProfitAndLossEntity>(
        DatabaseFailure(
          message: 'The profit & loss statement could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, ProfitAndLossEntity>(
        CacheFailure(
          message: 'The profit & loss statement could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CashFlowEntity>> generateCashFlow(
    String companyId,
    DateTimeRange dateRange,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, CashFlowEntity>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final DateTime start = _startOf(dateRange);
      final DateTime endExclusive = _endExclusiveOf(dateRange);
      final List<TransactionAggregate> aggregates =
          await _localDataSource.aggregateTransactions(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );

      double operating = 0;
      double investing = 0;
      double financing = 0;
      for (final TransactionAggregate aggregate in aggregates) {
        final double signed =
            aggregate.type == 'credit' ? aggregate.total : -aggregate.total;
        switch (_sectionOf(aggregate.category)) {
          case _CashFlowSection.operating:
            operating += signed;
            break;
          case _CashFlowSection.investing:
            investing += signed;
            break;
          case _CashFlowSection.financing:
            financing += signed;
            break;
        }
      }

      final double netCashChange = operating + investing + financing;
      return Right<Failure, CashFlowEntity>(
        CashFlowEntity(
          dateRange: dateRange,
          operatingCashFlow: operating,
          investingCashFlow: investing,
          financingCashFlow: financing,
          netCashChange: netCashChange,
          endingCashBalance: netCashChange,
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, CashFlowEntity>(
        DatabaseFailure(
          message: 'The cash flow statement could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, CashFlowEntity>(
        CacheFailure(
          message: 'The cash flow statement could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<AccountBalanceEntity>>>
      getChartOfAccountsBalances(String companyId) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<AccountBalanceEntity>>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final List<AccountEntity> accounts =
          await _localDataSource.getAccounts(normalizedCompanyId);
      final List<TransactionAggregate> aggregates =
          await _localDataSource.aggregateTransactions(normalizedCompanyId);
      final double documentsTotal = await _localDataSource.sumDocuments(
        normalizedCompanyId,
        column: 'total_amount',
      );
      final double documentsVat = await _localDataSource.sumDocuments(
        normalizedCompanyId,
        column: 'vat_amount',
      );

      double totalInflow = 0;
      double totalOutflow = 0;
      final Map<String, double> totalsByCategory = <String, double>{};
      for (final TransactionAggregate aggregate in aggregates) {
        totalsByCategory[aggregate.category] =
            (totalsByCategory[aggregate.category] ?? 0) + aggregate.total;
        if (aggregate.type == 'credit') {
          totalInflow += aggregate.total;
        } else if (aggregate.type == 'debit') {
          totalOutflow += aggregate.total;
        }
      }

      final double netCash = totalInflow - totalOutflow;
      final double outputVat = documentsVat;
      final double inputVat = _sumOf(
        totalsByCategory,
        const <String>{'input_vat', 'vat_input'},
      );
      final double revenue = documentsTotal +
          _sumOf(
            totalsByCategory,
            const <String>{'revenue', 'sales', 'income'},
          );
      final double expenseTotal = _expenseTotal(totalsByCategory);
      final double netProfit = revenue - expenseTotal;

      final Map<String, double> balances = <String, double>{
        '101.1': netCash,
        '121': documentsTotal,
        '221': outputVat,
        '222': inputVat,
        '401': revenue,
        '303': netProfit,
      };
      final Map<String, double> debits = <String, double>{
        '101.1': totalOutflow,
        '121': documentsTotal,
        '222': inputVat,
      };
      final Map<String, double> credits = <String, double>{
        '101.1': totalInflow,
        '221': outputVat,
        '401': revenue,
      };
      for (final MapEntry<String, String> entry
          in _expenseCategoryToCode.entries) {
        final double value = totalsByCategory[entry.key] ?? 0;
        if (value.abs() <= _epsilon) {
          continue;
        }
        balances[entry.value] = (balances[entry.value] ?? 0) + value;
        debits[entry.value] = (debits[entry.value] ?? 0) + value;
      }

      final List<AccountBalanceEntity> result = <AccountBalanceEntity>[];
      for (final AccountEntity account in accounts) {
        result.add(
          AccountBalanceEntity(
            account: account,
            debit: debits[account.code] ?? 0,
            credit: credits[account.code] ?? 0,
            balance: balances[account.code] ?? 0,
          ),
        );
      }
      return Right<Failure, List<AccountBalanceEntity>>(result);
    } on DatabaseException catch (error) {
      return Left<Failure, List<AccountBalanceEntity>>(
        DatabaseFailure(
          message: 'The chart of accounts could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<AccountBalanceEntity>>(
        CacheFailure(
          message: 'The chart of accounts could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, DashboardAnalyticsEntity>> generateDashboardAnalytics(
    String companyId,
    DateTimeRange dateRange,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return const Left<Failure, DashboardAnalyticsEntity>(
        ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final Either<Failure, ProfitAndLossEntity> pnlResult =
          await generateProfitAndLoss(normalizedCompanyId, dateRange);
      ProfitAndLossEntity? pnl;
      final Failure? pnlFailure = pnlResult.fold(
        (Failure value) => value,
        (ProfitAndLossEntity value) {
          pnl = value;
          return null;
        },
      );
      if (pnlFailure != null || pnl == null) {
        return Left<Failure, DashboardAnalyticsEntity>(
          pnlFailure ??
              const CacheFailure(message: 'Profit & loss is unavailable.'),
        );
      }
      final ProfitAndLossEntity statement = pnl!;
      final double operatingExpenses =
          statement.operatingExpenses.values.fold<double>(
        0,
        (double sum, double value) => sum + value,
      );

      // Growth badge against the immediately preceding period.
      final DateTimeRange previousRange = _previousPeriodOf(dateRange);
      final Either<Failure, ProfitAndLossEntity> previousResult =
          await generateProfitAndLoss(normalizedCompanyId, previousRange);
      final double previousRevenue = previousResult.fold(
        (Failure _) => 0,
        (ProfitAndLossEntity value) => value.totalRevenue,
      );
      final double revenueChange = previousRevenue.abs() <= _epsilon
          ? 0
          : (statement.totalRevenue - previousRevenue) / previousRevenue * 100;

      final DateTime start = _startOf(dateRange);
      final DateTime endExclusive = _endExclusiveOf(dateRange);

      final List<MonthlyTransactionAggregate> monthly =
          await _localDataSource.aggregateMonthlyTransactions(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final Map<String, double> documentsByMonth =
          await _localDataSource.sumDocumentsByMonth(
        normalizedCompanyId,
        column: 'total_amount',
        start: start,
        endExclusive: endExclusive,
      );
      final List<MonthlyProfitTrend> monthlyTrend = _buildMonthlyTrend(
        monthly,
        documentsByMonth,
        start,
        endExclusive,
      );

      // Current liquid cash: cumulative net ledger flows up to the period end.
      final List<TransactionAggregate> runningAggregates =
          await _localDataSource.aggregateTransactions(
        normalizedCompanyId,
        endExclusive: endExclusive,
      );
      double cashBalance = 0;
      for (final TransactionAggregate aggregate in runningAggregates) {
        cashBalance +=
            aggregate.type == 'credit' ? aggregate.total : -aggregate.total;
      }

      // Rolling 12-month cash flow window ending at the period end.
      final DateTime trendStart = DateTime.utc(
        dateRange.end.year,
        dateRange.end.month - 11,
        1,
      );
      final DateTime trendEndExclusive = DateTime.utc(
        dateRange.end.year,
        dateRange.end.month + 1,
        1,
      );
      final List<MonthlyTransactionAggregate> cashMonthly =
          await _localDataSource.aggregateMonthlyTransactions(
        normalizedCompanyId,
        start: trendStart,
        endExclusive: trendEndExclusive,
      );
      final double windowNet = _netOf(cashMonthly);
      final List<CashFlowPoint> cashFlowTrend = _buildCashFlowTrend(
        cashMonthly,
        trendStart,
        trendEndExclusive,
        startingBalance: cashBalance - windowNet,
      );
      final double dailyNet =
          _averageDailyNet(cashMonthly, trendStart, trendEndExclusive);
      final List<CashFlowPoint> cashFlowForecast = _buildForecast(
        cashFlowTrend,
        dailyNet,
      );

      // Runway and liquidity proxies.
      final double monthlyBurn = _monthlyBurn(monthly);
      final double runwayMonths = monthlyBurn <= _epsilon
          ? 12
          : (cashBalance / monthlyBurn).clamp(0, 120).toDouble();

      final double receivables = await _localDataSource.sumDocuments(
        normalizedCompanyId,
        column: 'total_amount',
      );
      final int receivablesCount =
          await _localDataSource.countDocuments(normalizedCompanyId);
      final double totalAssets = cashBalance + receivables;
      final double totalLiabilities = statement.outputVat;
      final double debtToAssetRatio =
          totalAssets <= _epsilon ? 0 : totalLiabilities / totalAssets;
      final double currentRatio =
          totalLiabilities <= _epsilon ? 0 : totalAssets / totalLiabilities;

      final CashCrunchPrediction? crunch = _predictCrunch(
        cashBalance: cashBalance,
        dailyNet: dailyNet,
        monthlyBurn: monthlyBurn,
        anchorDate: endExclusive,
        receivableCount: receivablesCount,
        receivablesTotal: receivables,
      );

      return Right<Failure, DashboardAnalyticsEntity>(
        DashboardAnalyticsEntity(
          dateRange: dateRange,
          grossRevenue: statement.totalRevenue,
          grossRevenueChangePercent: revenueChange,
          netOperatingExpenses: operatingExpenses,
          expenseBreakdown: _expenseBreakdown(statement),
          netProfitMargin: statement.profitMarginPercentage,
          cashBalance: cashBalance,
          runwayMonths: runwayMonths,
          debtToAssetRatio: debtToAssetRatio,
          currentRatio: currentRatio,
          monthlyTrend: monthlyTrend,
          cashFlowTrend: cashFlowTrend,
          cashFlowForecast: cashFlowForecast,
          cashCrunch: crunch,
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, DashboardAnalyticsEntity>(
        DatabaseFailure(
          message: 'The dashboard analytics could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, DashboardAnalyticsEntity>(
        CacheFailure(
          message: 'The dashboard analytics could not be generated.',
          cause: error,
        ),
      );
    }
  }

  static DateTimeRange _previousPeriodOf(DateTimeRange range) {
    final int days = range.end.difference(range.start).inDays + 1;
    final DateTime previousEnd = range.start.subtract(const Duration(days: 1));
    final DateTime previousStart =
        previousEnd.subtract(Duration(days: days - 1));
    return DateTimeRange(start: previousStart, end: previousEnd);
  }

  static List<MonthlyProfitTrend> _buildMonthlyTrend(
    List<MonthlyTransactionAggregate> monthly,
    Map<String, double> documentsByMonth,
    DateTime start,
    DateTime endExclusive,
  ) {
    final Map<String, double> revenue = <String, double>{};
    final Map<String, double> expenses = <String, double>{};
    for (final MonthlyTransactionAggregate aggregate in monthly) {
      if (_isRevenueCategory(aggregate.category)) {
        revenue[aggregate.month] =
            (revenue[aggregate.month] ?? 0) + aggregate.total;
      } else if (_isExpenseCategory(aggregate.category)) {
        expenses[aggregate.month] =
            (expenses[aggregate.month] ?? 0) + aggregate.total;
      }
    }

    final List<MonthlyProfitTrend> result = <MonthlyProfitTrend>[];
    DateTime cursor = DateTime.utc(start.year, start.month, 1);
    while (cursor.isBefore(endExclusive)) {
      final String key = _monthKey(cursor);
      result.add(
        MonthlyProfitTrend(
          monthLabel: DateFormat('MMM').format(cursor),
          revenue: (revenue[key] ?? 0) + (documentsByMonth[key] ?? 0),
          expenses: expenses[key] ?? 0,
        ),
      );
      cursor = DateTime.utc(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  static List<CashFlowPoint> _buildCashFlowTrend(
    List<MonthlyTransactionAggregate> monthly,
    DateTime start,
    DateTime endExclusive, {
    required double startingBalance,
  }) {
    final Map<String, double> netByMonth = <String, double>{};
    for (final MonthlyTransactionAggregate aggregate in monthly) {
      final double signed =
          aggregate.type == 'credit' ? aggregate.total : -aggregate.total;
      netByMonth[aggregate.month] =
          (netByMonth[aggregate.month] ?? 0) + signed;
    }

    final List<CashFlowPoint> result = <CashFlowPoint>[];
    double running = startingBalance;
    DateTime cursor = DateTime.utc(start.year, start.month, 1);
    while (cursor.isBefore(endExclusive)) {
      running += netByMonth[_monthKey(cursor)] ?? 0;
      result.add(CashFlowPoint(date: cursor, balance: running));
      cursor = DateTime.utc(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  static List<CashFlowPoint> _buildForecast(
    List<CashFlowPoint> trend,
    double dailyNet,
  ) {
    if (trend.isEmpty) {
      return const <CashFlowPoint>[];
    }
    final CashFlowPoint last = trend.last;
    final DateTime base = last.date;
    return <CashFlowPoint>[
      CashFlowPoint(date: base, balance: last.balance),
      CashFlowPoint(
        date: base.add(const Duration(days: 30)),
        balance: last.balance + dailyNet * 30,
      ),
      CashFlowPoint(
        date: base.add(const Duration(days: 60)),
        balance: last.balance + dailyNet * 60,
      ),
    ];
  }

  static double _netOf(List<MonthlyTransactionAggregate> monthly) {
    double total = 0;
    for (final MonthlyTransactionAggregate aggregate in monthly) {
      total +=
          aggregate.type == 'credit' ? aggregate.total : -aggregate.total;
    }
    return total;
  }

  static double _averageDailyNet(
    List<MonthlyTransactionAggregate> monthly,
    DateTime start,
    DateTime endExclusive,
  ) {
    final int days = endExclusive.difference(start).inDays;
    return days <= 0 ? 0 : _netOf(monthly) / days;
  }

  static double _monthlyBurn(List<MonthlyTransactionAggregate> monthly) {
    final Map<String, double> byMonth = <String, double>{};
    for (final MonthlyTransactionAggregate aggregate in monthly) {
      if (_isExpenseCategory(aggregate.category)) {
        byMonth[aggregate.month] =
            (byMonth[aggregate.month] ?? 0) + aggregate.total;
      }
    }
    if (byMonth.isEmpty) {
      return 0;
    }
    double total = 0;
    for (final double value in byMonth.values) {
      total += value;
    }
    return total / byMonth.length;
  }

  static List<ExpenseCategoryBreakdown> _expenseBreakdown(
    ProfitAndLossEntity statement,
  ) {
    final Map<String, double> categories = <String, double>{
      'Cost of Goods Sold': statement.cogs,
      for (final MapEntry<String, double> entry
          in statement.operatingExpenses.entries)
        entry.key: entry.value,
    };
    final List<MapEntry<String, double>> entries =
        categories.entries.where((MapEntry<String, double> e) => e.value.abs() > _epsilon).toList(growable: false)
          ..sort(
            (MapEntry<String, double> left, MapEntry<String, double> right) =>
                right.value.compareTo(left.value),
          );

    final List<ExpenseCategoryBreakdown> result = <ExpenseCategoryBreakdown>[];
    double others = 0;
    for (int index = 0; index < entries.length; index++) {
      final MapEntry<String, double> entry = entries[index];
      if (index < 5) {
        result.add(
          ExpenseCategoryBreakdown(name: entry.key, amount: entry.value),
        );
      } else {
        others += entry.value;
      }
    }
    if (others > _epsilon) {
      result.add(ExpenseCategoryBreakdown(name: 'Others', amount: others));
    }
    return result;
  }

  static CashCrunchPrediction? _predictCrunch({
    required double cashBalance,
    required double dailyNet,
    required double monthlyBurn,
    required DateTime anchorDate,
    required int receivableCount,
    required double receivablesTotal,
  }) {
    final double safetyThreshold = monthlyBurn > _epsilon
        ? monthlyBurn
        : (cashBalance > 0 ? cashBalance * 0.15 : 0);
    if (dailyNet >= 0 || safetyThreshold <= _epsilon) {
      return null;
    }
    final double projected30 = cashBalance + dailyNet * 30;
    if (projected30 >= safetyThreshold) {
      return null;
    }
    final int day = ((cashBalance - safetyThreshold) / -dailyNet)
        .clamp(0, 60)
        .toInt();
    final DateTime crunchDate = anchorDate.add(Duration(days: day));
    final String dateLabel = DateFormat('MMM d').format(crunchDate);
    final String advice = 'Warning: Expected cash crunch on $dateLabel. '
        'Consider accelerating $receivableCount outstanding client invoices '
        'totaling ${_money(receivablesTotal)}.';
    return CashCrunchPrediction(
      atRisk: true,
      crunchDate: crunchDate,
      projectedLowestCash: projected30,
      advice: advice,
    );
  }

  static bool _isRevenueCategory(String category) {
    return const <String>{'revenue', 'sales', 'income'}.contains(category);
  }

  static bool _isExpenseCategory(String category) {
    return const <String>{'cogs', 'costofgoodssold', 'costofsales'}
            .contains(category) ||
        _expenseCategoryToCode.containsKey(category);
  }

  static String _monthKey(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  static String _money(double value) => 'AZN ${value.toStringAsFixed(2)}';

  static Map<String, AccountEntity> _indexByCode(
    List<AccountEntity> accounts,
  ) {
    return <String, AccountEntity>{
      for (final AccountEntity account in accounts)
        account.code: account,
    };
  }

  static Map<String, double> _totalsByCategory(
    List<TransactionAggregate> aggregates,
  ) {
    final Map<String, double> totals = <String, double>{};
    for (final TransactionAggregate aggregate in aggregates) {
      totals[aggregate.category] =
          (totals[aggregate.category] ?? 0) + aggregate.total;
    }
    return totals;
  }

  static double _sumOf(Map<String, double> totals, Set<String> categories) {
    double total = 0;
    totals.forEach((String category, double value) {
      if (categories.contains(category)) {
        total += value;
      }
    });
    return total;
  }

  static double _expenseTotal(Map<String, double> totals) {
    double total = _sumOf(
      totals,
      const <String>{'cogs', 'costofgoodssold', 'costofsales'},
    );
    for (final String category in _expenseCategoryToCode.keys) {
      total += totals[category] ?? 0;
    }
    return total;
  }

  static _CashFlowSection _sectionOf(String category) {
    if (category.contains('invest')) {
      return _CashFlowSection.investing;
    }
    if (category.contains('financ') ||
        category.contains('loan') ||
        category.contains('capital') ||
        category.contains('dividend') ||
        category.contains('borrow')) {
      return _CashFlowSection.financing;
    }
    return _CashFlowSection.operating;
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

  static const double _epsilon = 0.000001;

  static const Map<String, String> _expenseCategoryToCode =
      <String, String>{
    'cogs': '501',
    'costofgoodssold': '501',
    'costofsales': '501',
    'salaries': '511',
    'salary': '511',
    'wages': '511',
    'payroll': '511',
    'rent': '512',
    'utilities': '513',
    'utility': '513',
    'marketing': '514',
    'advertising': '514',
    'depreciation': '515',
    'expense': '516',
    'other': '516',
    'interest': '601',
    'interestexpense': '601',
  };
}

enum _CashFlowSection { operating, investing, financing }
