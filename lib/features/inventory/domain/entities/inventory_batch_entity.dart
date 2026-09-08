import 'package:equatable/equatable.dart';

/// A single FIFO valuation layer for a product in one warehouse.
///
/// Batches are consumed oldest-first (by `receivedAt`) when stock leaves the
/// warehouse under the FIFO cost-flow assumption.
class InventoryBatchEntity extends Equatable {
  const InventoryBatchEntity({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.warehouseId,
    required this.receivedAt,
    required this.purchaseUnitCost,
    required this.initialQty,
    required this.remainingQty,
  });

  final String id;
  final String companyId;
  final String productId;
  final String warehouseId;
  final DateTime receivedAt;
  final double purchaseUnitCost;
  final double initialQty;
  final double remainingQty;

  InventoryBatchEntity copyWith({
    String? id,
    String? companyId,
    String? productId,
    String? warehouseId,
    DateTime? receivedAt,
    double? purchaseUnitCost,
    double? initialQty,
    double? remainingQty,
  }) {
    return InventoryBatchEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      productId: productId ?? this.productId,
      warehouseId: warehouseId ?? this.warehouseId,
      receivedAt: receivedAt ?? this.receivedAt,
      purchaseUnitCost: purchaseUnitCost ?? this.purchaseUnitCost,
      initialQty: initialQty ?? this.initialQty,
      remainingQty: remainingQty ?? this.remainingQty,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        productId,
        warehouseId,
        receivedAt,
        purchaseUnitCost,
        initialQty,
        remainingQty,
      ];
}
