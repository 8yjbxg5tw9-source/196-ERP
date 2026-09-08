import '../entities/bank_transaction_entity.dart';
import 'reconciliation_rule_entity.dart';

/// Evaluates active custom rules sequentially (by ascending priority) against
/// an incoming bank transaction, returning the first rule whose conditions all
/// match. It runs before the default fuzzy matching engine so accountants can
/// override routine categorization with explicit business rules.
class RuleMatchingEvaluator {
  const RuleMatchingEvaluator();

  /// Returns the highest-priority active rule matching [transaction], or null.
  ReconciliationRuleEntity? evaluate(
    BankTransactionEntity transaction,
    List<ReconciliationRuleEntity> rules,
  ) {
    final List<ReconciliationRuleEntity> active = rules
        .where((ReconciliationRuleEntity rule) => rule.isActive)
        .toList(growable: false)
      ..sort(
        (ReconciliationRuleEntity left, ReconciliationRuleEntity right) =>
            left.priority.compareTo(right.priority),
      );

    for (final ReconciliationRuleEntity rule in active) {
      if (_matchesAll(transaction, rule.conditions)) {
        return rule;
      }
    }
    return null;
  }

  bool _matchesAll(
    BankTransactionEntity transaction,
    List<RuleCondition> conditions,
  ) {
    for (final RuleCondition condition in conditions) {
      if (!_matches(transaction, condition)) {
        return false;
      }
    }
    return true;
  }

  bool _matches(BankTransactionEntity transaction, RuleCondition condition) {
    if (condition.field == RuleField.amount) {
      final double? threshold = double.tryParse(condition.value.trim());
      if (threshold == null) {
        return false;
      }
      switch (condition.operator) {
        case RuleOperator.greaterThan:
          return transaction.amount > threshold;
        case RuleOperator.lessThan:
          return transaction.amount < threshold;
        case RuleOperator.equals:
          return transaction.amount == threshold;
        case RuleOperator.contains:
        case RuleOperator.startsWith:
        case RuleOperator.endsWith:
          return false;
      }
    }

    final String value = _fieldText(transaction, condition.field).toLowerCase();
    final String expected = condition.value.trim().toLowerCase();
    switch (condition.operator) {
      case RuleOperator.contains:
        return value.contains(expected);
      case RuleOperator.equals:
        return value == expected;
      case RuleOperator.startsWith:
        return value.startsWith(expected);
      case RuleOperator.endsWith:
        return value.endsWith(expected);
      case RuleOperator.greaterThan:
      case RuleOperator.lessThan:
        return false;
    }
  }

  static String _fieldText(
    BankTransactionEntity transaction,
    RuleField field,
  ) {
    switch (field) {
      case RuleField.description:
        return transaction.description;
      case RuleField.counterpartyName:
        return transaction.counterpartyName ?? '';
      case RuleField.counterpartyVoen:
        return transaction.counterpartyVoen ?? '';
      case RuleField.referenceCode:
        return transaction.referenceCode ?? '';
      case RuleField.amount:
        return transaction.amount.toString();
    }
  }
}
