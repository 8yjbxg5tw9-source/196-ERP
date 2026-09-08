import 'package:equatable/equatable.dart';

/// Stock keeping unit of measure.
enum UnitOfMeasure { pcs, kg, meter, liter, box }

extension UnitOfMeasureLabel on UnitOfMeasure {
  String get label => switch (this) {
        UnitOfMeasure.pcs => 'pcs',
        UnitOfMeasure.kg => 'kg',
        UnitOfMeasure.meter => 'm',
        UnitOfMeasure.liter => 'L',
        UnitOfMeasure.box => 'box',
      };
}

/// Cost-flow assumption used to value the product's stock and COGS.
enum InventoryValuationMethod { fifo, movingAverage }

extension InventoryValuationMethodLabel on InventoryValuationMethod {
  String get label => switch (this) {
        InventoryValuationMethod.fifo => 'FIFO',
        InventoryValuationMethod.movingAverage => 'Moving Average',
      };
}

/// A stock directory master record with aggregated position fields.
class ProductItemEntity extends Equatable {
  const ProductItemEntity({
    required this.id,
    required this.companyId,
    required this.sku,
    this.barcode,
    required this.name,
    required this.category,
    required this.unitOfMeasure,
    required this.valuationMethod,
    this.reorderLevel = 0,
    this.totalQuantity = 0,
    this.totalValue = 0,
    this.averageUnitCost = 0,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String sku;
  final String? barcode;
  final String name;
  final String category;
  final UnitOfMeasure unitOfMeasure;
  final InventoryValuationMethod valuationMethod;
  final double reorderLevel;
  final double totalQuantity;
  final double totalValue;
  final double averageUnitCost;
  final DateTime? createdAt;

  bool get needsReorder => totalQuantity <= reorderLevel;

  ProductItemEntity copyWith({
    String? id,
    String? companyId,
    String? sku,
    Object? barcode = _unset,
    String? name,
    String? category,
    UnitOfMeasure? unitOfMeasure,
    InventoryValuationMethod? valuationMethod,
    double? reorderLevel,
    double? totalQuantity,
    double? totalValue,
    double? averageUnitCost,
    DateTime? createdAt,
  }) {
    return ProductItemEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      sku: sku ?? this.sku,
      barcode: identical(barcode, _unset) ? this.barcode : barcode as String?,
      name: name ?? this.name,
      category: category ?? this.category,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      valuationMethod: valuationMethod ?? this.valuationMethod,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalValue: totalValue ?? this.totalValue,
      averageUnitCost: averageUnitCost ?? this.averageUnitCost,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        sku,
        barcode,
        name,
        category,
        unitOfMeasure,
        valuationMethod,
        reorderLevel,
        totalQuantity,
        totalValue,
        averageUnitCost,
        createdAt,
      ];
}

const Object _unset = Object();
