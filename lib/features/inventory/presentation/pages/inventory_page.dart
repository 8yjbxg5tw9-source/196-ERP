import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/product_item_entity.dart';
import '../../domain/entities/stock_movement_entity.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';

/// Multi-warehouse stock directory with reorder warnings, stock movement /
/// transfer modals, and COGS-aware valuation (FIFO / moving average).
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<InventoryBloc>(
          create: (_) => sl<InventoryBloc>(),
          child: _InventoryWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _InventoryWorkspace extends StatefulWidget {
  const _InventoryWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_InventoryWorkspace> createState() => _InventoryWorkspaceState();
}

class _InventoryWorkspaceState extends State<_InventoryWorkspace> {
  @override
  void initState() {
    super.initState();
    _dispatchLoadIfReady();
  }

  @override
  void didUpdateWidget(covariant _InventoryWorkspace oldWidget) {
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
    context.read<InventoryBloc>().add(LoadWarehousesAndStockEvent(companyId));
  }

  String get _companyId => widget.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Warehouses'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openNewProduct,
            icon: const Icon(Icons.add_box_outlined, size: 17),
            label: const Text('New Product'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openMovement,
            icon: const Icon(Icons.swap_vert_rounded, size: 17),
            label: const Text('Stock Movement'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openTransfer,
            icon: const Icon(Icons.local_shipping_outlined, size: 17),
            label: const Text('Transfer'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (BuildContext context, InventoryState state) {
          if (state is StockMovementSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, InventoryState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.warehouse_outlined,
              title: 'Select an active company',
              message: 'Inventory is scoped to the active company.',
            );
          }
          if (state is InventoryLoading || state is InventoryInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Inventory unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchLoadIfReady,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }

          final List<ProductItemEntity> products = state is StockLoaded
              ? state.products
              : state is StockMovementSuccess
                    ? state.products
                    : const <ProductItemEntity>[];
          final List<WarehouseEntity> warehouses = state is StockLoaded
              ? state.warehouses
              : state is StockMovementSuccess
                    ? state.warehouses
                    : const <WarehouseEntity>[];
          final Map<String, Map<String, double>> quantities =
              state is StockLoaded
                  ? state.quantitiesByProduct
                  : state is StockMovementSuccess
                        ? state.quantitiesByProduct
                        : const <String, Map<String, double>>{};

          return _StockTable(
            products: products,
            warehouses: warehouses,
            quantitiesByProduct: quantities,
            onNewProduct: _openNewProduct,
            onMovement: _openMovement,
            onTransfer: _openTransfer,
          );
        },
      ),
    );
  }

  void _openNewProduct() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _NewProductDialog(companyId: _companyId),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  void _openMovement() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    final InventoryState state = context.read<InventoryBloc>().state;
    final List<ProductItemEntity> products = state is StockLoaded
        ? state.products
        : state is StockMovementSuccess
              ? state.products
              : const <ProductItemEntity>[];
    final List<WarehouseEntity> warehouses = state is StockLoaded
        ? state.warehouses
        : state is StockMovementSuccess
              ? state.warehouses
              : const <WarehouseEntity>[];
    if (products.isEmpty || warehouses.isEmpty) {
      _showSnack('Add a product and a warehouse first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _MovementDialog(
        companyId: _companyId,
        products: products,
        warehouses: warehouses,
      ),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  void _openTransfer() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    final InventoryState state = context.read<InventoryBloc>().state;
    final List<ProductItemEntity> products = state is StockLoaded
        ? state.products
        : state is StockMovementSuccess
              ? state.products
              : const <ProductItemEntity>[];
    final List<WarehouseEntity> warehouses = state is StockLoaded
        ? state.warehouses
        : state is StockMovementSuccess
              ? state.warehouses
              : const <WarehouseEntity>[];
    if (products.isEmpty || warehouses.length < 2) {
      _showSnack('Add a product and at least two warehouses first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _TransferDialog(
        companyId: _companyId,
        products: products,
        warehouses: warehouses,
      ),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({
    required this.products,
    required this.warehouses,
    required this.quantitiesByProduct,
    required this.onNewProduct,
    required this.onMovement,
    required this.onTransfer,
  });

  final List<ProductItemEntity> products;
  final List<WarehouseEntity> warehouses;
  final Map<String, Map<String, double>> quantitiesByProduct;
  final VoidCallback onNewProduct;
  final VoidCallback onMovement;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _WorkspaceMessage(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Create your first product to begin tracking stock.',
        action: FilledButton.icon(
          onPressed: onNewProduct,
          icon: const Icon(Icons.add_box_outlined, size: 17),
          label: const Text('New Product'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KpiStrip(products: products),
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
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Warehouse')),
            DataColumn(label: Text('Qty on Hand'), numeric: true),
            DataColumn(label: Text('Avg Cost'), numeric: true),
            DataColumn(label: Text('Total Value'), numeric: true),
            DataColumn(label: Text('Status')),
          ],
          rows: <DataRow>[
            for (final ProductItemEntity product in products)
              _buildRow(context, product),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, ProductItemEntity product) {
    final ThemeData theme = Theme.of(context);
    final Map<String, double> quantities =
        quantitiesByProduct[product.id] ?? const <String, double>{};
    final List<String> warehouseLines = <String>[
      for (final WarehouseEntity warehouse in warehouses)
        if ((quantities[warehouse.id] ?? 0) > 0)
          '${warehouse.code}: ${AppFormatters.decimal(quantities[warehouse.id] ?? 0, decimalDigits: 0)}',
    ];
    final String warehouseLabel = warehouseLines.isEmpty
        ? '—'
        : warehouseLines.join('  ·  ');

    return DataRow(
      cells: <DataCell>[
        DataCell(Text(product.sku)),
        DataCell(
          Tooltip(
            message: '${product.name} (${product.category})',
            child: Text(product.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(
          Text(
            warehouseLabel,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DataCell(Text(AppFormatters.decimal(product.totalQuantity))),
        DataCell(Text(AppFormatters.decimal(product.averageUnitCost))),
        DataCell(Text(AppFormatters.decimal(product.totalValue))),
        DataCell(
          product.needsReorder
              ? _ReorderBadge(method: product.valuationMethod)
              : Text(
                  product.valuationMethod.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReorderBadge extends StatelessWidget {
  const _ReorderBadge({required this.method});

  final InventoryValuationMethod method;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.warning.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            'Reorder · ${method.label}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.products});

  final List<ProductItemEntity> products;

  @override
  Widget build(BuildContext context) {
    double totalValue = 0;
    int reorderCount = 0;
    for (final ProductItemEntity product in products) {
      totalValue += product.totalValue;
      if (product.needsReorder) {
        reorderCount += 1;
      }
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiCard(
          label: 'Total Asset Value',
          value: AppFormatters.currency(totalValue, symbol: '₼'),
          icon: Icons.payments_outlined,
          color: AppColors.success,
        ),
        _KpiCard(
          label: 'Products',
          value: '${products.length}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
        ),
        _KpiCard(
          label: 'Reorder Alerts',
          value: '$reorderCount',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
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

class _NewProductDialog extends StatefulWidget {
  const _NewProductDialog({required this.companyId});

  final String companyId;

  @override
  State<_NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<_NewProductDialog> {
  final TextEditingController _sku = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _reorderLevel = TextEditingController(text: '0');
  UnitOfMeasure _unit = UnitOfMeasure.pcs;
  InventoryValuationMethod _method = InventoryValuationMethod.movingAverage;

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _category.dispose();
    _reorderLevel.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _sku.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New product'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _sku,
                autofocus: true,
                decoration: const InputDecoration(isDense: true, labelText: 'SKU'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(isDense: true, labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _category,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Category',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<UnitOfMeasure>(
                value: _unit,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, labelText: 'Unit'),
                items: <DropdownMenuItem<UnitOfMeasure>>[
                  for (final UnitOfMeasure unit in UnitOfMeasure.values)
                    DropdownMenuItem<UnitOfMeasure>(
                      value: unit,
                      child: Text(unit.label),
                    ),
                ],
                onChanged: (UnitOfMeasure? value) {
                  if (value != null) {
                    setState(() => _unit = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<InventoryValuationMethod>(
                value: _method,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Valuation method',
                ),
                items: <DropdownMenuItem<InventoryValuationMethod>>[
                  for (final InventoryValuationMethod method
                      in InventoryValuationMethod.values)
                    DropdownMenuItem<InventoryValuationMethod>(
                      value: method,
                      child: Text(method.label),
                    ),
                ],
                onChanged: (InventoryValuationMethod? value) {
                  if (value != null) {
                    setState(() => _method = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reorderLevel,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Reorder level',
                ),
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
                  context.read<InventoryBloc>().add(
                        CreateProductItemEvent(
                          ProductItemEntity(
                            id: '',
                            companyId: widget.companyId,
                            sku: _sku.text.trim(),
                            name: _name.text.trim(),
                            category: _category.text.trim().isEmpty
                                ? 'General'
                                : _category.text.trim(),
                            unitOfMeasure: _unit,
                            valuationMethod: _method,
                            reorderLevel:
                                double.tryParse(_reorderLevel.text.trim()) ?? 0,
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

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({
    required this.companyId,
    required this.products,
    required this.warehouses,
  });

  final String companyId;
  final List<ProductItemEntity> products;
  final List<WarehouseEntity> warehouses;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  String? _productId;
  String? _warehouseId;
  StockMovementType _type = StockMovementType.purchaseIn;
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _unitCost = TextEditingController();
  final TextEditingController _reference = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _reference.dispose();
    super.dispose();
  }

  bool get _needsUnitCost =>
      _type == StockMovementType.purchaseIn ||
      _type == StockMovementType.return_;

  bool get _canSave {
    final double quantity = double.tryParse(_quantity.text.trim()) ?? 0;
    if (_productId == null || _warehouseId == null || quantity == 0) {
      return false;
    }
    if (_needsUnitCost && (double.tryParse(_unitCost.text.trim()) ?? 0) <= 0) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record stock movement'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _productId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, labelText: 'Product'),
                items: <DropdownMenuItem<String>>[
                  for (final ProductItemEntity product in widget.products)
                    DropdownMenuItem<String>(
                      value: product.id,
                      child: Text('${product.sku} · ${product.name}'),
                    ),
                ],
                onChanged: (String? value) => setState(() => _productId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Warehouse',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final WarehouseEntity warehouse in widget.warehouses)
                    DropdownMenuItem<String>(
                      value: warehouse.id,
                      child: Text('${warehouse.code} · ${warehouse.name}'),
                    ),
                ],
                onChanged: (String? value) => setState(() => _warehouseId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<StockMovementType>(
                value: _type,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, labelText: 'Type'),
                items: <DropdownMenuItem<StockMovementType>>[
                  for (final StockMovementType type in <StockMovementType>[
                    StockMovementType.purchaseIn,
                    StockMovementType.saleOut,
                    StockMovementType.adjustment,
                    StockMovementType.return_,
                  ])
                    DropdownMenuItem<StockMovementType>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (StockMovementType? value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: _type == StockMovementType.adjustment
                      ? 'Quantity (+ add / − remove)'
                      : 'Quantity',
                ),
              ),
              if (_needsUnitCost) ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: _unitCost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Unit cost',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Reference (invoice / document)',
                ),
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
                  final double quantity =
                      double.tryParse(_quantity.text.trim()) ?? 0;
                  final double unitCost =
                      double.tryParse(_unitCost.text.trim()) ?? 0;
                  context.read<InventoryBloc>().add(
                        RecordStockMovementEvent(
                          companyId: widget.companyId,
                          productId: _productId!,
                          warehouseId: _warehouseId!,
                          type: _type,
                          quantity: quantity,
                          unitCost: unitCost,
                          referenceDocId: _reference.text.trim().isEmpty
                              ? null
                              : _reference.text.trim(),
                        ),
                      );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Record'),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({
    required this.companyId,
    required this.products,
    required this.warehouses,
  });

  final String companyId;
  final List<ProductItemEntity> products;
  final List<WarehouseEntity> warehouses;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  String? _productId;
  String? _fromWarehouseId;
  String? _toWarehouseId;
  final TextEditingController _quantity = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _productId != null &&
      _fromWarehouseId != null &&
      _toWarehouseId != null &&
      _fromWarehouseId != _toWarehouseId &&
      (double.tryParse(_quantity.text.trim()) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer stock'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _productId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, labelText: 'Product'),
                items: <DropdownMenuItem<String>>[
                  for (final ProductItemEntity product in widget.products)
                    DropdownMenuItem<String>(
                      value: product.id,
                      child: Text('${product.sku} · ${product.name}'),
                    ),
                ],
                onChanged: (String? value) => setState(() => _productId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _fromWarehouseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'From warehouse',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final WarehouseEntity warehouse in widget.warehouses)
                    DropdownMenuItem<String>(
                      value: warehouse.id,
                      child: Text('${warehouse.code} · ${warehouse.name}'),
                    ),
                ],
                onChanged: (String? value) =>
                    setState(() => _fromWarehouseId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _toWarehouseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'To warehouse',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final WarehouseEntity warehouse in widget.warehouses)
                    DropdownMenuItem<String>(
                      value: warehouse.id,
                      child: Text('${warehouse.code} · ${warehouse.name}'),
                    ),
                ],
                onChanged: (String? value) =>
                    setState(() => _toWarehouseId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Quantity',
                ),
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
                  context.read<InventoryBloc>().add(
                        TransferStockBetweenWarehousesEvent(
                          companyId: widget.companyId,
                          productId: _productId!,
                          fromWarehouseId: _fromWarehouseId!,
                          toWarehouseId: _toWarehouseId!,
                          quantity: double.tryParse(_quantity.text.trim()) ?? 0,
                        ),
                      );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Transfer'),
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
