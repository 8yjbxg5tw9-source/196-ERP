import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/entities/audit_log_entity.dart';

/// Side-by-side before/after JSON diff for a single audit record.
///
/// Changed fields are highlighted red (old value) and green (new value);
/// unchanged fields are rendered muted below the changed set.
class AuditDiffViewer extends StatelessWidget {
  const AuditDiffViewer({required this.log, super.key});

  final AuditLogEntity log;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, ({Object? before, Object? after})> changes =
        log.changedFields();
    final Set<String> changedKeys = changes.keys.toSet();
    final Set<String> keys = <String>{
      ...?log.beforeState?.keys,
      ...?log.afterState?.keys,
    };

    final List<String> orderedKeys = <String>[
      ...keys.where(changedKeys.contains),
      ...keys.where((String key) => !changedKeys.contains(key)),
    ];

    if (orderedKeys.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No structured before/after state was captured for this action.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DiffHeader(
          field: 'Field',
          before: 'Before',
          after: 'After',
          emphasized: true,
        ),
        for (final String key in orderedKeys)
          _DiffRow(
            key: ValueKey<String>(key),
            field: key,
            before: log.beforeState?[key],
            after: log.afterState?[key],
            changed: changedKeys.contains(key),
          ),
      ],
    );
  }

  static String formatValue(Object? value) {
    if (value == null) {
      return '—';
    }
    if (value is Map || value is List) {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    }
    return value.toString();
  }
}

class _DiffHeader extends StatelessWidget {
  const _DiffHeader({
    required this.field,
    required this.before,
    required this.after,
    required this.emphasized,
  });

  final String field;
  final String before;
  final String after;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text(field, style: style)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Text(before, style: style)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Text(after, style: style)),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.field,
    required this.before,
    required this.after,
    required this.changed,
    super.key,
  });

  final String field;
  final Object? before;
  final Object? after;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
    );
    final Color beforeColor = changed
        ? const Color(0xFFE11D48).withAlpha(20)
        : Colors.transparent;
    final Color afterColor = changed
        ? const Color(0xFF059669).withAlpha(20)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              field,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: beforeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AuditDiffViewer.formatValue(before),
                style: mono?.copyWith(
                  color: changed
                      ? const Color(0xFFE11D48)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: afterColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AuditDiffViewer.formatValue(after),
                style: mono?.copyWith(
                  color: changed
                      ? const Color(0xFF059669)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
