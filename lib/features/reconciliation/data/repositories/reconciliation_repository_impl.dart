import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../document_ocr/data/datasources/document_local_data_source.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_statement_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../../domain/services/matching_engine.dart';
import '../datasources/reconciliation_local_data_source.dart';
import '../models/bank_transaction_model.dart';
import '../parsers/csv_statement_parser.dart';
import '../parsers/excel_statement_parser.dart';
import '../parsers/mt940_statement_parser.dart';
import '../parsers/statement_parser.dart';

class ReconciliationRepositoryImpl implements ReconciliationRepository {
  ReconciliationRepositoryImpl(
    this._localDataSource,
    this._documentDataSource, {
    MatchingEngine matchingEngine = const MatchingEngine(),
    List<StatementParser>? parsers,
  })  : _matchingEngine = matchingEngine,
        _parsers = parsers ?? const <StatementParser>[
          CsvStatementParser(),
          ExcelStatementParser(),
          Mt940StatementParser(),
        ];

  final ReconciliationLocalDataSource _localDataSource;
  final DocumentLocalDataSource _documentDataSource;
  final MatchingEngine _matchingEngine;
  final List<StatementParser> _parsers;

  @override
  Future<Either<Failure, BankStatementEntity>> parseAndSaveStatement(
    File file,
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, BankStatementEntity>(
        const ValidationFailure(message: 'Select a company before importing.'),
      );
    }

