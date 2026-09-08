import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/bank_statement_entity.dart';
import '../entities/bank_transaction_entity.dart';

/// Coordinates bank statement imports and document reconciliation.
abstract interface class ReconciliationRepository {
  Future<Either<Failure, BankStatementEntity>> parseAndSaveStatement(
    File file,
    String companyId,
  );

  Future<Either<Failure, List<BankTransactionEntity>>> runAutoMatching(
    String companyId,
  );

  Future<Either<Failure, BankTransactionEntity>> confirmMatch(
    String transactionId,
    String documentId,
  );

  Future<Either<Failure, BankTransactionEntity>> manualUnmatch(
    String transactionId,
  );
}
