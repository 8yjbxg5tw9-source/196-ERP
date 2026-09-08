import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/cash_flow_pdf_exporter.dart';
import '../../domain/entities/cash_flow_monthly_point.dart';
import '../../domain/entities/cash_flow_statement_entity.dart';
import '../../domain/repositories/cash_flow_repository.dart';
import 'cash_flow_event.dart';
import 'cash_flow_state.dart';

/// Coordinates statement generation (direct / indirect), monthly liquidity
/// series, and PDF export for the cash flow workspace.
class CashFlowBloc extends Bloc<CashFlowEvent, CashFlowState> {
  CashFlowBloc({
    required CashFlowRepository repository,
    CashFlowPdfExporter exporter = const CashFlowPdfExporter(),
  })  : _repository = repository,
        _exporter = exporter,
        super(const CashFlowInitial()) {
    on<GenerateCashFlowReportEvent>(_onGenerate);
    on<ExportCashFlowPdfEvent>(_onExport);
  }

  final CashFlowRepository _repository;
  final CashFlowPdfExporter _exporter;

  Future<void> _onGenerate(
    GenerateCashFlowReportEvent event,
    Emitter<CashFlowState> emit,
  ) async {
    emit(const CashFlowLoading());
    final statementResult = await _repository.generateStatement(
      companyId: event.companyId,
      dateRange: event.range,
      method: event.method,
    );
    await statementResult.fold(
      (failure) async => emit(CashFlowError(failure.message)),
      (CashFlowStatementEntity statement) async {
        final monthlyResult = await _repository.getMonthlyMovements(
          companyId: event.companyId,
          dateRange: event.range,
        );
        final List<CashFlowMonthlyPoint> monthly = monthlyResult.fold(
          (_) => const <CashFlowMonthlyPoint>[],
          (List<CashFlowMonthlyPoint> value) => value,
        );
        emit(
          CashFlowLoaded(
            statement: statement,
            monthly: monthly,
          ),
        );
      },
    );
  }

  Future<void> _onExport(
    ExportCashFlowPdfEvent event,
    Emitter<CashFlowState> emit,
  ) async {
    final CashFlowState current = state;
    if (current is! CashFlowLoaded) {
      emit(const CashFlowError('Generate a statement before exporting.'));
      return;
    }
    try {
      final String path = await _exporter.export(current.statement);
      emit(
        CashFlowLoaded(
          statement: current.statement,
          monthly: current.monthly,
          exportedPath: path,
        ),
      );
    } on Object catch (error) {
      emit(CashFlowError('The statement could not be exported: $error'));
    }
  }
}
