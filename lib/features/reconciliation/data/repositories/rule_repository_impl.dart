import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/rules/reconciliation_rule_entity.dart';
import '../../domain/rules/rule_repository.dart';
import '../datasources/rules_local_data_source.dart';
import '../models/reconciliation_rule_model.dart';

/// SQLite-backed store for custom reconciliation rules.
class RuleRepositoryImpl implements RuleRepository {
  RuleRepositoryImpl(this._localDataSource);

  final RulesLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, List<ReconciliationRuleEntity>>> getRules(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<ReconciliationRuleEntity>>(
        const ValidationFailure(message: 'Select a company before loading rules.'),
      );
    }
    try {
      final List<ReconciliationRuleModel> rules =
          await _localDataSource.getRules(normalizedCompanyId);
      return Right<Failure, List<ReconciliationRuleEntity>>(rules);
    } on DatabaseException catch (error) {
      return Left<Failure, List<ReconciliationRuleEntity>>(
        DatabaseFailure(
          message: 'Reconciliation rules could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<ReconciliationRuleEntity>>(
        CacheFailure(
          message: 'Reconciliation rules could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ReconciliationRuleEntity>> createRule(
    ReconciliationRuleEntity rule,
  ) async {
    if (rule.ruleName.trim().isEmpty) {
      return Left<Failure, ReconciliationRuleEntity>(
        const ValidationFailure(message: 'Rule name is required.'),
      );
    }
    if (rule.conditions.isEmpty) {
      return Left<Failure, ReconciliationRuleEntity>(
        const ValidationFailure(message: 'Add at least one condition.'),
      );
    }
    try {
      final ReconciliationRuleModel model = ReconciliationRuleModel(
        id: rule.id.isEmpty
            ? 'rule-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : rule.id,
        companyId: rule.companyId,
        ruleName: rule.ruleName.trim(),
        priority: rule.priority,
        conditions: rule.conditions,
        action: rule.action,
        isActive: rule.isActive,
        createdAt: rule.createdAt ?? DateTime.now().toUtc(),
      );
      final ReconciliationRuleModel saved =
          await _localDataSource.createRule(model);
      return Right<Failure, ReconciliationRuleEntity>(saved);
    } on DatabaseException catch (error) {
      return Left<Failure, ReconciliationRuleEntity>(
        DatabaseFailure(
          message: 'The reconciliation rule could not be created.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, ReconciliationRuleEntity>(
        CacheFailure(
          message: 'The reconciliation rule could not be saved.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ReconciliationRuleEntity>> toggleRuleStatus(
    String ruleId,
    bool isActive,
  ) async {
    final String normalizedId = ruleId.trim();
    if (normalizedId.isEmpty) {
      return Left<Failure, ReconciliationRuleEntity>(
        const ValidationFailure(message: 'A rule is required to update.'),
      );
    }
    try {
      final ReconciliationRuleModel? target =
          await _localDataSource.getRuleById(normalizedId);
      if (target == null) {
        return Left<Failure, ReconciliationRuleEntity>(
          NotFoundFailure(message: 'Rule $normalizedId was not found.'),
        );
      }
      final ReconciliationRuleModel updated = ReconciliationRuleModel(
        id: target.id,
        companyId: target.companyId,
        ruleName: target.ruleName,
        priority: target.priority,
        conditions: target.conditions,
        action: target.action,
        isActive: isActive,
        createdAt: target.createdAt,
      );
      await _localDataSource.updateRule(updated);
      return Right<Failure, ReconciliationRuleEntity>(updated);
    } on DatabaseException catch (error) {
      return Left<Failure, ReconciliationRuleEntity>(
        DatabaseFailure(
          message: 'The rule status could not be updated.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, ReconciliationRuleEntity>(
        CacheFailure(
          message: 'The rule status could not be updated locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> reorderRules(
    List<String> orderedRuleIds,
  ) async {
    if (orderedRuleIds.isEmpty) {
      return const Right<Failure, void>(null);
    }
    try {
      await _localDataSource.setRulePriorities(orderedRuleIds);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'Rule priorities could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'Rule priorities could not be saved locally.',
          cause: error,
        ),
      );
    }
  }
}
