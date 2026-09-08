import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import 'reconciliation_rule_entity.dart';

/// Persistence contract for custom reconciliation rules.
abstract interface class RuleRepository {
  Future<Either<Failure, List<ReconciliationRuleEntity>>> getRules(
    String companyId,
  );

  Future<Either<Failure, ReconciliationRuleEntity>> createRule(
    ReconciliationRuleEntity rule,
  );

  Future<Either<Failure, ReconciliationRuleEntity>> toggleRuleStatus(
    String ruleId,
    bool isActive,
  );

  Future<Either<Failure, void>> reorderRules(
    List<String> orderedRuleIds,
  );
}
