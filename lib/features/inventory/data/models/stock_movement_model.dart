import '../../domain/entities/stock_movement_entity.dart';

/// SQLite mapping for the `stock_movements` table.
///
/// `quantity` is stored signed: positive brings stock into the source
/// warehouse, negative removes it. A transfer writes two rows (out-leg and
/// in-leg) so per-warehouse balances aggregate as a plain `SUM(quantity)`.
class StockMovementModel extends StockMovementEntity {
  const StockMovementModel({
    required super.id,
    required super.companyId,
    required super.productId,
    required super.warehouseId,
    super.targetWarehouseId,
    required super.type,
    required super.quantity,
    required super.unitCost,
    required super.totalCost,
    super.referenceDocId,
    required super.timestamp,
  });

  factory StockMovementModel.fromMap(Map<String, Object?> map) {
    return StockMovementModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      warehouseId: map['warehouse_id']?.toString() ?? '',
      targetWarehouseId: _nullable(map['target_warehouse_id']),
      type: StockMovementTypeValues.fromStorage(
        map['movement_type']?.toString() ?? '',
      ),
      quantity: _double(map['quantity']),
      unitCost: _double(map['unit_cost']),
      totalCost: _double(map['total_cost']),
      referenceDocId: _nullable(map['reference_doc_id']),
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'target_warehouse_id': targetWarehouseId,
      'movement_type': type.storageValue,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'reference_doc_id': referenceDocId,
      'timestamp': timestamp.toUtc().toIso8601String(),
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
}
