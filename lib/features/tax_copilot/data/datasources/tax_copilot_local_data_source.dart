import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../../../core/utils/vector_math.dart';
import '../../domain/entities/tax_rule_entity.dart';
import '../models/tax_query_model.dart';
import '../models/tax_rule_model.dart';

/// Local SQLite contract for retrieval results and copilot history.
abstract interface class TaxCopilotLocalDataSource {
  Future<List<TaxRuleModel>> searchRelevantTaxRules(
    List<double> queryVector, {
    int limit = 8,
  });

  Future<void> saveQuery(TaxQueryModel query);

  Future<List<TaxQueryModel>> getQueryHistory(String companyId);

  Future<void> clearQueryHistory(String companyId);

  Future<TaxRuleModel?> getTaxRuleByArticleCode(String articleCode);
}

class TaxCopilotLocalDataSourceImpl implements TaxCopilotLocalDataSource {
  TaxCopilotLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<TaxRuleModel>> searchRelevantTaxRules(
    List<double> queryVector, {
    int limit = 8,
  }) async {
    if (limit <= 0) {
      return const <TaxRuleModel>[];
    }

    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.taxRules,
    );
    final List<TaxRuleModel> rules =
        rows.map(TaxRuleModel.fromSqflite).toList(growable: false);
    final List<_ScoredTaxRule> scoredRules = rules
        .where(
          (TaxRuleModel rule) =>
              rule.embedding != null &&
              rule.embedding!.length == queryVector.length,
        )
        .map(
          (TaxRuleModel rule) => _ScoredTaxRule(
            rule: rule,
            score: cosineSimilarity(queryVector, rule.embedding!),
          ),
        )
        .toList(growable: false);

    final List<_ScoredTaxRule> ranked = List<_ScoredTaxRule>.of(scoredRules)
      ..sort((_ScoredTaxRule left, _ScoredTaxRule right) {
        final int scoreOrder = right.score.compareTo(left.score);
        if (scoreOrder != 0) {
          return scoreOrder;
        }
        return left.rule.articleCode.compareTo(right.rule.articleCode);
      });

    return ranked
        .take(limit)
        .map((_ScoredTaxRule scored) => scored.rule)
        .toList(growable: false);
  }

  @override
  Future<void> saveQuery(TaxQueryModel query) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.taxQueries,
      query.toSqflite(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<TaxQueryModel>> getQueryHistory(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.taxQueries,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'timestamp DESC',
      limit: 100,
    );
    return rows.map(TaxQueryModel.fromSqflite).toList(growable: false);
  }

  @override
  Future<TaxRuleModel?> getTaxRuleByArticleCode(String articleCode) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.taxRules,
      where: 'article_code = ?',
      whereArgs: <Object?>[articleCode],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TaxRuleModel.fromSqflite(rows.first);
  }

  @override
  Future<void> clearQueryHistory(String companyId) async {
    final Database database = await _databaseService.database;
    await database.delete(
      DatabaseTables.taxQueries,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
    );
  }

  /// Used by corpus importers to persist precomputed embeddings.
  Future<void> upsertTaxRules(Iterable<TaxRuleEntity> rules) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      for (final TaxRuleEntity rule in rules) {
        await transaction.insert(
          DatabaseTables.taxRules,
          TaxRuleModel.fromEntity(rule).toSqflite(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

class _ScoredTaxRule {
  const _ScoredTaxRule({required this.rule, required this.score});

  final TaxRuleModel rule;
  final double score;
}
