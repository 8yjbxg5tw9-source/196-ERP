import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/rules/reconciliation_rule_entity.dart';
import '../bloc/rules_bloc.dart';

/// Visual "IF [conditions] THEN [action]" editor for custom reconciliation
/// rules, with drag-and-drop priority reordering and one-tap activation.
class RulesBuilderPage extends StatelessWidget {
  const RulesBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<RulesBloc>(
          create: (_) => sl<RulesBloc>(),
          child: _RulesBuilderView(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _RulesBuilderView extends StatefulWidget {
  const _RulesBuilderView({required this.companyId});

  final String? companyId;

  @override
  State<_RulesBuilderView> createState() => _RulesBuilderViewState();
}

class _RulesBuilderViewState extends State<_RulesBuilderView> {
  @override
  void initState() {
    super.initState();
    final String companyId = widget.companyId ?? '';
    if (companyId.isNotEmpty) {
      context.read<RulesBloc>().add(LoadRulesEvent(companyId));
    }
  }

  Future<void> _createRule() async {
    final String companyId = widget.companyId ?? '';
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an active company first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final int nextPriority = context.read<RulesBloc>().state is RulesLoaded
        ? (context.read<RulesBloc>().state as RulesLoaded).rules.length
        : 0;
    final ReconciliationRuleEntity? rule = await showDialog<ReconciliationRuleEntity>(
      context: context,
      builder: (BuildContext _) => _RuleEditorDialog(companyId: companyId),
    );
    if (rule == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<RulesBloc>().add(
          CreateRuleEvent(rule.copyWith(priority: nextPriority)),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconciliation Rules'),
        actions: <Widget>[
          FilledButton.icon(
            onPressed: _createRule,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('New Rule'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<RulesBloc, RulesState>(
        listener: (BuildContext context, RulesState state) {
          if (state is RulesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, RulesState state) {
          if (widget.companyId == null || widget.companyId!.isEmpty) {
            return const _EmptyRules(message: 'Select an active company.');
          }
          if (state is RulesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is RulesError) {
            return _EmptyRules(message: state.message);
          }
          final List<ReconciliationRuleEntity> rules =
              state is RulesLoaded
                  ? state.rules
                  : const <ReconciliationRuleEntity>[];
          if (rules.isEmpty) {
            return const _EmptyRules(
              message: 'No rules yet. Create one to override routine matching.',
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            onReorder: (int oldIndex, int newIndex) {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final List<String> ids =
                  rules.map((ReconciliationRuleEntity r) => r.id).toList(
                        growable: false,
                      );
              final String moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              context.read<RulesBloc>().add(ReorderRulesEvent(ids));
            },
            itemBuilder: (BuildContext context, int index) {
              final ReconciliationRuleEntity rule = rules[index];
              return _RuleTile(
                key: ValueKey<String>(rule.id),
                rule: rule,
                index: index,
              );
            },
          );
        },
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.index,
    super.key,
  });

  final ReconciliationRuleEntity rule;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.drag_indicator_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          '${index + 1}. ${rule.ruleName}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _summarize(rule),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: rule.isActive,
          onChanged: (bool value) => context
              .read<RulesBloc>()
              .add(ToggleRuleStatusEvent(rule.id, value)),
        ),
      ),
    );
  }

  static String _summarize(ReconciliationRuleEntity rule) {
    final String conditions = rule.conditions
        .map(
          (RuleCondition c) =>
              '${c.field.label} ${c.operator.label} "${c.value}"',
        )
        .join(' AND ');
    final String action = switch (rule.action.type) {
      RuleActionType.categorize => 'Categorize as "${rule.action.value}"',
      RuleActionType.assignAccount =>
        'Assign account "${rule.action.value}"',
      RuleActionType.autoApprove => 'Auto-approve',
    };
    return 'IF $conditions THEN $action';
  }
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({required this.companyId});

  final String companyId;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final List<_ConditionDraft> _conditions = <_ConditionDraft>[
    _ConditionDraft(),
  ];
  RuleActionType _actionType = RuleActionType.categorize;
  final TextEditingController _actionValueController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _actionValueController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) {
      return false;
    }
    for (final _ConditionDraft condition in _conditions) {
      if (condition.valueController.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New reconciliation rule'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Rule name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Text(
                    'IF',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 8),
              for (int index = 0; index < _conditions.length; index++)
                _ConditionRow(
                  key: ValueKey<int>(index),
                  draft: _conditions[index],
                  onRemove: _conditions.length > 1
                      ? () => setState(() => _conditions.removeAt(index))
                      : null,
                  onChanged: () => setState(() {}),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _conditions.add(_ConditionDraft()),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add condition (AND)'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(
                    'THEN',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RuleActionType>(
                value: _actionType,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Action',
                ),
                items: <DropdownMenuItem<RuleActionType>>[
                  for (final RuleActionType type in RuleActionType.values)
                    DropdownMenuItem<RuleActionType>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (RuleActionType? value) {
                  if (value != null) {
                    setState(() => _actionType = value);
                  }
                },
              ),
              if (_actionType != RuleActionType.autoApprove) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _actionValueController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _actionType == RuleActionType.assignAccount
                        ? 'Account code'
                        : 'Category name',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () {
                  final List<RuleCondition> conditions = _conditions
                      .map(
                        (_ConditionDraft draft) => RuleCondition(
                          field: draft.field,
                          operator: draft.operator,
                          value: draft.valueController.text.trim(),
                        ),
                      )
                      .toList(growable: false);
                  Navigator.of(context).pop(
                    ReconciliationRuleEntity(
                      id: '',
                      companyId: widget.companyId,
                      ruleName: _nameController.text.trim(),
                      priority: 0,
                      conditions: conditions,
                      action: RuleAction(
                        type: _actionType,
                        value: _actionValueController.text.trim(),
                      ),
                    ),
                  );
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ConditionDraft {
  RuleField field = RuleField.description;
  RuleOperator operator = RuleOperator.contains;
  final TextEditingController valueController = TextEditingController();
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.draft,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final _ConditionDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<RuleField>(
              value: draft.field,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Field',
              ),
              items: <DropdownMenuItem<RuleField>>[
                for (final RuleField field in RuleField.values)
                  DropdownMenuItem<RuleField>(
                    value: field,
                    child: Text(field.label),
                  ),
              ],
              onChanged: (RuleField? value) {
                if (value != null) {
                  draft.field = value;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<RuleOperator>(
              value: draft.operator,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Operator',
              ),
              items: <DropdownMenuItem<RuleOperator>>[
                for (final RuleOperator operator in RuleOperator.values)
                  DropdownMenuItem<RuleOperator>(
                    value: operator,
                    child: Text(operator.label),
                  ),
              ],
              onChanged: (RuleOperator? value) {
                if (value != null) {
                  draft.operator = value;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: draft.valueController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Value',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove condition',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
