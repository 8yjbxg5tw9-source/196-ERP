import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../domain/entities/split_allocation.dart';
import 'reconciliation_state.dart';

abstract class ReconciliationEvent extends Equatable {
  const ReconciliationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadWorkspaceEvent extends ReconciliationEvent {
  const LoadWorkspaceEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class ImportStatementEvent extends ReconciliationEvent {
  const ImportStatementEvent({
    required this.file,
    required this.companyId,
  });

  final File file;
  final String companyId;

  @override
  List<Object?> get props => <Object?>[file, companyId];
}

class TriggerAutoMatchEvent extends ReconciliationEvent {
  const TriggerAutoMatchEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class ConfirmMatchEvent extends ReconciliationEvent {
  const ConfirmMatchEvent({
    required this.transactionId,
    required this.documentId,
  });

  final String transactionId;
  final String documentId;

  @override
  List<Object?> get props => <Object?>[transactionId, documentId];
}

class ManualLinkEvent extends ReconciliationEvent {
  const ManualLinkEvent({
    required this.transactionId,
    required this.documentId,
  });

  final String transactionId;
  final String documentId;

  @override
  List<Object?> get props => <Object?>[transactionId, documentId];
}

class UnlinkTransactionEvent extends ReconciliationEvent {
  const UnlinkTransactionEvent(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => <Object?>[transactionId];
}

class SplitTransactionEvent extends ReconciliationEvent {
  const SplitTransactionEvent({
    required this.transactionId,
    required this.allocations,
  });

  final String transactionId;
  final List<SplitAllocation> allocations;

  @override
  List<Object?> get props => <Object?>[transactionId, allocations];
}

class FilterTransactionsEvent extends ReconciliationEvent {
  const FilterTransactionsEvent(this.filter);

  final ReconciliationFilter filter;

  @override
  List<Object?> get props => <Object?>[filter];
}
