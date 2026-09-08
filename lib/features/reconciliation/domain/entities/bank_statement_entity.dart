import 'package:equatable/equatable.dart';

import 'bank_transaction_entity.dart';

/// An imported statement and the normalized transactions it produced.
class BankStatementEntity extends Equatable {
  const BankStatementEntity({
    required this.id,
    required this.companyId,
    required this.sourceFileName,
    required this.importedAt,
    required this.transactions,
  });

  final String id;
  final String companyId;
  final String sourceFileName;
  final DateTime importedAt;
  final List<BankTransactionEntity> transactions;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        sourceFileName,
        importedAt,
        transactions,
      ];
}
