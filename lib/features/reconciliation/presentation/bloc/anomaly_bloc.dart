import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../document_ocr/data/datasources/document_local_data_source.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../data/datasources/reconciliation_local_data_source.dart';
import '../../data/models/bank_transaction_model.dart';
import '../../domain/entities/anomaly_alert_entity.dart';
import '../../domain/services/anomaly_detection_engine.dart';

/// Fraud/anomaly scanner intents.
abstract class AnomalyEvent extends Equatable {
  const AnomalyEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class RunAnomalyScanEvent extends AnomalyEvent {
  const RunAnomalyScanEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class DismissAlertEvent extends AnomalyEvent {
  const DismissAlertEvent(this.alertId);

  final String alertId;

  @override
  List<Object?> get props => <Object?>[alertId];
}

/// Fraud/anomaly scanner state.
abstract class AnomalyState extends Equatable {
  const AnomalyState();

  @override
  List<Object?> get props => const <Object?>[];
}

class AnomalyInitial extends AnomalyState {
  const AnomalyInitial();
}

class AnomalyScanning extends AnomalyState {
  const AnomalyScanning();
}

class AnomalyScanComplete extends AnomalyState {
  const AnomalyScanComplete({
    required this.alerts,
    this.dismissedIds = const <String>{},
  });

  final List<AnomalyAlertEntity> alerts;
  final Set<String> dismissedIds;

  List<AnomalyAlertEntity> get visibleAlerts => alerts
      .where((AnomalyAlertEntity alert) => !dismissedIds.contains(alert.id))
      .toList(growable: false);

  AnomalyScanComplete copyWith({Set<String>? dismissedIds}) {
    return AnomalyScanComplete(
      alerts: alerts,
      dismissedIds: dismissedIds ?? this.dismissedIds,
    );
  }

  @override
  List<Object?> get props => <Object?>[alerts, dismissedIds];
}

class AnomalyError extends AnomalyState {
  const AnomalyError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// Runs the anomaly detection engine over a company's bank lines and invoices.
class AnomalyBloc extends Bloc<AnomalyEvent, AnomalyState> {
  AnomalyBloc({
    required AnomalyDetectionEngine engine,
    required ReconciliationLocalDataSource transactionsDataSource,
    required DocumentLocalDataSource documentDataSource,
  })  : _engine = engine,
        _transactionsDataSource = transactionsDataSource,
        _documentDataSource = documentDataSource,
        super(const AnomalyInitial()) {
    on<RunAnomalyScanEvent>(_onRunScan);
    on<DismissAlertEvent>(_onDismiss);
  }

  final AnomalyDetectionEngine _engine;
  final ReconciliationLocalDataSource _transactionsDataSource;
  final DocumentLocalDataSource _documentDataSource;

  Future<void> _onRunScan(
    RunAnomalyScanEvent event,
    Emitter<AnomalyState> emit,
  ) async {
    final String companyId = event.companyId.trim();
    if (companyId.isEmpty) {
      emit(const AnomalyError('Select a company before scanning.'));
      return;
    }
    emit(const AnomalyScanning());
    try {
      final List<BankTransactionModel> transactions =
          await _transactionsDataSource.getTransactions(companyId);
      final List<DocumentEntity> documents =
          await _documentDataSource.getDocuments(companyId);
      final Map<String, String> categories = <String, String>{
        for (final BankTransactionModel transaction in transactions)
          transaction.id: transaction.category,
      };
      final List<AnomalyAlertEntity> alerts = _engine.scan(
        companyId: companyId,
        transactions: transactions,
        documents: documents,
        categoriesByTransactionId: categories,
      );
      emit(AnomalyScanComplete(alerts: alerts));
    } on Failure catch (error) {
      emit(AnomalyError(error.message));
    } on Object catch (error) {
      emit(AnomalyError('The anomaly scan could not be completed.'));
    }
  }

  void _onDismiss(
    DismissAlertEvent event,
    Emitter<AnomalyState> emit,
  ) {
    final AnomalyState current = state;
    if (current is! AnomalyScanComplete) {
      return;
    }
    emit(
      current.copyWith(
        dismissedIds: <String>{...current.dismissedIds, event.alertId},
      ),
    );
  }
}
