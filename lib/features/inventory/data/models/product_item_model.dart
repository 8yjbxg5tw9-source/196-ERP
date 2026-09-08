import '../../domain/entities/product_item_entity.dart';

/// SQLite mapping for the `products` table.
class ProductItemModel extends ProductItemEntity {
  const ProductItemModel({
    required super.id,
    required super.companyId,
    required super.sku,
    super.barcode,
    required super.name,
    required super.category,
    required super.unitOfMeasure,
    required super.valuationMethod,
    super.reorderLevel,
    super.totalQuantity,
    super.totalValue,
    super.averageUnitCost,
    super.createdAt,
  });

  factory ProductItemModel.fromMap(Map<String, Object?> map) {
    return ProductItemModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      barcode: _nullable(map['barcode']),
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      unitOfMeasure: _unitOfMeasure(map['unit_of_measure']),
      valuationMethod: _valuationMethod(map['valuation_method']),
      reorderLevel: _double(map['reorder_level']),
      totalQuantity: _double(map['total_quantity']),
      totalValue: _double(map['total_value']),
      averageUnitCost: _double(map['average_unit_cost']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'category': category,
      'unit_of_measure': unitOfMeasure.name,
      'valuation_method': valuationMethod.name,
      'reorder_level': reorderLevel,
      'total_quantity': totalQuantity,
      'total_value': totalValue,
      'average_unit_cost': averageUnitCost,
      'created_at': (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  static String? _nullable(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static UnitOfMeasure _unitOfMeasure(Object? value) {
    for (final UnitOfMeasure unit in UnitOfMeasure.values) {
      if (unit.name == value?.toString()) {
        return unit;
      }
    }
    return UnitOfMeasure.pcs;
  }

  static InventoryValuationMethod _valuationMethod(Object? value) {
    for (final InventoryValuationMethod method
        in InventoryValuationMethod.values) {
      if (method.name == value?.toString()) {
        return method;
      }
    }
    return InventoryValuationMethod.movingAverage;
  }
}
