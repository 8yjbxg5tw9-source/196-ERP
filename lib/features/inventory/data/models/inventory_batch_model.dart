import '../../domain/entities/inventory_batch_entity.dart';

/// SQLite mapping for the `inventory_batches` table.
class InventoryBatchModel extends InventoryBatchEntity {
  const InventoryBatchModel({
    required super.id,
    required super.companyId,
    required super.productId,
    required super.warehouseId,
    required super.receivedAt,
    required super.purchaseUnitCost,
    required super.initialQty,
    required super.remainingQty,
  });

  factory InventoryBatchModel.fromMap(Map<String, Object?> map) {
    return InventoryBatchModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      warehouseId: map['warehouse_id']?.toString() ?? '',
      receivedAt: DateTime.tryParse(map['received_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      purchaseUnitCost: _double(map['purchase_unit_cost']),
      initialQty: _double(map['initial_qty']),
      remainingQty: _double(map['remaining_qty']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'received_at': receivedAt.toUtc().toIso8601String(),
      'purchase_unit_cost': purchaseUnitCost,
      'initial_qty': initialQty,
      'remaining_qty': remainingQty,
    };
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
