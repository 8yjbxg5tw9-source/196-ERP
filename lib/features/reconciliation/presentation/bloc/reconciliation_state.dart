import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';

/// Status dimension used by the workspace filter bar.
enum ReconciliationMatchFilter { all, reconciled, suggested, unmatched }

/// Immutable filter criteria applied to the loaded bank transactions.
class ReconciliationFilter extends Equatable {
  const ReconciliationFilter({
    this.dateRange,
    this.status = ReconciliationMatchFilter.all,
    this.minAmount,
    this.maxAmount,
    this.query = '',
  });

  final DateTimeRange? dateRange;
  final ReconciliationMatchFilter status;
  final double? minAmount;
  final double? maxAmount;
  final String query;

  bool get isDefault =>
      dateRange == null &&
      status == ReconciliationMatchFilter.all &&
      minAmount == null &&
      maxAmount == null &&
      query.trim().isEmpty;

  ReconciliationFilter copyWith({
    Object? dateRange = _unset,
    ReconciliationMatchFilter? status,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    String? query,
  }) {
    return ReconciliationFilter(
      dateRange: identical(dateRange, _unset)
          ? this.dateRange
          : dateRange as DateTimeRange?,
      status: status ?? this.status,
      minAmount: identical(minAmount, _unset)
          ? this.minAmount
          : minAmount as double?,
      maxAmount: identical(maxAmount, _unset)
          ? this.maxAmount
          : maxAmount as double?,
      query: query ?? this.query,
    );
  }

  bool matches(BankTransactionEntity transaction) {
    switch (status) {
      case ReconciliationMatchFilter.reconciled:
        if (transaction.status != MatchStatus.reconciled) {
          return false;
        }
        break;
      case ReconciliationMatchFilter.suggested:
        if (transaction.status != MatchStatus.suggested) {
          return false;
        }
        break;
      case ReconciliationMatchFilter.unmatched:
        if (transaction.status != MatchStatus.unmatched) {
          return false;
        }
        break;
      case ReconciliationMatchFilter.all:
        break;
    }
    if (dateRange != null) {
      final DateTime start = DateTime(
        dateRange!.start.year,
        dateRange!.start.month,
        dateRange!.start.day,
      );
      final DateTime end = DateTime(
            dateRange!.end.year,
            dateRange!.end.month,
            dateRange!.end.day,
          ).add(const Duration(days: 1));
      final DateTime transactionDate = transaction.transactionDate;
      if (transactionDate.isBefore(start) ||
          !transactionDate.isBefore(end)) {
        return false;
      }
    }
    if (minAmount != null && transaction.amount < minAmount!) {
      return false;
    }
    if (maxAmount != null && transaction.amount > maxAmount!) {
      return false;
    }
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      final String searchable =
          '${transaction.description} '
          '${transaction.counterpartyName ?? ''} '
          '${transaction.counterpartyVoen ?? ''} '
          '${transaction.referenceCode ?? ''}'
              .toLowerCase();
      if (!searchable.contains(normalizedQuery)) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Object?> get props =>
      <Object?>[dateRange, status, minAmount, maxAmount, query];
}

const Object _unset = Object();

abstract class ReconciliationState extends Equatable {
  const ReconciliationState();

  @override
  List<Object?> get props => const <Object?>[];
}

class ReconciliationInitial extends ReconciliationState {
  const ReconciliationInitial();
}

class ReconciliationLoading extends ReconciliationState {
  const ReconciliationLoading();
}

class ReconciliationProcessing extends ReconciliationState {
  const ReconciliationProcessing({
    this.progress = 0,
    this.message = 'Processing…',
    this.transactions,
    this.candidateDocuments,
    this.filter,
  });

  final double progress;
  final String message;
  final List<BankTransactionEntity>? transactions;
  final List<DocumentEntity>? candidateDocuments;
  final ReconciliationFilter? filter;

  bool get hasWorkspace =>
      transactions != null && candidateDocuments != null && filter != null;

  @override
  List<Object?> get props =>
      <Object?>[progress, message, transactions, candidateDocuments, filter];
}

class ReconciliationLoaded extends ReconciliationState {
  const ReconciliationLoaded({
    required this.transactions,
    required this.candidateDocuments,
    this.filter = const ReconciliationFilter(),
  });

  final List<BankTransactionEntity> transactions;
  final List<DocumentEntity> candidateDocuments;
  final ReconciliationFilter filter;

  List<BankTransactionEntity> get filteredTransactions =>
      transactions.where(filter.matches).toList(growable: false);

  @override
  List<Object?> get props =>
      <Object?>[transactions, candidateDocuments, filter];
}

class ReconciliationError extends ReconciliationState {
  const ReconciliationError({
    required this.message,
    this.transactions,
    this.candidateDocuments,
    this.filter,
  });

  final String message;
  final List<BankTransactionEntity>? transactions;
  final List<DocumentEntity>? candidateDocuments;
  final ReconciliationFilter? filter;

  bool get hasWorkspace =>
      transactions != null && candidateDocuments != null && filter != null;

  @override
  List<Object?> get props =>
      <Object?>[message, transactions, candidateDocuments, filter];
}
