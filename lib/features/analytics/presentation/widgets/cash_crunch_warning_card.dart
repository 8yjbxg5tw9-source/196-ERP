import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';

/// AI predictive liquidity alert: highlights an expected cash shortfall with
/// mitigation advice, or confirms a healthy 30-day runway.
class CashCrunchWarningCard extends StatelessWidget {
  const CashCrunchWarningCard({required this.prediction, super.key});

  final CashCrunchPrediction? prediction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CashCrunchPrediction? risk = prediction;
    if (risk == null || !risk.atRisk) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 20,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Liquidity healthy',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No cash crunch is projected within the next 30 days.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(16),
        border: Border.all(color: AppColors.warning.withAlpha(140)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Cash Crunch Prediction',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  risk.advice,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Projected 30-day low: '
                      '${AppFormatters.decimal(risk.projectedLowestCash)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
