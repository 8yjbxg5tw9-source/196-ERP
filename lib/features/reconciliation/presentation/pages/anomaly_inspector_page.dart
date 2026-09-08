import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../../shared/navigation/app_shell_controller.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../../document_ocr/presentation/pages/document_verification_page.dart';
import '../../domain/entities/anomaly_alert_entity.dart';
import '../bloc/anomaly_bloc.dart';

/// Fraud & anomaly inspector: a warning dashboard listing flagged transactions
/// with severity badges and one-click Dismiss / Investigate actions.
class AnomalyInspectorPage extends StatelessWidget {
  const AnomalyInspectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<AnomalyBloc>(
          create: (_) => sl<AnomalyBloc>(),
          child: _AnomalyInspectorView(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _AnomalyInspectorView extends StatelessWidget {
  const _AnomalyInspectorView({required this.companyId});

  final String? companyId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud & Anomaly Inspector'),
        actions: <Widget>[
          FilledButton.icon(
            onPressed: () => _runScan(context),
            icon: const Icon(Icons.radar_rounded, size: 17),
            label: const Text('Run Scan'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<AnomalyBloc, AnomalyState>(
        listener: (BuildContext context, AnomalyState state) {
          if (state is AnomalyError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, AnomalyState state) {
          if (state is AnomalyScanning) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnomalyError) {
            return Center(
              child: Text(
                state.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final List<AnomalyAlertEntity> alerts =
              state is AnomalyScanComplete
                  ? state.visibleAlerts
                  : const <AnomalyAlertEntity>[];
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.verified_outlined,
                    size: 48,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state is AnomalyScanComplete
                        ? 'No anomalies detected.'
                        : 'Run a scan to inspect bank activity.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              return _AlertCard(
                alert: alerts[index],
                onDismiss: () => context
                    .read<AnomalyBloc>()
                    .add(DismissAlertEvent(alerts[index].id)),
                onInvestigate: () => _investigate(context, alerts[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _runScan(BuildContext context) {
    final String companyId = this.companyId ?? '';
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an active company first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.read<AnomalyBloc>().add(RunAnomalyScanEvent(companyId));
  }

  void _investigate(BuildContext context, AnomalyAlertEntity alert) {
    final String? documentId = alert.documentId;
    if (documentId != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DocumentVerificationPage(documentId: documentId),
        ),
      );
      return;
    }
    sl<AppShellController>().select(AppSection.reconciliation);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onDismiss,
    required this.onInvestigate,
  });

  final AnomalyAlertEntity alert;
  final VoidCallback onDismiss;
  final VoidCallback onInvestigate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool red = alert.severity == AnomalySeverity.red;
    final Color color = red ? AppColors.error : AppColors.warning;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _SeverityBadge(severity: alert.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (alert.amount != null)
                  Text(
                    AppFormatters.currency(alert.amount!, symbol: '₼'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${alert.kind.label} · ${alert.description}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onInvestigate,
                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                  label: const Text('Investigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final AnomalySeverity severity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool red = severity == AnomalySeverity.red;
    final Color color = red ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            severity.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
