import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/bank_transaction_entity.dart';

/// Compact status badge that color-codes bank transaction match confidence:
/// green for >= 90%, amber for 60-89%, and red/neutral for unmatched rows.
class MatchConfidenceBadge extends StatelessWidget {
  const MatchConfidenceBadge({required this.transaction, super.key});

  final BankTransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return switch (transaction.status) {
      MatchStatus.reconciled => _badge(
        context,
        label: 'Reconciled',
        icon: Icons.verified_rounded,
        color: AppColors.success,
      ),
      MatchStatus.suggested => _suggestedBadge(context),
      MatchStatus.unmatched => _badge(
        context,
        label: 'Unmatched',
        icon: Icons.help_outline_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };
  }

  Widget _suggestedBadge(BuildContext context) {
    final double confidence = transaction.matchConfidence;
    final Color color = _confidenceColor(confidence);
    final int percent = (confidence * 100).round();
    return _badge(
      context,
      label: '$percent% Match',
      icon: confidence >= 0.9
          ? Icons.auto_awesome_rounded
          : Icons.check_circle_outline_rounded,
      color: color,
      tooltip: _reasonFor(confidence),
    );
  }

  static Color _confidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return AppColors.success;
    }
    if (confidence >= 0.6) {
      return AppColors.warning;
    }
    return AppColors.error;
  }

  static String? _reasonFor(double confidence) {
    if (confidence >= 0.999) {
      return 'Exact VÖEN & Amount';
    }
    if (confidence >= 0.85) {
      return 'Counterparty & Amount';
    }
    if (confidence >= 0.6) {
      return 'Reference & Amount';
    }
    return null;
  }

  Widget _badge(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    String? tooltip,
  }) {
    final ThemeData theme = Theme.of(context);
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        border: Border.all(color: color.withAlpha(140)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) {
      return chip;
    }
    return Tooltip(message: tooltip, child: chip);
  }
}
