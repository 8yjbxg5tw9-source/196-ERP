import 'package:equatable/equatable.dart';

enum BankTransactionType {
  credit,
  debit,
}

enum MatchStatus {
  unmatched,
  suggested,
  reconciled,
}

/// A normalized bank ledger line that can be matched to an approved document.
class BankTransactionEntity extends Equatable {
  const BankTransactionEntity({
    required this.id,
    required this.companyId,
    required this.transactionDate,
    required this.description,
    required this.amount,
    required this.type,
    this.counterpartyName,
    this.counterpartyVoen,
    this.referenceCode,
    this.matchedDocumentId,
    this.matchConfidence = 0,
    this.status = MatchStatus.unmatched,
  }) : assert(amount >= 0),
       assert(matchConfidence >= 0 && matchConfidence <= 1);

  final String id;
  final String companyId;
  final DateTime transactionDate;
  final String? counterpartyName;
  final String? counterpartyVoen;
  final String? referenceCode;
  final String description;
  final double amount;
  final BankTransactionType type;
  final String? matchedDocumentId;
  final double matchConfidence;
  final MatchStatus status;

  BankTransactionEntity copyWith({
    String? id,
    String? companyId,
    DateTime? transactionDate,
    String? counterpartyName,
    String? counterpartyVoen,
    String? referenceCode,
    String? description,
    double? amount,
    BankTransactionType? type,
    Object? matchedDocumentId = _copyWithUnset,
    double? matchConfidence,
    MatchStatus? status,
  }) {
    return BankTransactionEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      transactionDate: transactionDate ?? this.transactionDate,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyVoen: counterpartyVoen ?? this.counterpartyVoen,
      referenceCode: referenceCode ?? this.referenceCode,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      matchedDocumentId: identical(matchedDocumentId, _copyWithUnset)
          ? this.matchedDocumentId
          : matchedDocumentId as String?,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        transactionDate,
        counterpartyName,
        counterpartyVoen,
        referenceCode,
        description,
        amount,
        type,
        matchedDocumentId,
        matchConfidence,
        status,
      ];
}

const Object _copyWithUnset = Object();