    try {
      if (!await file.exists()) {
        return Left<Failure, BankStatementEntity>(
          const ValidationFailure(message: 'The selected statement does not exist.'),
        );
      }
      final StatementParser parser = _parserFor(file);
      final List<BankTransactionEntity> parsed = await parser.parse(
        file,
        normalizedCompanyId,
      );
      final List<BankTransactionModel> models = parsed
          .map(BankTransactionModel.fromEntity)
          .toList(growable: false);
      await _localDataSource.saveTransactions(models);
      return Right<Failure, BankStatementEntity>(
        BankStatementEntity(
          id: _newStatementId(),
          companyId: normalizedCompanyId,
          sourceFileName: file.uri.pathSegments.isEmpty
              ? file.path
              : file.uri.pathSegments.last,
          importedAt: DateTime.now().toUtc(),
          transactions: parsed,
        ),
      );
    } on StatementParserException catch (error) {
      return Left<Failure, BankStatementEntity>(
        ParsingFailure(
          message: error.message.toString(),
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, BankStatementEntity>(
        ParsingFailure(
          message: 'The bank statement format is invalid.',
          cause: error,
        ),
      );
    } on FileSystemException catch (error) {
      return Left<Failure, BankStatementEntity>(
        CacheFailure(
          message: 'The bank statement could not be read.',
          cause: error,
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, BankStatementEntity>(
        DatabaseFailure(
          message: 'The imported bank statement could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, BankStatementEntity>(
        CacheFailure(
          message: 'The bank statement could not be imported.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<BankTransactionEntity>>> runAutoMatching(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<BankTransactionEntity>>(
        const ValidationFailure(message: 'Select a company before matching.'),
      );
    }

    try {
      final List<BankTransactionModel> transactions =
          await _localDataSource.getTransactions(normalizedCompanyId);
      final List<DocumentEntity> documents =
          await _documentDataSource.getDocuments(normalizedCompanyId);
      final List<BankTransactionEntity> matched = _matchingEngine
          .matchTransactions(transactions, documents);
      final Map<String, String> categories = <String, String>{
        for (final BankTransactionModel transaction in transactions)
          transaction.id: transaction.category,
      };
      await _localDataSource.saveTransactions(
        matched
            .map(
              (BankTransactionEntity transaction) =>
                  BankTransactionModel.fromEntity(
                transaction,
                category: categories[transaction.id] ?? 'bank_statement',
              ),
            )
            .toList(growable: false),
      );
      return Right<Failure, List<BankTransactionEntity>>(matched);
    } on DatabaseException catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        DatabaseFailure(
          message: 'Bank transactions or invoices could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        ParsingFailure(
          message: 'Saved reconciliation data is invalid.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        CacheFailure(
          message: 'Automatic bank reconciliation could not be completed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, BankTransactionEntity>> confirmMatch(
    String transactionId,
    String documentId,
  ) async {
    final String normalizedTransactionId = transactionId.trim();
    final String normalizedDocumentId = documentId.trim();
    if (normalizedTransactionId.isEmpty || normalizedDocumentId.isEmpty) {
      return Left<Failure, BankTransactionEntity>(
        const ValidationFailure(
          message: 'A transaction and document are required to confirm a match.',
        ),
      );
    }

    try {
      final BankTransactionModel? transaction =
          await _localDataSource.getTransaction(normalizedTransactionId);
      if (transaction == null) {
        return Left<Failure, BankTransactionEntity>(
          NotFoundFailure(
            message: 'Bank transaction $normalizedTransactionId was not found.',
          ),
        );
      }
      final DocumentEntity? document =
          await _documentDataSource.getDocument(normalizedDocumentId);
      if (document == null) {
        return Left<Failure, BankTransactionEntity>(
          NotFoundFailure(
            message: 'Invoice $normalizedDocumentId was not found.',
          ),
        );
      }
      if (document.companyId != transaction.companyId) {
        return Left<Failure, BankTransactionEntity>(
          const ValidationFailure(
            message: 'The transaction and invoice belong to different companies.',
          ),
        );
      }
      if (document.status != DocumentStatus.completed) {
        return Left<Failure, BankTransactionEntity>(
          const ValidationFailure(
            message: 'Only an approved OCR invoice can be reconciled.',
          ),
        );
      }

      final BankTransactionEntity reconciled = transaction.copyWith(
        matchedDocumentId: normalizedDocumentId,
        matchConfidence: 1.0,
        status: MatchStatus.reconciled,
      );
      // updateTransaction writes document_id, confidence, status, and the
      // reconciled flag in one SQLite transaction.
      await _localDataSource.updateTransaction(
        BankTransactionModel.fromEntity(
          reconciled,
          category: transaction.category,
        ),
      );
      return Right<Failure, BankTransactionEntity>(reconciled);
    } on DatabaseException catch (error) {
      return Left<Failure, BankTransactionEntity>(
        DatabaseFailure(
          message: 'The reconciliation confirmation could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, BankTransactionEntity>(
        CacheFailure(
          message: 'The reconciliation confirmation could not be saved locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, BankTransactionEntity>> manualUnmatch(
    String transactionId,
  ) async {
    final String normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      return Left<Failure, BankTransactionEntity>(
        const ValidationFailure(message: 'A transaction is required to unmatch.'),
      );
    }

    try {
      final BankTransactionModel? transaction =
          await _localDataSource.getTransaction(normalizedTransactionId);
      if (transaction == null) {
        return Left<Failure, BankTransactionEntity>(
          NotFoundFailure(
            message: 'Bank transaction $normalizedTransactionId was not found.',
          ),
        );
      }
      final BankTransactionEntity unmatched = transaction.copyWith(
        matchedDocumentId: null,
        matchConfidence: 0,
        status: MatchStatus.unmatched,
      );
      await _localDataSource.updateTransaction(
        BankTransactionModel.fromEntity(
          unmatched,
          category: transaction.category,
        ),
      );
      return Right<Failure, BankTransactionEntity>(unmatched);
    } on DatabaseException catch (error) {
      return Left<Failure, BankTransactionEntity>(
        DatabaseFailure(
          message: 'The bank transaction could not be unmatched.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, BankTransactionEntity>(
        CacheFailure(
          message: 'The bank transaction could not be unmatched locally.',
          cause: error,
        ),
      );
    }
  }

  StatementParser _parserFor(File file) {
    for (final StatementParser parser in _parsers) {
      if (parser.supports(file.path)) {
        return parser;
      }
    }
    throw StatementParserException(
      'Unsupported bank statement format: ${file.path}',
    );
  }

  String _newStatementId() {
    return 'statement-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}
