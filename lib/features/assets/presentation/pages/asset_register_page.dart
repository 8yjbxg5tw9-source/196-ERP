import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/depreciation_schedule_entity.dart';
import '../../domain/repositories/asset_repository.dart';
import '../bloc/asset_bloc.dart';
import '../bloc/asset_event.dart';
import '../bloc/asset_state.dart';

/// Fixed asset register with the monthly depreciation engine, schedule
/// preview, and dispose action.
class AssetRegisterPage extends StatelessWidget {
  const AssetRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<AssetBloc>(
          create: (_) => sl<AssetBloc>(),
          child: _AssetWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _AssetWorkspace extends StatefulWidget {
  const _AssetWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_AssetWorkspace> createState() => _AssetWorkspaceState();
}

class _AssetWorkspaceState extends State<_AssetWorkspace> {
  @override
  void initState() {
    super.initState();
    _dispatchLoadIfReady();
  }

  @override
  void didUpdateWidget(covariant _AssetWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _dispatchLoadIfReady();
    }
  }

  void _dispatchLoadIfReady() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<AssetBloc>().add(LoadAssetsEvent(companyId));
  }

  String get _companyId => widget.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixed Assets'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openNewAsset,
            icon: const Icon(Icons.add_business_outlined, size: 17),
            label: const Text('New Asset'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _runDepreciation,
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: const Text('Run Monthly Depreciation'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<AssetBloc, AssetState>(
        listener: (BuildContext context, AssetState state) {
          if (state is AssetOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AssetError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, AssetState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.business_outlined,
              title: 'Select an active company',
              message: 'Fixed assets are scoped to the active company.',
            );
          }
          if (state is AssetLoading || state is AssetInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AssetError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Fixed assets unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchLoadIfReady,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }

          final List<AssetEntity> assets = state is AssetsLoaded
              ? state.assets
              : state is AssetOperationSuccess
                    ? state.assets
                    : const <AssetEntity>[];

          return _AssetTable(
            assets: assets,
            onNewAsset: _openNewAsset,
            onDispose: _confirmDispose,
            onSchedules: _openSchedules,
          );
        },
      ),
    );
  }

  void _openNewAsset() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    final AssetBloc bloc = context.read<AssetBloc>();
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _NewAssetDialog(
        companyId: _companyId,
        bloc: bloc,
      ),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  void _runDepreciation() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    final AssetState state = context.read<AssetBloc>().state;
    final List<AssetEntity> assets = state is AssetsLoaded
        ? state.assets
        : state is AssetOperationSuccess
              ? state.assets
              : const <AssetEntity>[];
    if (assets.where((AssetEntity a) => a.status == AssetStatus.active).isEmpty) {
      _showSnack('No active assets to depreciate.');
      return;
    }
    context.read<AssetBloc>().add(
          RunMonthlyDepreciationEvent(
            companyId: _companyId,
            periodDate: DateTime.now().toUtc(),
          ),
        );
  }

  void _confirmDispose(AssetEntity asset) {
    final AssetBloc bloc = context.read<AssetBloc>();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Dispose asset'),
        content: Text(
          'Dispose "${asset.name}" (${asset.assetCode})? '
          'The asset will be marked disposed and removed from the '
          'depreciable register.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              bloc.add(DisposeAssetEvent(asset.id));
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Dispose'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  Future<void> _openSchedules(AssetEntity asset) async {
    final AssetRepository repository = sl<AssetRepository>();
    final List<DepreciationScheduleEntity> schedules =
        await repository.getSchedules(asset.id).then(
              (result) => result.fold(
                (_) => const <DepreciationScheduleEntity>[],
                (List<DepreciationScheduleEntity> value) => value,
              ),
            );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext _) => _ScheduleDialog(
        asset: asset,
        schedules: schedules,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _AssetTable extends StatelessWidget {
  const _AssetTable({
    required this.assets,
    required this.onNewAsset,
    required this.onDispose,
    required this.onSchedules,
  });

  final List<AssetEntity> assets;
  final VoidCallback onNewAsset;
  final void Function(AssetEntity asset) onDispose;
  final void Function(AssetEntity asset) onSchedules;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return _WorkspaceMessage(
        icon: Icons.business_outlined,
        title: 'No fixed assets yet',
        message: 'Register your first asset to begin depreciation tracking.',
        action: FilledButton.icon(
          onPressed: onNewAsset,
          icon: const Icon(Icons.add_business_outlined, size: 17),
          label: const Text('New Asset'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KpiStrip(assets: assets),
          const SizedBox(height: 14),
          _buildTable(context),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll<Color>(
            theme.colorScheme.surfaceContainerHighest.withAlpha(70),
          ),
          columns: const <DataColumn>[
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Asset')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Purchased')),
            DataColumn(label: Text('Cost'), numeric: true),
            DataColumn(label: Text('Accum. Depr.'), numeric: true),
            DataColumn(label: Text('Book Value'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: <DataRow>[
            for (final AssetEntity asset in assets) _buildRow(context, asset),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, AssetEntity asset) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = switch (asset.status) {
      AssetStatus.active => AppColors.success,
      AssetStatus.fullyDepreciated => AppColors.primary,
      AssetStatus.disposed => theme.colorScheme.onSurfaceVariant,
    };
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(asset.assetCode)),
        DataCell(
          Tooltip(
            message: '${asset.name} · ${asset.usefulLifeMonths} months life',
            child: Text(asset.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text(asset.category.label)),
        DataCell(Text(asset.depreciationMethod.label)),
        DataCell(Text(AppFormatters.date(asset.purchaseDate))),
        DataCell(Text(AppFormatters.decimal(asset.purchasePrice))),
        DataCell(
          Text(AppFormatters.decimal(asset.accumulatedDepreciation)),
        ),
        DataCell(
          Text(
            AppFormatters.decimal(asset.bookValue),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          Text(
            asset.status.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Depreciation schedule',
                icon: const Icon(Icons.timeline_rounded, size: 18),
                onPressed: () => onSchedules(asset),
              ),
              if (asset.status == AssetStatus.active)
                IconButton(
                  tooltip: 'Dispose',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () => onDispose(asset),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.assets});

  final List<AssetEntity> assets;

  @override
  Widget build(BuildContext context) {
    double bookValue = 0;
    double accumulated = 0;
    int activeCount = 0;
    int fullyDepreciated = 0;
    for (final AssetEntity asset in assets) {
      bookValue += asset.bookValue;
      accumulated += asset.accumulatedDepreciation;
      if (asset.status == AssetStatus.active) {
        activeCount += 1;
      } else if (asset.status == AssetStatus.fullyDepreciated) {
        fullyDepreciated += 1;
      }
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiCard(
          label: 'Carrying Value',
          value: AppFormatters.currency(bookValue, symbol: '₼'),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
        ),
        _KpiCard(
          label: 'Accum. Depreciation',
          value: AppFormatters.currency(accumulated, symbol: '₼'),
          icon: Icons.trending_down_rounded,
          color: AppColors.warning,
        ),
        _KpiCard(
          label: 'Active',
          value: '$activeCount',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
        _KpiCard(
          label: 'Fully Depreciated',
          value: '$fullyDepreciated',
          icon: Icons.task_alt_rounded,
          color: AppColors.accent,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewAssetDialog extends StatefulWidget {
  const _NewAssetDialog({required this.companyId, required this.bloc});

  final String companyId;
  final AssetBloc bloc;

  @override
  State<_NewAssetDialog> createState() => _NewAssetDialogState();
}

class _NewAssetDialogState extends State<_NewAssetDialog> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _salvage = TextEditingController(text: '0');
  final TextEditingController _life = TextEditingController();
  final TextEditingController _purchaseDate = TextEditingController(
    text: _defaultDate(),
  );
  AssetCategory _category = AssetCategory.machinery;
  DepreciationMethod _method = DepreciationMethod.straightLine;

  static String _defaultDate() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _price.dispose();
    _salvage.dispose();
    _life.dispose();
    _purchaseDate.dispose();
    super.dispose();
  }

  bool get _canSave {
    final double price = double.tryParse(_price.text.trim()) ?? -1;
    final int life = int.tryParse(_life.text.trim()) ?? 0;
    final DateTime? date = DateTime.tryParse(_purchaseDate.text.trim());
    return _code.text.trim().isNotEmpty &&
        _name.text.trim().isNotEmpty &&
        price >= 0 &&
        life > 0 &&
        date != null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New fixed asset'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _code,
                      autofocus: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Asset code',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Name',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<AssetCategory>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Category',
                      ),
                      items: <DropdownMenuItem<AssetCategory>>[
                        for (final AssetCategory category
                            in AssetCategory.values)
                          DropdownMenuItem<AssetCategory>(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: (AssetCategory? value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<DepreciationMethod>(
                      value: _method,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Method',
                      ),
                      items: <DropdownMenuItem<DepreciationMethod>>[
                        for (final DepreciationMethod method
                            in DepreciationMethod.values)
                          DropdownMenuItem<DepreciationMethod>(
                            value: method,
                            child: Text(method.label),
                          ),
                      ],
                      onChanged: (DepreciationMethod? value) {
                        if (value != null) {
                          setState(() => _method = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Purchase price (AZN)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _salvage,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Salvage value (AZN)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _life,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Useful life (months)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _purchaseDate,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Purchase date (yyyy-mm-dd)',
                      ),
                    ),
                  ),
                ],
              ),
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
                  final double price =
                      double.tryParse(_price.text.trim()) ?? 0;
                  widget.bloc.add(
                    CreateAssetEvent(
                      AssetEntity(
                        id: '',
                        companyId: widget.companyId,
                        assetCode: _code.text.trim(),
                        name: _name.text.trim(),
                        category: _category,
                        purchaseDate:
                            DateTime.parse(_purchaseDate.text.trim()),
                        purchasePrice: price,
                        salvageValue:
                            double.tryParse(_salvage.text.trim()) ?? 0,
                        usefulLifeMonths:
                            int.tryParse(_life.text.trim()) ?? 12,
                        depreciationMethod: _method,
                        bookValue: price,
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ScheduleDialog extends StatelessWidget {
  const _ScheduleDialog({required this.asset, required this.schedules});

  final AssetEntity asset;
  final List<DepreciationScheduleEntity> schedules;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Depreciation schedule · ${asset.assetCode}'),
      content: SizedBox(
        width: 560,
        child: schedules.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No depreciation posted yet for this asset.'),
              )
            : SingleChildScrollView(
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Period')),
                    DataColumn(label: Text('Depreciation'), numeric: true),
                    DataColumn(label: Text('Accumulated'), numeric: true),
                    DataColumn(label: Text('Ending Book'), numeric: true),
                  ],
                  rows: <DataRow>[
                    for (final DepreciationScheduleEntity schedule in schedules)
                      DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Text(AppFormatters.date(schedule.periodDate)),
                          ),
                          DataCell(
                            Text(
                              AppFormatters.decimal(
                                schedule.depreciationAmount,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              AppFormatters.decimal(schedule.accumulatedAmount),
                            ),
                          ),
                          DataCell(
                            Text(
                              AppFormatters.decimal(schedule.endingBookValue),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
