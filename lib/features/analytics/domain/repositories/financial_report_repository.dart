import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../../core/errors/failures.dart';
import '../entities/analytics_dashboard_entity.dart';
import '../entities/cash_flow_entity.dart';
import '../entities/chart_of_accounts.dart';
import '../entities/profit_and_loss_entity.dart';

/// Computes the primary financial statements, chart-of-accounts balances, and
/// executive dashboard analytics in real time from the local SQLite ledger.
abstract interface class FinancialReportRepository {
  Future<Either<Failure, ProfitAndLossEntity>> generateProfitAndLoss(
    String companyId,
    DateTimeRange dateRange,
  );

  Future<Either<Failure, CashFlowEntity>> generateCashFlow(
    String companyId,
    DateTimeRange dateRange,
  );

  Future<Either<Failure, List<AccountBalanceEntity>>>
      getChartOfAccountsBalances(String companyId);

  Future<Either<Failure, DashboardAnalyticsEntity>> generateDashboardAnalytics(
    String companyId,
    DateTimeRange dateRange,
  );
}
