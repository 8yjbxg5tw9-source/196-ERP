import 'package:equatable/equatable.dart';

/// The transaction field a [RuleCondition] inspects.
enum RuleField {
  description,
  counterpartyName,
  counterpartyVoen,
  referenceCode,
  amount,
}

extension RuleFieldLabel on RuleField {
  String get label => switch (this) {
        RuleField.description => 'Description',
        RuleField.counterpartyName => 'Counterparty',
        RuleField.counterpartyVoen => 'VÖEN',
        RuleField.referenceCode => 'Reference',
        RuleField.amount => 'Amount',
      };
}

/// The comparison operator a [RuleCondition] applies to its field.
enum RuleOperator {
  contains,
  equals,
  startsWith,
  endsWith,
  greaterThan,
  lessThan,
}

extension RuleOperatorLabel on RuleOperator {
  String get label => switch (this) {
        RuleOperator.contains => 'contains',
        RuleOperator.equals => 'equals',
        RuleOperator.startsWith => 'starts with',
        RuleOperator.endsWith => 'ends with',
        RuleOperator.greaterThan => 'greater than',
        RuleOperator.lessThan => 'less than',
      };
}

/// A single "IF field OP value" predicate of a reconciliation rule.
class RuleCondition extends Equatable {
  const RuleCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  final RuleField field;
  final RuleOperator operator;
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'field': field.name,
        'operator': operator.name,
        'value': value,
      };

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      field: RuleField.values.firstWhere(
        (RuleField field) => field.name == json['field'],
        orElse: () => RuleField.description,
      ),
      operator: RuleOperator.values.firstWhere(
        (RuleOperator operator) => operator.name == json['operator'],
        orElse: () => RuleOperator.contains,
      ),
      value: (json['value'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => <Object?>[field, operator, value];
}

/// The effect of a matched rule.
enum RuleActionType { categorize, assignAccount, autoApprove }

extension RuleActionTypeLabel on RuleActionType {
  String get label => switch (this) {
        RuleActionType.categorize => 'Categorize',
        RuleActionType.assignAccount => 'Assign account',
        RuleActionType.autoApprove => 'Auto-approve',
      };
}

/// The consequence applied when every [RuleCondition] matches.
class RuleAction extends Equatable {
  const RuleAction({
    required this.type,
    this.value = '',
  });

  final RuleActionType type;

  /// Category name (for `categorize`) or account code (for `assignAccount`).
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'value': value,
      };

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      type: RuleActionType.values.firstWhere(
        (RuleActionType type) => type.name == json['type'],
        orElse: () => RuleActionType.categorize,
      ),
      value: (json['value'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => <Object?>[type, value];
}

/// A custom reconciliation rule evaluated before the default fuzzy matcher.
class ReconciliationRuleEntity extends Equatable {
  const ReconciliationRuleEntity({
    required this.id,
    required this.companyId,
    required this.ruleName,
    required this.priority,
    required this.conditions,
    required this.action,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String ruleName;
  final int priority;
  final List<RuleCondition> conditions;
  final RuleAction action;
  final bool isActive;
  final DateTime? createdAt;

  ReconciliationRuleEntity copyWith({
    String? id,
    String? companyId,
    String? ruleName,
    int? priority,
    List<RuleCondition>? conditions,
    RuleAction? action,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ReconciliationRuleEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      ruleName: ruleName ?? this.ruleName,
      priority: priority ?? this.priority,
      conditions: conditions ?? this.conditions,
      action: action ?? this.action,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        ruleName,
        priority,
        conditions,
        action,
        isActive,
        createdAt,
      ];
}
