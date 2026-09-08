import 'dart:convert';

import '../../domain/rules/reconciliation_rule_entity.dart';

/// SQLite mapping for the `reconciliation_rules` table.
class ReconciliationRuleModel extends ReconciliationRuleEntity {
  const ReconciliationRuleModel({
    required super.id,
    required super.companyId,
    required super.ruleName,
    required super.priority,
    required super.conditions,
    required super.action,
    super.isActive = true,
    super.createdAt,
  });

  factory ReconciliationRuleModel.fromMap(Map<String, Object?> map) {
    return ReconciliationRuleModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      ruleName: map['rule_name']?.toString() ?? '',
      priority: int.tryParse(map['priority']?.toString() ?? '') ?? 0,
      conditions: _decodeConditions(map['conditions_json']),
      action: RuleAction.fromJson(_decodeJson(map['action_type'],
          map['action_value'])),
      isActive: (map['is_active'] ?? 1) == 1 ||
          map['is_active']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'rule_name': ruleName,
      'priority': priority,
      'conditions_json': jsonEncode(
        conditions.map((RuleCondition c) => c.toJson()).toList(growable: false),
      ),
      'action_type': action.type.name,
      'action_value': action.value,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  static List<RuleCondition> _decodeConditions(Object? value) {
    try {
      final dynamic decoded = jsonDecode(value?.toString() ?? '[]');
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(RuleCondition.fromJson)
            .toList(growable: false);
      }
    } on FormatException {
      // Fall through to the empty default.
    }
    return const <RuleCondition>[];
  }

  static Map<String, dynamic> _decodeJson(
    Object? actionType,
    Object? actionValue,
  ) {
    return <String, dynamic>{
      'type': actionType?.toString() ?? 'categorize',
      'value': actionValue?.toString() ?? '',
    };
  }
}
