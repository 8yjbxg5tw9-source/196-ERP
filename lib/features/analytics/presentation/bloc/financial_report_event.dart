import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

abstract class FinancialReportEvent extends Equatable {
  const FinancialReportEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class FetchProfitAndLossEvent extends FinancialReportEvent {
  const FetchProfitAndLossEvent({
    required this.companyId,
    required this.range,
  });

  final String companyId;
  final DateTimeRange range;

  @override
  List<Object?> get props => <Object?>[companyId, range];
}

class FetchCashFlowEvent extends FinancialReportEvent {
  const FetchCashFlowEvent({
    required this.companyId,
    required this.range,
  });

  final String companyId;
  final DateTimeRange range;

  @override
  List<Object?> get props => <Object?>[companyId, range];
}

class FetchChartOfAccountsEvent extends FinancialReportEvent {
  const FetchChartOfAccountsEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class FetchDashboardAnalyticsEvent extends FinancialReportEvent {
  const FetchDashboardAnalyticsEvent({
    required this.companyId,
    required this.range,
  });

  final String companyId;
  final DateTimeRange range;

  @override
  List<Object?> get props => <Object?>[companyId, range];
}

class ExportReportPdfEvent extends FinancialReportEvent {
  const ExportReportPdfEvent();
}
