import 'package:equatable/equatable.dart';

import '../../domain/entities/analytics_dashboard_entity.dart';
import '../../domain/entities/cash_flow_entity.dart';
import '../../domain/entities/chart_of_accounts.dart';
import '../../domain/entities/profit_and_loss_entity.dart';

abstract class FinancialReportState extends Equatable {
  const FinancialReportState();

  @override
  List<Object?> get props => const <Object?>[];
}

class FinancialReportInitial extends FinancialReportState {
  const FinancialReportInitial();
}

class ReportLoading extends FinancialReportState {
  const ReportLoading({this.label});

  final String? label;

  @override
  List<Object?> get props => <Object?>[label];
}

class ProfitAndLossLoaded extends FinancialReportState {
  const ProfitAndLossLoaded(this.report);

  final ProfitAndLossEntity report;

  @override
  List<Object?> get props => <Object?>[report];
}

class CashFlowLoaded extends FinancialReportState {
  const CashFlowLoaded(this.report);

  final CashFlowEntity report;

  @override
  List<Object?> get props => <Object?>[report];
}

class ChartOfAccountsLoaded extends FinancialReportState {
  const ChartOfAccountsLoaded(this.balances);

  final List<AccountBalanceEntity> balances;

  @override
  List<Object?> get props => <Object?>[balances];
}

class DashboardAnalyticsLoaded extends FinancialReportState {
  const DashboardAnalyticsLoaded(this.dashboard);

  final DashboardAnalyticsEntity dashboard;

  @override
  List<Object?> get props => <Object?>[dashboard];
}

class ReportError extends FinancialReportState {
  const ReportError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class ReportExported extends FinancialReportState {
  const ReportExported(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => <Object?>[filePath];
}
