import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../company/presentation/bloc/company_bloc.dart';
import '../../../company/presentation/bloc/company_state.dart';
import '../../domain/entities/company_group_entity.dart';
import '../../domain/entities/consolidated_report_entity.dart';
import '../bloc/consolidation_bloc.dart';
import '../bloc/consolidation_event.dart';
import '../bloc/consolidation_state.dart';
import '../widgets/consolidation_stacked_bar_chart.dart';

/// Multi-company consolidation workspace: define groups, generate a
/// consolidated statement for a period, and inspect intercompany eliminations.
class ConsolidationPage extends StatelessWidget {
  const ConsolidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConsolidationBloc>(
      create: (_) => sl<ConsolidationBloc>(),
      child: const _ConsolidationWorkspace(),
    );
  }
}

class _ConsolidationWorkspace extends StatefulWidget {
  const _ConsolidationWorkspace();

  @override
  State<_ConsolidationWorkspace> createState() =>
      _ConsolidationWorkspaceState();
}

class _ConsolidationWorkspaceState extends State<_ConsolidationWorkspace> {
  DateTimeRange _range = _defaultRange();

  @override
  void initState() {
    super.initState();
    context.read<ConsolidationBloc>().add(const LoadGroupsEvent());
  }

  static DateTimeRange _defaultRange() {
    final DateTime now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> _pickRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _range = picked);
  }

  Future<void> _createGroup() async {
    final CompanyState companyState = context.read<CompanyBloc>().state;
    final List<CompanyEntity> companies = companyState is CompaniesLoaded
        ? companyState.companies
        : const <CompanyEntity>[];
    if (companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create at least two companies first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final _GroupDraft? draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (BuildContext _) => _CreateGroupDialog(companies: companies),
    );
    if (draft == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<ConsolidationBloc>().add(
          CreateGroupEvent(
            groupName: draft.name,
            parentCompanyId: draft.parentId,
            subsidiaryCompanyIds: draft.subsidiaryIds,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consolidation'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 17),
            label: Text(
              '${AppFormatters.date(_range.start)} – '
              '${AppFormatters.date(_range.end)}',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _generate(),
            icon: const Icon(Icons.insights_rounded, size: 17),
            label: const Text('Generate Report'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<ConsolidationBloc, ConsolidationState>(
        listener: (BuildContext context, ConsolidationState state) {
          if (state is ConsolidationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, ConsolidationState state) {
          if (state is ConsolidationLoadingGroups) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ConsolidationInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ConsolidationError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<ConsolidationBloc>()
                  .add(const LoadGroupsEvent()),
            );
          }

          final ConsolidationGroupsLoaded loaded =
              state as ConsolidationGroupsLoaded;
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildToolbar(context, loaded),
                const SizedBox(height: 16),
                Expanded(child: _buildBody(context, theme, loaded)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, ConsolidationGroupsLoaded state) {
    final ThemeData theme = Theme.of(context);
    final List<CompanyGroupEntity> groups = state.groups;
    final String? selectedGroupId = state.selectedGroupId ?? _firstGroupId(state);

    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButton<String>(
            value: selectedGroupId,
            isExpanded: true,
            hint: const Text('Select a company group'),
            items: <DropdownMenuItem<String>>[
              for (final CompanyGroupEntity group in groups)
                DropdownMenuItem<String>(
                  value: group.id,
                  child: Text(
                    group.groupName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                context.read<ConsolidationBloc>().add(
                      SelectGroupEvent(value),
                    );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _createGroup,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('New Group'),
        ),
      ],
    );
  }

  String? _firstGroupId(ConsolidationGroupsLoaded state) {
    return state.groups.isEmpty ? null : state.groups.first.id;
  }

  void _generate() {
    final ConsolidationState state = context.read<ConsolidationBloc>().state;
    if (state is! ConsolidationGroupsLoaded) {
      return;
    }
    final String? groupId = state.selectedGroupId ?? _firstGroupId(state);
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a company group before generating.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.read<ConsolidationBloc>().add(
          GenerateReportEvent(groupId: groupId, range: _range),
        );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ConsolidationGroupsLoaded state,
  ) {
    if (state.isGenerating) {
      return const Center(child: CircularProgressIndicator());
    }
    final ConsolidatedReportEntity? report = state.report;
    if (report == null) {
      return _EmptyState(
        hasGroups: state.groups.isNotEmpty,
        onGenerate: _generate,
      );
    }
    return ListView(
      children: <Widget>[
        _KpiRow(report: report),
        const SizedBox(height: 16),
        _ChartCard(report: report),
        const SizedBox(height: 16),
        _ComparisonMatrix(report: report),
        const SizedBox(height: 16),
        _EliminationsCard(report: report),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.report});

  final ConsolidatedReportEntity report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _KpiCard(
            label: 'Consolidated revenue',
            value: report.consolidatedRevenue,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Consolidated expenses',
            value: report.consolidatedExpenses,
            color: AppColors.rose,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Consolidated net income',
            value: report.consolidatedNetIncome,
            color: report.consolidatedNetIncome >= 0
                ? AppColors.primary
                : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormatters.currency(value, symbol: '₼'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.report});

  final ConsolidatedReportEntity report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Member comparison',
      child: SizedBox(
        height: 280,
        child: ConsolidationStackedBarChart(
          report: report,
          formatter: (double value) =>
              AppFormatters.currency(value, symbol: '₼'),
        ),
      ),
    );
  }
}

class _ComparisonMatrix extends StatelessWidget {
  const _ComparisonMatrix({required this.report});

  final ConsolidatedReportEntity report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Side-by-side comparison',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          columns: const <DataColumn>[
            DataColumn(label: Text('Company')),
            DataColumn(label: Text('Revenue'), numeric: true),
            DataColumn(label: Text('Expenses'), numeric: true),
            DataColumn(label: Text('Net'), numeric: true),
            DataColumn(label: Text('Eliminated'), numeric: true),
            DataColumn(label: Text('Adjusted net'), numeric: true),
          ],
          rows: <DataRow>[
            for (final ConsolidatedMemberSummary summary
                in report.memberSummaries)
              DataRow(
                cells: <DataCell>[
                  DataCell(Text(summary.companyName)),
                  _moneyCell(summary.revenue, theme),
                  _moneyCell(summary.expenses, theme),
                  _moneyCell(summary.netIncome, theme),
                  _moneyCell(
                    summary.eliminatedRevenue + summary.eliminatedExpenses,
                    theme,
                  ),
                  _moneyCell(summary.adjustedNetIncome, theme, bold: true),
                ],
              ),
            DataRow(
              cells: <DataCell>[
                DataCell(
                  Text(
                    'Consolidated',
                    style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.secondary),
                  ),
                ),
                _moneyCell(report.consolidatedRevenue, theme),
                _moneyCell(report.consolidatedExpenses, theme),
                _moneyCell(report.consolidatedNetIncome, theme),
                _moneyCell(report.eliminatedTotal, theme),
                _moneyCell(report.consolidatedNetIncome, theme, bold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataCell _moneyCell(double value, ThemeData theme, {bool bold = false}) {
    final Color color = value < 0 ? AppColors.error : null;
    return DataCell(
      Text(
        AppFormatters.decimal(value),
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _EliminationsCard extends StatelessWidget {
  const _EliminationsCard({required this.report});

  final ConsolidatedReportEntity report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<IntercompanyElimination> eliminations = report.eliminations;
    return _SectionCard(
      title:
          'Intercompany eliminations (${eliminations.length}) · ${AppFormatters.currency(report.eliminatedTotal, symbol: '₼')}',
      child: eliminations.isEmpty
          ? Text(
              'No intercompany activity detected in this period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: <Widget>[
                for (final IntercompanyElimination elimination in eliminations)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      elimination.source ==
                              IntercompanyEliminationSource.document
                          ? Icons.description_outlined
                          : Icons.swap_horiz_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    title: Text(
                      '${elimination.sellerCompanyName} → '
                      '${elimination.buyerCompanyName}',
                    ),
                    subtitle: Text(
                      elimination.source ==
                              IntercompanyEliminationSource.document
                          ? 'Invoice ${elimination.id.replaceFirst('doc-', '')}'
                          : 'Bank line ${elimination.id.replaceFirst('tx-', '')}',
                    ),
                    trailing: Text(
                      AppFormatters.currency(
                        elimination.amount,
                        symbol: '₼',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasGroups, required this.onGenerate});

  final bool hasGroups;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            hasGroups
                ? 'Select a group and generate a report.'
                : 'Create a company group to begin consolidation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasGroups) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.insights_rounded, size: 17),
              label: const Text('Generate Report'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline_rounded,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _GroupDraft {
  const _GroupDraft({
    required this.name,
    required this.parentId,
    required this.subsidiaryIds,
  });

  final String name;
  final String parentId;
  final List<String> subsidiaryIds;
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.companies});

  final List<CompanyEntity> companies;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _parentId;
  final Set<String> _subsidiaryIds = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New company group'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Group name',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _parentId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Parent company',
              ),
              items: <DropdownMenuItem<String>>[
                for (final CompanyEntity company in widget.companies)
                  DropdownMenuItem<String>(
                    value: company.id,
                    child: Text(company.name),
                  ),
              ],
              onChanged: (String? value) => setState(() => _parentId = value),
            ),
            const SizedBox(height: 16),
            Text(
              'Subsidiary companies',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (final CompanyEntity company in widget.companies)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(company.name),
                        value: _subsidiaryIds.contains(company.id),
                        onChanged: company.id == _parentId
                            ? null
                            : (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _subsidiaryIds.add(company.id);
                                  } else {
                                    _subsidiaryIds.remove(company.id);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () {
                  Navigator.of(context).pop(
                    _GroupDraft(
                      name: _nameController.text.trim(),
                      parentId: _parentId!,
                      subsidiaryIds: _subsidiaryIds.toList(growable: false),
                    ),
                  );
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _parentId != null;
}
