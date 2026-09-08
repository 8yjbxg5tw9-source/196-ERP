import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../document_ocr/data/datasources/document_local_data_source.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_statement_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import '../../domain/entities/split_allocation.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../../domain/rules/reconciliation_rule_entity.dart';
import '../../domain/rules/rule_matching_evaluator.dart';
import '../../domain/rules/rule_repository.dart';
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
    RuleRepository? ruleRepository,
    RuleMatchingEvaluator ruleEvaluator = const RuleMatchingEvaluator(),
  })  : _matchingEngine = matchingEngine,
        _ruleRepository = ruleRepository,
        _ruleEvaluator = ruleEvaluator,
        _parsers = parsers ?? const <StatementParser>[
          CsvStatementParser(),
          ExcelStatementParser(),
          Mt940StatementParser(),
        ];

  static const double _splitTolerance = 0.01;

  final ReconciliationLocalDataSource _localDataSource;
  final DocumentLocalDataSource _documentDataSource;
  final MatchingEngine _matchingEngine;
  final RuleRepository? _ruleRepository;
  final RuleMatchingEvaluator _ruleEvaluator;
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
      final Map<String, String> ruleCategories =
          await _ruleCategories(normalizedCompanyId, parsed);
      final List<BankTransactionModel> models = parsed
          .map(
            (BankTransactionEntity transaction) =>
                BankTransactionModel.fromEntity(
              transaction,
              category:
                  ruleCategories[transaction.id] ?? 'bank_statement',
            ),
          )
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
  Future<Either<Failure, List<BankTransactionEntity>>> getTransactions(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<BankTransactionEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }

    try {
      final List<BankTransactionModel> transactions =
          await _localDataSource.getTransactions(normalizedCompanyId);
      return Right<Failure, List<BankTransactionEntity>>(transactions);
    } on DatabaseException catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        DatabaseFailure(
          message: 'Bank transactions could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        CacheFailure(
          message: 'Saved bank transactions could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<DocumentEntity>>> getCandidateDocuments(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<DocumentEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }

    try {
      final List<DocumentEntity> documents =
          await _documentDataSource.getDocuments(normalizedCompanyId);
      final List<DocumentEntity> candidates = documents
          .where(
            (DocumentEntity document) =>
                document.status == DocumentStatus.completed,
          )
          .toList(growable: false);
      return Right<Failure, List<DocumentEntity>>(candidates);
    } on DatabaseException catch (error) {
      return Left<Failure, List<DocumentEntity>>(
        DatabaseFailure(
          message: 'Approved invoices could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<DocumentEntity>>(
        CacheFailure(
          message: 'Approved invoices could not be read.',
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
      final _RuleApplication ruleApplication =
          await _ruleApplication(normalizedCompanyId, transactions);
      final Map<String, String> categories = <String, String>{
        for (final BankTransactionModel transaction in transactions)
          transaction.id: ruleApplication.categories[transaction.id] ??
              transaction.category,
      };
      final List<BankTransactionEntity> withRules = matched
          .map(
            (BankTransactionEntity transaction) =>
                ruleApplication.autoApproved.contains(transaction.id) &&
                        transaction.status == MatchStatus.unmatched
                    ? transaction.copyWith(
                        matchConfidence: 1.0,
                        status: MatchStatus.suggested,
                      )
                    : transaction,
          )
          .toList(growable: false);
      await _localDataSource.saveTransactions(
        withRules
            .map(
              (BankTransactionEntity transaction) =>
                  BankTransactionModel.fromEntity(
                transaction,
                category: categories[transaction.id] ?? 'bank_statement',
              ),
            )
            .toList(growable: false),
      );
      return Right<Failure, List<BankTransactionEntity>>(withRules);
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
      await _localDataSource.writeAuditLog(
        action: 'reconciliation_confirmed',
        details: 'Reconciled Bank Tx [$normalizedTransactionId] '
            'with Document [$normalizedDocumentId] by User',
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
      await _localDataSource.writeAuditLog(
        action: 'reconciliation_unlinked',
        details: 'Unlinked Bank Tx [$normalizedTransactionId] by User',
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

  @override
  Future<Either<Failure, List<BankTransactionEntity>>> splitTransaction(
    String transactionId,
    List<SplitAllocation> allocations,
  ) async {
    final String normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty || allocations.isEmpty) {
      return Left<Failure, List<BankTransactionEntity>>(
        const ValidationFailure(
          message: 'A transaction and at least one invoice are required.',
        ),
      );
    }

    try {
      final BankTransactionModel? transaction =
          await _localDataSource.getTransaction(normalizedTransactionId);
      if (transaction == null) {
        return Left<Failure, List<BankTransactionEntity>>(
          NotFoundFailure(
            message: 'Bank transaction $normalizedTransactionId was not found.',
          ),
        );
      }

      double allocatedTotal = 0;
      for (final SplitAllocation allocation in allocations) {
        if (allocation.amount <= 0 || !allocation.amount.isFinite) {
          return Left<Failure, List<BankTransactionEntity>>(
            const ValidationFailure(
              message: 'Each split amount must be greater than zero.',
            ),
          );
        }
        allocatedTotal += allocation.amount;
        final DocumentEntity? document =
            await _documentDataSource.getDocument(allocation.documentId);
        if (document == null) {
          return Left<Failure, List<BankTransactionEntity>>(
            NotFoundFailure(
              message: 'Invoice ${allocation.documentId} was not found.',
            ),
          );
        }
        if (document.companyId != transaction.companyId) {
          return Left<Failure, List<BankTransactionEntity>>(
            const ValidationFailure(
              message: 'An invoice belongs to a different company.',
            ),
          );
        }
        if (document.status != DocumentStatus.completed) {
          return Left<Failure, List<BankTransactionEntity>>(
            const ValidationFailure(
              message: 'Only an approved OCR invoice can be split.',
            ),
          );
        }
      }

      if (allocatedTotal > transaction.amount + _splitTolerance) {
        return Left<Failure, List<BankTransactionEntity>>(
          const ValidationFailure(
            message: 'The allocated amounts exceed the transaction total.',
          ),
        );
      }

      final int splitSeed = DateTime.now().toUtc().microsecondsSinceEpoch;
      final List<BankTransactionModel> children = <BankTransactionModel>[];
      for (int index = 0; index < allocations.length; index++) {
        final SplitAllocation allocation = allocations[index];
        children.add(
          BankTransactionModel(
            id: 'split-$splitSeed-$index',
            companyId: transaction.companyId,
            transactionDate: transaction.transactionDate,
            description:
                '${transaction.description} (split ${index + 1}/${allocations.length})',
            amount: allocation.amount,
            type: transaction.type,
            counterpartyName: transaction.counterpartyName,
            counterpartyVoen: transaction.counterpartyVoen,
            referenceCode: transaction.referenceCode,
            matchedDocumentId: allocation.documentId,
            matchConfidence: 1.0,
            status: MatchStatus.reconciled,
            category: transaction.category,
          ),
        );
      }

      final double residual = transaction.amount - allocatedTotal;
      if (residual > _splitTolerance) {
        children.add(
          BankTransactionModel(
            id: 'split-$splitSeed-residual',
            companyId: transaction.companyId,
            transactionDate: transaction.transactionDate,
            description: '${transaction.description} (unallocated remainder)',
            amount: residual,
            type: transaction.type,
            counterpartyName: transaction.counterpartyName,
            counterpartyVoen: transaction.counterpartyVoen,
            referenceCode: transaction.referenceCode,
            status: MatchStatus.unmatched,
            category: transaction.category,
          ),
        );
      }

      await _localDataSource.replaceTransactionWithChildren(
        normalizedTransactionId,
        children,
      );
      await _localDataSource.writeAuditLog(
        action: 'reconciliation_split',
        details: 'Split Bank Tx [$normalizedTransactionId] into '
            '${allocations.length} allocations by User',
      );
      return Right<Failure, List<BankTransactionEntity>>(children);
    } on DatabaseException catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        DatabaseFailure(
          message: 'The transaction split could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<BankTransactionEntity>>(
        CacheFailure(
          message: 'The transaction split could not be saved locally.',
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

  Future<Map<String, String>> _ruleCategories(
    String companyId,
    List<BankTransactionEntity> transactions,
  ) async {
    final _RuleApplication application =
        await _ruleApplication(companyId, transactions);
    return application.categories;
  }

  Future<_RuleApplication> _ruleApplication(
    String companyId,
    List<BankTransactionEntity> transactions,
  ) async {
    final RuleRepository? repository = _ruleRepository;
    if (repository == null) {
      return const _RuleApplication();
    }
    final List<ReconciliationRuleEntity> rules = await repository
        .getRules(companyId)
        .then(
          (Either<Failure, List<ReconciliationRuleEntity>> result) => result.fold(
            (Failure failure) => const <ReconciliationRuleEntity>[],
            (List<ReconciliationRuleEntity> list) => list,
          ),
        );
    final Map<String, String> categories = <String, String>{};
    final Set<String> autoApproved = <String>{};
    for (final BankTransactionEntity transaction in transactions) {
      final ReconciliationRuleEntity? rule = _ruleEvaluator.evaluate(
        transaction,
        rules,
      );
      if (rule == null) {
        continue;
      }
      switch (rule.action.type) {
        case RuleActionType.categorize:
          if (rule.action.value.trim().isNotEmpty) {
            categories[transaction.id] = rule.action.value.trim();
          }
          break;
        case RuleActionType.assignAccount:
          if (rule.action.value.trim().isNotEmpty) {
            categories[transaction.id] = rule.action.value.trim();
          }
          break;
        case RuleActionType.autoApprove:
          autoApproved.add(transaction.id);
          break;
      }
    }
    return _RuleApplication(
      categories: categories,
      autoApproved: autoApproved,
    );
  }

  String _newStatementId() {
    return 'statement-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}

class _RuleApplication {
  const _RuleApplication({
    this.categories = const <String, String>{},
    this.autoApproved = const <String>{},
  });

  final Map<String, String> categories;
  final Set<String> autoApproved;
}
