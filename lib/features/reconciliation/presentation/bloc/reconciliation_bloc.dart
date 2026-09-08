import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_statement_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import '../../domain/entities/split_allocation.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import 'reconciliation_event.dart';
import 'reconciliation_state.dart';

/// Coordinates imports, automatic matching, manual overrides, filtering, and
/// instant SQLite persistence for the dual-pane reconciliation workspace.
class ReconciliationBloc
    extends Bloc<ReconciliationEvent, ReconciliationState> {
  ReconciliationBloc({required ReconciliationRepository repository})
      : _repository = repository,
        super(const ReconciliationInitial()) {
    on<LoadWorkspaceEvent>(_onLoadWorkspace);
    on<ImportStatementEvent>(_onImportStatement);
    on<TriggerAutoMatchEvent>(_onTriggerAutoMatch);
    on<ConfirmMatchEvent>(_onConfirmMatch);
    on<ManualLinkEvent>(_onManualLink);
    on<UnlinkTransactionEvent>(_onUnlinkTransaction);
    on<SplitTransactionEvent>(_onSplitTransaction);
    on<FilterTransactionsEvent>(_onFilterTransactions);
  }

  final ReconciliationRepository _repository;
  String? _companyId;
  ReconciliationFilter _filter = const ReconciliationFilter();

  Future<void> _onLoadWorkspace(
    LoadWorkspaceEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    _companyId = event.companyId.trim();
    emit(const ReconciliationLoading());
    await _loadWorkspaceAndEmit(emit);
  }

  Future<void> _onImportStatement(
    ImportStatementEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    _companyId = event.companyId.trim();
    emit(const ReconciliationLoading());
    final Either<Failure, BankStatementEntity> result =
        await _repository.parseAndSaveStatement(event.file, _companyId!);
    final Failure? failure = result.fold(
      (Failure value) => value,
      (BankStatementEntity _) => null,
    );
    if (failure != null) {
      emit(ReconciliationError(message: failure.message));
      return;
    }
    await _loadWorkspaceAndEmit(emit);
  }

  Future<void> _onTriggerAutoMatch(
    TriggerAutoMatchEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    _companyId = event.companyId.trim();
    final List<BankTransactionEntity> transactions =
        _transactionsSnapshot(state);
    final List<DocumentEntity> documents = _documentsSnapshot(state);
    emit(
      ReconciliationProcessing(
        progress: 0.05,
        message: 'Loading bank transactions…',
        transactions: transactions,
        candidateDocuments: documents,
        filter: _filter,
      ),
    );
    final Either<Failure, List<BankTransactionEntity>> result =
        await _repository.runAutoMatching(_companyId!);
    emit(
      ReconciliationProcessing(
        progress: 0.75,
        message: 'Ranking approved invoices…',
        transactions: transactions,
        candidateDocuments: documents,
        filter: _filter,
      ),
    );
    final Failure? failure = result.fold(
      (Failure value) => value,
      (List<BankTransactionEntity> _) => null,
    );
    if (failure != null) {
      emit(ReconciliationError(message: failure.message));
      return;
    }
    emit(
      ReconciliationProcessing(
        progress: 1.0,
        message: 'Refreshing workspace…',
        transactions: transactions,
        candidateDocuments: documents,
        filter: _filter,
      ),
    );
    await _loadWorkspaceAndEmit(emit);
  }

  Future<void> _onConfirmMatch(
    ConfirmMatchEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    final Either<Failure, BankTransactionEntity> result =
        await _repository.confirmMatch(event.transactionId, event.documentId);
    await _afterAction(result, emit);
  }

  Future<void> _onManualLink(
    ManualLinkEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    final Either<Failure, BankTransactionEntity> result =
        await _repository.confirmMatch(event.transactionId, event.documentId);
    await _afterAction(result, emit);
  }

  Future<void> _onUnlinkTransaction(
    UnlinkTransactionEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    final Either<Failure, BankTransactionEntity> result =
        await _repository.manualUnmatch(event.transactionId);
    await _afterAction(result, emit);
  }

  Future<void> _onSplitTransaction(
    SplitTransactionEvent event,
    Emitter<ReconciliationState> emit,
  ) async {
    final Either<Failure, List<BankTransactionEntity>> result =
        await _repository.splitTransaction(
      event.transactionId,
      event.allocations,
    );
    final Failure? failure = result.fold(
      (Failure value) => value,
      (List<BankTransactionEntity> _) => null,
    );
    if (failure != null) {
      emit(_errorWithSnapshot(failure.message));
      return;
    }
    await _loadWorkspaceAndEmit(emit);
  }

  Future<void> _afterAction(
    Either<Failure, BankTransactionEntity> result,
    Emitter<ReconciliationState> emit,
  ) async {
    final Failure? failure = result.fold(
      (Failure value) => value,
      (BankTransactionEntity _) => null,
    );
    if (failure != null) {
      emit(_errorWithSnapshot(failure.message));
      return;
    }
    await _loadWorkspaceAndEmit(emit);
  }

  void _onFilterTransactions(
    FilterTransactionsEvent event,
    Emitter<ReconciliationState> emit,
  ) {
    _filter = event.filter;
    final ReconciliationState current = state;
    final List<BankTransactionEntity> transactions =
        _transactionsSnapshot(current);
    final List<DocumentEntity> documents = _documentsSnapshot(current);
    emit(
      ReconciliationLoaded(
        transactions: transactions,
        candidateDocuments: documents,
        filter: _filter,
      ),
    );
  }

  Future<void> _loadWorkspaceAndEmit(
    Emitter<ReconciliationState> emit,
  ) async {
    final String? companyId = _companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      emit(
        const ReconciliationError(
          message: 'Select an active company before using reconciliation.',
        ),
      );
      return;
    }

    final Either<Failure, List<BankTransactionEntity>> transactionsResult =
        await _repository.getTransactions(companyId);
    final Failure? transactionsFailure = transactionsResult.fold(
      (Failure value) => value,
      (List<BankTransactionEntity> _) => null,
    );
    if (transactionsFailure != null) {
      emit(ReconciliationError(message: transactionsFailure.message));
      return;
    }

    final Either<Failure, List<DocumentEntity>> documentsResult =
        await _repository.getCandidateDocuments(companyId);
    final Failure? documentsFailure = documentsResult.fold(
      (Failure value) => value,
      (List<DocumentEntity> _) => null,
    );
    if (documentsFailure != null) {
      emit(ReconciliationError(message: documentsFailure.message));
      return;
    }

    final List<BankTransactionEntity> transactions = transactionsResult.fold(
      (Failure _) => const <BankTransactionEntity>[],
      (List<BankTransactionEntity> value) => value,
    );
    final List<DocumentEntity> documents = documentsResult.fold(
      (Failure _) => const <DocumentEntity>[],
      (List<DocumentEntity> value) => value,
    );
    emit(
      ReconciliationLoaded(
        transactions: transactions,
        candidateDocuments: documents,
        filter: _filter,
      ),
    );
  }

  ReconciliationError _errorWithSnapshot(String message) {
    final ReconciliationState current = state;
    return ReconciliationError(
      message: message,
      transactions: _transactionsSnapshot(current),
      candidateDocuments: _documentsSnapshot(current),
      filter: _filter,
    );
  }

  List<BankTransactionEntity> _transactionsSnapshot(
    ReconciliationState current,
  ) {
    switch (current) {
      case ReconciliationLoaded value:
        return value.transactions;
      case ReconciliationError value:
        return value.transactions ?? const <BankTransactionEntity>[];
      default:
        return const <BankTransactionEntity>[];
    }
  }

  List<DocumentEntity> _documentsSnapshot(ReconciliationState current) {
    switch (current) {
      case ReconciliationLoaded value:
        return value.candidateDocuments;
      case ReconciliationError value:
        return value.candidateDocuments ?? const <DocumentEntity>[];
      default:
        return const <DocumentEntity>[];
    }
  }
}
