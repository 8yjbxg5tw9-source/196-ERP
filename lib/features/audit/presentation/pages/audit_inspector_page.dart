import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/permission_guard.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/audit_log_entity.dart';
import '../../domain/entities/integrity_check_result.dart';
import '../bloc/audit_bloc.dart';
import '../bloc/audit_event.dart';
import '../bloc/audit_state.dart';
import '../widgets/action_badge.dart';
import '../widgets/audit_diff_viewer.dart';

/// Immutable audit-trail inspector with live filters and a JSON diff viewer.
class AuditInspectorPage extends StatelessWidget {
  const AuditInspectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<AuditBloc>(
          create: (_) => sl<AuditBloc>(),
          child: _AuditInspectorView(company: activeCompany),
        );
      },
    );
  }
}

class _AuditInspectorView extends StatefulWidget {
  const _AuditInspectorView({required this.company});

  final CompanyEntity? company;

  @override
  State<_AuditInspectorView> createState() => _AuditInspectorViewState();
}

class _AuditInspectorViewState extends State<_AuditInspectorView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  AuditAction? _action;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AuditInspectorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.company?.id != widget.company?.id) {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    final CompanyEntity? company = widget.company;
    if (company == null) {
      return;
    }
    context.read<AuditBloc>().add(
          FetchAuditLogsEvent(
            companyId: company.id,
            range: _range,
            actionFilter: _action,
            userId: _userId,
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = context.watch<AuthBloc>().state;
    final UserEntity? currentUser = _currentUserOf(authState);
    final bool canView = currentUser != null &&
        PermissionGuard.canExecute(currentUser.role, AppPermission.viewAuditLogs);

    if (!canView) {
      return const _InspectorMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Access restricted',
        message: 'Your role does not include audit-log access.',
      );
    }
    if (widget.company == null) {
      return const _InspectorMessage(
        icon: Icons.business_outlined,
        title: 'Select an active company',
        message: 'Audit records are scoped to the active company.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Inspector'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: () => context.read<AuditBloc>().add(
                  RunIntegrityVerificationEvent(companyId: widget.company!.id),
                ),
            icon: const Icon(Icons.verified_user_outlined, size: 17),
            label: const Text('Verify Integrity'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Export audit log (PDF)',
            onPressed: () => context
                .read<AuditBloc>()
                .add(const ExportAuditLogsPdfEvent()),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildFilterBar(context),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<UserEntity> users = switch (context.watch<AuthBloc>().state) {
      AuthAuthenticated(:final users) => users,
      _ => const <UserEntity>[],
    };

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search user, entity, action…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
              ),
            ),
          ),
          DropdownButton<AuditAction?>(
            value: _action,
            hint: const Text('All actions'),
            items: <DropdownMenuItem<AuditAction?>>[
              const DropdownMenuItem<AuditAction?>(
                value: null,
                child: Text('All actions'),
              ),
              for (final AuditAction action in AuditAction.values)
                DropdownMenuItem<AuditAction?>(
                  value: action,
                  child: Text(action.label),
                ),
            ],
            onChanged: (AuditAction? value) {
              setState(() => _action = value);
              _load();
            },
          ),
          DropdownButton<String?>(
            value: _userId,
            hint: const Text('All users'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All users'),
              ),
              for (final UserEntity user in users)
                DropdownMenuItem<String?>(
                  value: user.id,
                  child: Text(
                    user.fullName.isEmpty ? user.username : user.fullName,
                  ),
                ),
            ],
            onChanged: (String? value) {
              setState(() => _userId = value);
              _load();
            },
          ),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              '${AppFormatters.date(_range.start)} – '
              '${AppFormatters.date(_range.end)}',
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return BlocConsumer<AuditBloc, AuditState>(
      listenWhen: (AuditState previous, AuditState current) =>
          (current is AuditLoaded && current.message != null) ||
          current is AuditError ||
          current is IntegrityCheckComplete,
      listener: (BuildContext context, AuditState state) {
        if (state is IntegrityCheckComplete) {
          _showIntegrityResult(context, state.result);
          return;
        }
        final String? message = switch (state) {
          AuditLoaded(:final message) => message,
          AuditError(:final message) => message,
          _ => null,
        };
        if (message == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      },
      builder: (BuildContext context, AuditState state) {
        if (state is AuditLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AuditError) {
          return _InspectorMessage(
            icon: Icons.error_outline_rounded,
            title: 'Audit trail could not be loaded',
            message: state.message,
          );
        }
        if (state is AuditLoaded) {
          if (state.logs.isEmpty) {
            return const _InspectorMessage(
              icon: Icons.visibility_off_outlined,
              title: 'No audit records found',
              message: 'Adjust the filters or perform an audited action first.',
            );
          }
          return _AuditGrid(logs: state.logs, onOpen: _showDiff);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _showIntegrityResult(
    BuildContext context,
    IntegrityCheckResult result,
  ) {
    final ThemeData theme = Theme.of(context);
    final Color accent =
        result.isValid ? AppColors.success : AppColors.error;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(
                result.isValid
                    ? Icons.verified_user_rounded
                    : Icons.gpp_bad_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.isValid
                      ? 'All Systems Secured & Verified'
                      : 'Database Tampering Detected',
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 12),
                _IntegrityStat(
                  label: 'Total records',
                  value: '${result.totalRecords}',
                ),
                _IntegrityStat(
                  label: 'Hash-chained records',
                  value: '${result.hashedRecords}',
                ),
                _IntegrityStat(
                  label: 'Legacy (pre-chain) records',
                  value: '${result.legacyRecords}',
                ),
                if (!result.isValid) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Tampered row${result.tamperedIndexes.length == 1 ? '' : 's'}: '
                    '${result.tamperedIndexes.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {});
        _load();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    _load();
  }

  void _showDiff(AuditLogEntity log) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('${log.action.label} · ${log.entityName}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${log.userName} (${log.userRole}) · '
                    '${AppFormatters.dateTime(log.timestamp.toLocal())}',
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _HashChainInfo(log: log),
                  const SizedBox(height: 12),
                  AuditDiffViewer(log: log),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static UserEntity? _currentUserOf(AuthState state) {
    return switch (state) {
      AuthAuthenticated(:final currentUser) => currentUser,
      AuthFailure(:final currentUser) => currentUser,
      _ => null,
    };
  }
}

class _AuditGrid extends StatelessWidget {
  const _AuditGrid({required this.logs, required this.onOpen});

  final List<AuditLogEntity> logs;
  final ValueChanged<AuditLogEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        _GridHeader(theme: theme),
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withAlpha(40),
            ),
            itemBuilder: (BuildContext context, int index) {
              final AuditLogEntity log = logs[index];
              return _AuditRow(
                log: log,
                onOpen: () => onOpen(log),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text('Timestamp', style: style)),
          Expanded(flex: 2, child: Text('User', style: style)),
          Expanded(flex: 2, child: Text('Action', style: style)),
          Expanded(flex: 2, child: Text('Entity', style: style)),
          Expanded(flex: 4, child: Text('Details', style: style)),
          SizedBox(
            width: 96,
            child: Text('Chain', style: style),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log, required this.onOpen});

  final AuditLogEntity log;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onDoubleTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                AppFormatters.dateTime(log.timestamp.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.userName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(flex: 2, child: ActionBadge(action: log.action)),
            Expanded(
              flex: 2,
              child: Text(
                log.entityId == null
                    ? log.entityName
                    : '${log.entityName}\n${log.entityId}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                _detailSummary(log),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: 96, child: _ChainBadge(log: log)),
          ],
        ),
      ),
    );
  }

  static String _detailSummary(AuditLogEntity log) {
    final Map<String, ({Object? before, Object? after})> changes =
        log.changedFields();
    if (changes.isEmpty) {
      return 'No field changes';
    }
    return changes.entries
        .take(3)
        .map((MapEntry<String, ({Object? before, Object? after})> entry) {
          return '${entry.key}: ${entry.value.before ?? '∅'} → '
              '${entry.value.after ?? '∅'}';
        })
        .join(' · ');
  }
}

/// Green shield for a chained record; muted label for legacy rows written
/// before hash chaining was introduced.
class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.log});

  final AuditLogEntity log;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!log.isChained) {
      return Text(
        'Legacy',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.shield_rounded, size: 15, color: AppColors.success),
        const SizedBox(width: 4),
        Text(
          'Secured',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Compact hash metadata shown inside the field-delta dialog.
class _HashChainInfo extends StatelessWidget {
  const _HashChainInfo({required this.log});

  final AuditLogEntity log;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String previous = log.previousHash?.trim() ?? '';
    final String current = log.currentHash?.trim() ?? '';
    final String device = log.systemDeviceInfo?.trim() ?? '';
    if (current.isEmpty) {
      return Text(
        'Legacy record — no hash chain (predates cryptographic auditing).',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HashLine(label: 'Previous hash', value: previous),
        _HashLine(label: 'Current hash', value: current),
        if (device.isNotEmpty) _HashLine(label: 'Device', value: device),
      ],
    );
  }
}

class _HashLine extends StatelessWidget {
  const _HashLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String compact = value.length > 26
        ? '${value.substring(0, 26)}…${value.substring(value.length - 6)}'
        : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              compact,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrityStat extends StatelessWidget {
  const _IntegrityStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorMessage extends StatelessWidget {
  const _InspectorMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
