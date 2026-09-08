import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/vector_math.dart';
import '../../domain/entities/tax_query_entity.dart';
import '../../domain/entities/tax_rule_entity.dart';
import '../../domain/repositories/tax_copilot_repository.dart';
import '../datasources/llm_remote_data_source.dart';
import '../datasources/tax_copilot_local_data_source.dart';
import '../models/tax_query_model.dart';
import '../models/tax_rule_model.dart';

/// Coordinates query embedding, local cosine retrieval, LLM grounding, and
/// company-scoped query history.
class TaxCopilotRepositoryImpl implements TaxCopilotRepository {
  const TaxCopilotRepositoryImpl(
    this._localDataSource,
    this._llmDataSource,
  );

  final TaxCopilotLocalDataSource _localDataSource;
  final LlmRemoteDataSource _llmDataSource;

  @override
  Future<Either<Failure, List<TaxRuleEntity>>> searchRelevantTaxRules(
    String queryVector,
  ) async {
    final List<double>? vector = decodeVector(queryVector);
    if (vector == null) {
      return Left<Failure, List<TaxRuleEntity>>(
        const ValidationFailure(
          message: 'The query embedding is not a valid numeric vector.',
        ),
      );
    }

    try {
      final rules = await _localDataSource.searchRelevantTaxRules(vector);
      return Right<Failure, List<TaxRuleEntity>>(rules);
    } on DatabaseException catch (error) {
      return Left<Failure, List<TaxRuleEntity>>(
        DatabaseFailure(
          message: 'Tax rules could not be searched in SQLite.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, List<TaxRuleEntity>>(
        ParsingFailure(
          message: 'A stored tax rule has invalid data.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<TaxRuleEntity>>(
        CacheFailure(
          message: 'The local tax corpus could not be searched.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TaxQueryEntity>> askTaxCopilot(
    String question,
    String companyId,
  ) async {
    final String normalizedQuestion = question.trim();
    final String normalizedCompanyId = companyId.trim();
    if (normalizedQuestion.isEmpty) {
      return Left<Failure, TaxQueryEntity>(
        const ValidationFailure(message: 'Ask a tax or legal question.'),
      );
    }
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, TaxQueryEntity>(
        const ValidationFailure(message: 'Select a company before asking.'),
      );
    }

    try {
      final List<double> queryEmbedding =
          await _llmDataSource.createEmbedding(normalizedQuestion);
      final Either<Failure, List<TaxRuleEntity>> searchResult =
          await searchRelevantTaxRules(encodeVector(queryEmbedding));
      final List<TaxRuleEntity> retrievedRules = searchResult.fold(
        (Failure failure) => throw failure,
        (List<TaxRuleEntity> rules) => rules,
      );
      final LlmAnswer generatedAnswer = await _llmDataSource.answerQuestion(
        question: normalizedQuestion,
        retrievedRules: retrievedRules,
      );
      final List<String> citations = generatedAnswer.citedArticles.isEmpty
          ? retrievedRules
              .map((TaxRuleEntity rule) => rule.articleCode)
              .toList(growable: false)
          : generatedAnswer.citedArticles;
      final TaxQueryModel query = TaxQueryModel(
        id: _newQueryId(),
        companyId: normalizedCompanyId,
        question: normalizedQuestion,
        answer: generatedAnswer.answer,
        citedArticles: citations,
        timestamp: DateTime.now().toUtc(),
      );
      await _localDataSource.saveQuery(query);
      return Right<Failure, TaxQueryEntity>(query);
    } on Failure catch (failure) {
      return Left<Failure, TaxQueryEntity>(failure);
    } on DatabaseException catch (error) {
      return Left<Failure, TaxQueryEntity>(
        DatabaseFailure(
          message: 'The tax copilot result could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, TaxQueryEntity>(
        ParsingFailure(
          message: 'The tax copilot returned an invalid response.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, TaxQueryEntity>(
        ServerFailure(
          message: 'The tax copilot could not complete the request.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TaxQueryEntity>>> getQueryHistory(
    String companyId,
  ) async {
    if (companyId.trim().isEmpty) {
      return Left<Failure, List<TaxQueryEntity>>(
        const ValidationFailure(message: 'Select a company first.'),
      );
    }

    try {
      final List<TaxQueryModel> history =
          await _localDataSource.getQueryHistory(companyId);
      return Right<Failure, List<TaxQueryEntity>>(history);
    } on DatabaseException catch (error) {
      return Left<Failure, List<TaxQueryEntity>>(
        DatabaseFailure(
          message: 'Tax copilot history could not be loaded.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, List<TaxQueryEntity>>(
        ParsingFailure(
          message: 'Tax copilot history contains invalid data.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<TaxQueryEntity>>(
        CacheFailure(
          message: 'Tax copilot history could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> clearQueryHistory(String companyId) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, void>(
        const ValidationFailure(message: 'Select a company first.'),
      );
    }

    try {
      await _localDataSource.clearQueryHistory(normalizedCompanyId);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'Tax copilot history could not be cleared.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'Tax copilot history could not be cleared locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TaxRuleEntity?>> getTaxRuleByArticleCode(
    String articleCode,
  ) async {
    final String normalizedArticleCode = _normalizeArticleCode(articleCode);
    if (normalizedArticleCode.isEmpty) {
      return Left<Failure, TaxRuleEntity?>(
        const ValidationFailure(message: 'An article number is required.'),
      );
    }

    try {
      final TaxRuleModel? rule =
          await _localDataSource.getTaxRuleByArticleCode(
        normalizedArticleCode,
      );
      return Right<Failure, TaxRuleEntity?>(rule);
    } on DatabaseException catch (error) {
      return Left<Failure, TaxRuleEntity?>(
        DatabaseFailure(
          message: 'The cited tax article could not be loaded.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      return Left<Failure, TaxRuleEntity?>(
        ParsingFailure(
          message: 'The cited tax article contains invalid data.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, TaxRuleEntity?>(
        CacheFailure(
          message: 'The cited tax article could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  static String _normalizeArticleCode(String value) {
    final String normalized = value.trim();
    if (normalized.toLowerCase().startsWith('article ')) {
      return normalized.substring('article '.length).trim();
    }
    return normalized;
  }

  String _newQueryId() {
    return 'tax-query-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}
