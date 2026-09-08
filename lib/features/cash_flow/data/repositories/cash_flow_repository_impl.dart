import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../analytics/domain/entities/profit_and_loss_entity.dart';
import '../../../analytics/domain/repositories/financial_report_repository.dart';
import '../../domain/entities/cash_flow_monthly_point.dart';
import '../../domain/entities/cash_flow_statement_entity.dart';
import '../../domain/repositories/cash_flow_repository.dart';
import '../../domain/services/cash_flow_engine.dart';
import '../datasources/cash_flow_local_data_source.dart';

/// Assembles the raw ledger inputs and delegates statement compilation to the
/// dual-method [CashFlowEngine].
class CashFlowRepositoryImpl implements CashFlowRepository {
  CashFlowRepositoryImpl(
    this._localDataSource,
    this._financialReportRepository, {
    CashFlowEngine engine = const CashFlowEngine(),
  }) : _engine = engine;

  final CashFlowLocalDataSource _localDataSource;
  final FinancialReportRepository _financialReportRepository;
  final CashFlowEngine _engine;

  @override
  Future<Either<Failure, CashFlowStatementEntity>> generateStatement({
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowMethod method,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, CashFlowStatementEntity>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final DateTime start = _startOf(dateRange);
      final DateTime endExclusive = _endExclusiveOf(dateRange);

      final List<CashMovement> movements = await _loadMovements(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final double beginningCash = await _beginningCash(
        normalizedCompanyId,
        start,
      );

      final double netProfit =
          await _netProfit(normalizedCompanyId, dateRange);
      final double depreciation = await _localDataSource.sumDepreciation(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final FxImpactRow fx = await _localDataSource.sumUnrealizedFx(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final double receivablesEnd = await _localDataSource.receivablesAt(
        normalizedCompanyId,
        endExclusive,
      );
      final double receivablesStart = await _localDataSource.receivablesAt(
        normalizedCompanyId,
        start,
      );
      final double inventoryChange = await _localDataSource.netInventoryChange(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final double payablesChange = await _localDataSource.netPayablesChange(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );

      final CashFlowStatementEntity statement = _engine.build(
        id: 'cash-flow-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        companyId: normalizedCompanyId,
        dateRange: dateRange,
        method: method,
        input: CashFlowEngineInput(
          movements: movements,
          beginningCashBalance: beginningCash,
          netProfit: netProfit,
          depreciation: depreciation,
          unrealizedFxGain: fx.gain,
          unrealizedFxLoss: fx.loss,
          accountsReceivableChange: receivablesEnd - receivablesStart,
          inventoryChange: inventoryChange,
          accountsPayableChange: payablesChange,
        ),
      );
      return Right<Failure, CashFlowStatementEntity>(statement);
    } on DatabaseException catch (error) {
      return Left<Failure, CashFlowStatementEntity>(
        DatabaseFailure(
          message: 'The cash flow statement could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, CashFlowStatementEntity>(
        CacheFailure(
          message: 'The cash flow statement could not be generated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<CashFlowMonthlyPoint>>> getMonthlyMovements({
    required String companyId,
    required DateTimeRange dateRange,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<CashFlowMonthlyPoint>>(
        const ValidationFailure(message: 'Select a company before reporting.'),
      );
    }

    try {
      final DateTime start = _startOf(dateRange);
      final DateTime endExclusive = _endExclusiveOf(dateRange);
      final List<CashMovement> movements = await _loadMovements(
        normalizedCompanyId,
        start: start,
        endExclusive: endExclusive,
      );
      final Map<String, double> netByMonth = <String, double>{};
      final Map<String, DateTime> monthDates = <String, DateTime>{};
      for (final CashMovement movement in movements) {
        final DateTime anchor = movement.date.toLocal();
        final DateTime monthStart = DateTime(anchor.year, anchor.month);
        final String key = _monthKey(monthStart);
        netByMonth[key] = (netByMonth[key] ?? 0) + movement.signedAmount;
        monthDates[key] = monthStart;
      }
      final List<String> keys = netByMonth.keys.toList(growable: false)..sort();
      final List<CashFlowMonthlyPoint> points = <CashFlowMonthlyPoint>[
        for (final String key in keys)
          CashFlowMonthlyPoint(
            date: monthDates[key] ?? start,
            label: _monthLabel(monthDates[key] ?? start),
            netMovement: netByMonth[key] ?? 0,
          ),
      ];
      return Right<Failure, List<CashFlowMonthlyPoint>>(points);
    } on DatabaseException catch (error) {
      return Left<Failure, List<CashFlowMonthlyPoint>>(
        DatabaseFailure(
          message: 'Monthly cash movements could not be computed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<CashFlowMonthlyPoint>>(
        CacheFailure(
          message: 'Monthly cash movements could not be generated.',
          cause: error,
        ),
      );
    }
  }

  Future<List<CashMovement>> _loadMovements(
    String companyId, {
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final List<CashMovement> movements = <CashMovement>[];
    final List<BankCashRow> bankRows = await _localDataSource.getBankTransactions(
      companyId,
      start: start,
      endExclusive: endExclusive,
    );
    for (final BankCashRow row in bankRows) {
      final String counterparty = row.counterpartyName == null ||
              row.counterpartyName!.trim().isEmpty
          ? ''
          : ' · ${row.counterpartyName!.trim()}';
      movements.add(
        CashMovement(
          date: row.date,
          description: '${row.description}$counterparty',
          accountCode: row.category,
          inflow: row.type == 'credit' ? row.amount : 0,
          outflow: row.type == 'credit' ? 0 : row.amount,
          sourceType: 'bank',
        ),
      );
    }
    final List<JournalCashRow> journalRows =
        await _localDataSource.getJournalEntries(
      companyId,
      start: start,
      endExclusive: endExclusive,
    );
    for (final JournalCashRow row in journalRows) {
      if (CashFlowEngine.isCashAccount(row.debitAccount)) {
        movements.add(
          CashMovement(
            date: row.entryDate,
            description: row.description,
            accountCode: row.creditAccount,
            inflow: row.amount,
            outflow: 0,
            sourceType: 'journal',
          ),
        );
      } else if (CashFlowEngine.isCashAccount(row.creditAccount)) {
        movements.add(
          CashMovement(
            date: row.entryDate,
            description: row.description,
            accountCode: row.debitAccount,
            inflow: 0,
            outflow: row.amount,
            sourceType: 'journal',
          ),
        );
      }
    }
    return movements;
  }

  Future<double> _beginningCash(String companyId, DateTime start) async {
    final List<BankCashRow> bankRows =
        await _localDataSource.getBankTransactions(companyId, endExclusive: start);
    double beginning = 0;
    for (final BankCashRow row in bankRows) {
      beginning += row.type == 'credit' ? row.amount : -row.amount;
    }
    final List<JournalCashRow> journalRows =
        await _localDataSource.getJournalEntries(companyId, endExclusive: start);
    for (final JournalCashRow row in journalRows) {
      if (CashFlowEngine.isCashAccount(row.debitAccount)) {
        beginning += row.amount;
      } else if (CashFlowEngine.isCashAccount(row.creditAccount)) {
        beginning -= row.amount;
      }
    }
    return beginning;
  }

  Future<double> _netProfit(String companyId, DateTimeRange range) async {
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

  static DateTime _startOf(DateTimeRange range) {
    return DateTime(range.start.year, range.start.month, range.start.day)
        .toUtc();
  }

  static DateTime _endExclusiveOf(DateTimeRange range) {
    return DateTime(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1))
        .toUtc();
  }

  static String _monthKey(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  static String _monthLabel(DateTime value) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }
}
