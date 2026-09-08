import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/export_models.dart';
import '../../../../core/services/export_service.dart';
import '../../domain/entities/audit_log_entity.dart';
import '../../domain/entities/integrity_check_result.dart';
import '../../domain/repositories/audit_repository.dart';
import 'audit_event.dart';
import 'audit_state.dart';

/// Loads and filters the audit trail and exports it to PDF.
class AuditBloc extends Bloc<AuditEvent, AuditState> {
  AuditBloc({
    required AuditRepository repository,
    required ExportService exportService,
  })  : _repository = repository,
        _exportService = exportService,
        super(const AuditInitial()) {
    on<FetchAuditLogsEvent>(_onFetchAuditLogs);
    on<ExportAuditLogsPdfEvent>(_onExportPdf);
    on<RunIntegrityVerificationEvent>(_onVerifyIntegrity);
  }

  final AuditRepository _repository;
  final ExportService _exportService;

  Future<void> _onFetchAuditLogs(
    FetchAuditLogsEvent event,
    Emitter<AuditState> emit,
  ) async {
    emit(const AuditLoading());
    final result = await _repository.getLogs(
      companyId: event.companyId,
      from: event.range?.start,
      to: event.range?.end,
      action: event.actionFilter,
      userId: event.userId,
      search: event.search,
    );
    result.fold(
      (failure) => emit(AuditError(failure.message)),
      (logs) => emit(AuditLoaded(logs)),
    );
  }

  Future<void> _onExportPdf(
    ExportAuditLogsPdfEvent event,
    Emitter<AuditState> emit,
  ) async {
    final AuditState current = state;
    if (current is! AuditLoaded || current.logs.isEmpty) {
      emit(const AuditError('Nothing to export yet.'));
      return;
    }
    try {
      final File file = await _exportService.generatePdfReport(
        _toReportData(current.logs),
        'audit',
      );
      emit(AuditLoaded(current.logs, message: 'Exported to ${file.path}'));
    } on Object catch (error) {
      emit(AuditError('Audit export failed: $error'));
    }
  }

  Future<void> _onVerifyIntegrity(
    RunIntegrityVerificationEvent event,
    Emitter<AuditState> emit,
  ) async {
    final result = await _repository.verifyAuditChainIntegrity(
      event.companyId,
    );
    result.fold(
      (failure) => emit(AuditError(failure.message)),
      (IntegrityCheckResult integrity) =>
          emit(IntegrityCheckComplete(integrity)),
    );
  }

  ReportData _toReportData(List<AuditLogEntity> logs) {
    final DateFormat stamp = DateFormat('yyyy-MM-dd HH:mm');
    final List<ReportRow> rows = logs.map((AuditLogEntity log) {
      return ReportRow(
        label: '${stamp.format(log.timestamp.toLocal())} · ${log.userName} '
            '(${log.userRole}) — ${log.action.label} ${log.entityName}'
            '${log.entityId == null ? '' : ' ${log.entityId}'}',
        value: _detailOf(log),
      );
    }).toList(growable: false);

    return ReportData(
      title: 'Audit Log Export',
      periodLabel: 'Generated ${DateFormat.yMMMMd().format(DateTime.now())}',
      currency: 'AZN',
      sections: <ReportSection>[
        ReportSection(title: 'Audit trail entries', rows: rows),
      ],
    );
  }

  static String _detailOf(AuditLogEntity log) {
    final Map<String, ({Object? before, Object? after})> changes =
        log.changedFields();
    if (changes.isEmpty) {
      return 'No field changes recorded.';
    }
    final List<String> parts = changes.entries
        .take(5)
        .map((MapEntry<String, ({Object? before, Object? after})> entry) {
          return '${entry.key}: ${entry.value.before ?? '∅'} → '
              '${entry.value.after ?? '∅'}';
        })
        .toList(growable: false);
    final String suffix = changes.length > 5 ? '…' : '';
    return parts.join('; ') + suffix;
  }
}
