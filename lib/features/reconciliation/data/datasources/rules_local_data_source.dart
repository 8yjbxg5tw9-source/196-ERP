import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../models/reconciliation_rule_model.dart';

/// SQLite boundary for custom reconciliation rules.
abstract interface class RulesLocalDataSource {
  Future<List<ReconciliationRuleModel>> getRules(String companyId);

  Future<ReconciliationRuleModel?> getRuleById(String ruleId);

  Future<ReconciliationRuleModel> createRule(ReconciliationRuleModel rule);

  Future<void> updateRule(ReconciliationRuleModel rule);

  Future<void> setRulePriorities(List<String> orderedRuleIds);
}

class RulesLocalDataSourceImpl implements RulesLocalDataSource {
  RulesLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<ReconciliationRuleModel>> getRules(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.reconciliationRules,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'priority ASC, created_at ASC',
    );
    return rows.map(ReconciliationRuleModel.fromMap).toList(growable: false);
  }

  @override
  Future<ReconciliationRuleModel?> getRuleById(String ruleId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.reconciliationRules,
      where: 'id = ?',
      whereArgs: <Object?>[ruleId],
      limit: 1,
    );
    return rows.isEmpty ? null : ReconciliationRuleModel.fromMap(rows.first);
  }

  @override
  Future<ReconciliationRuleModel> createRule(
    ReconciliationRuleModel rule,
  ) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.reconciliationRules,
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return rule;
  }

  @override
  Future<void> updateRule(ReconciliationRuleModel rule) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.reconciliationRules,
      rule.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[rule.id],
    );
  }

  @override
  Future<void> setRulePriorities(List<String> orderedRuleIds) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      for (int index = 0; index < orderedRuleIds.length; index++) {
        await transaction.update(
          DatabaseTables.reconciliationRules,
          <String, Object?>{'priority': index},
          where: 'id = ?',
          whereArgs: <Object?>[orderedRuleIds[index]],
        );
      }
    });
  }
}
