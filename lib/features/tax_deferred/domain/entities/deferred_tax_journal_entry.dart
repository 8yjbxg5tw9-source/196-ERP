import 'package:equatable/equatable.dart';

/// One self-balancing ledger line generated from the period-end net deferred
/// tax movement.
class DeferredTaxJournalEntry extends Equatable {
  const DeferredTaxJournalEntry({
    required this.companyId,
    required this.entryDate,
    required this.description,
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.sourceId,
  });

  final String companyId;
  final DateTime entryDate;
  final String description;
  final String debitAccount;
  final String creditAccount;
  final double amount;
  final String sourceId;

  @override
  List<Object?> get props => <Object?>[
        companyId,
        entryDate,
        description,
        debitAccount,
        creditAccount,
        amount,
        sourceId,
      ];
}
