import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/report_pdf_exporter.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';
import '../../domain/entities/cash_flow_entity.dart';
import '../../domain/entities/profit_and_loss_entity.dart';
import '../../domain/repositories/financial_report_repository.dart';
import 'financial_report_event.dart';
import 'financial_report_state.dart';

/// Coordinates statement generation, dashboard analytics, chart-of-accounts
/// balances, and PDF export for the reporting workspace.
class FinancialReportBloc
    extends Bloc<FinancialReportEvent, FinancialReportState> {
  FinancialReportBloc({
    required FinancialReportRepository repository,
    ReportPdfExporter exporter = const ReportPdfExporter(),
  })  : _repository = repository,
        _exporter = exporter,
        super(const FinancialReportInitial()) {
    on<FetchProfitAndLossEvent>(_onFetchProfitAndLoss);
    on<FetchCashFlowEvent>(_onFetchCashFlow);
    on<FetchChartOfAccountsEvent>(_onFetchChartOfAccounts);
    on<FetchDashboardAnalyticsEvent>(_onFetchDashboardAnalytics);
    on<ExportReportPdfEvent>(_onExportReportPdf);
  }

  final FinancialReportRepository _repository;
  final ReportPdfExporter _exporter;

  Future<void> _onFetchProfitAndLoss(
    FetchProfitAndLossEvent event,
    Emitter<FinancialReportState> emit,
  ) async {
    emit(const ReportLoading(label: 'Computing profit & loss…'));
    final result = await _repository.generateProfitAndLoss(
      event.companyId,
      event.range,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (ProfitAndLossEntity report) => emit(ProfitAndLossLoaded(report)),
    );
  }

  Future<void> _onFetchCashFlow(
    FetchCashFlowEvent event,
    Emitter<FinancialReportState> emit,
  ) async {
    emit(const ReportLoading(label: 'Computing cash flow…'));
    final result = await _repository.generateCashFlow(
      event.companyId,
      event.range,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (CashFlowEntity report) => emit(CashFlowLoaded(report)),
    );
  }

  Future<void> _onFetchChartOfAccounts(
    FetchChartOfAccountsEvent event,
    Emitter<FinancialReportState> emit,
  ) async {
    emit(const ReportLoading(label: 'Computing account balances…'));
    final result = await _repository.getChartOfAccountsBalances(
      event.companyId,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (balances) => emit(ChartOfAccountsLoaded(balances)),
    );
  }

  Future<void> _onFetchDashboardAnalytics(
    FetchDashboardAnalyticsEvent event,
    Emitter<FinancialReportState> emit,
  ) async {
    emit(const ReportLoading(label: 'Computing dashboard analytics…'));
    final result = await _repository.generateDashboardAnalytics(
      event.companyId,
      event.range,
    );
    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (DashboardAnalyticsEntity dashboard) =>
          emit(DashboardAnalyticsLoaded(dashboard)),
    );
  }

  Future<void> _onExportReportPdf(
    ExportReportPdfEvent event,
    Emitter<FinancialReportState> emit,
  ) async {
    final FinancialReportState current = state;
    try {
      if (current is ProfitAndLossLoaded) {
        final String path = await _exporter.exportProfitAndLoss(
          current.report,
        );
        emit(ReportExported(path));
      } else if (current is CashFlowLoaded) {
        final String path = await _exporter.exportCashFlow(current.report);
        emit(ReportExported(path));
      } else {
        emit(const ReportError('Generate a report before exporting.'));
      }
    } on Object catch (error) {
      emit(ReportError('The report could not be exported: $error'));
    }
  }
}
