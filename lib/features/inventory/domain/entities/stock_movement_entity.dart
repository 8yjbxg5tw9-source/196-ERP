import 'package:equatable/equatable.dart';

/// The kind of stock event recorded on the ledger.
enum StockMovementType { purchaseIn, saleOut, transfer, adjustment, return_ }

extension StockMovementTypeValues on StockMovementType {
  String get storageValue => switch (this) {
        StockMovementType.purchaseIn => 'purchaseIn',
        StockMovementType.saleOut => 'saleOut',
        StockMovementType.transfer => 'transfer',
        StockMovementType.adjustment => 'adjustment',
        StockMovementType.return_ => 'return',
      };

  String get label => switch (this) {
        StockMovementType.purchaseIn => 'Purchase In',
        StockMovementType.saleOut => 'Sale Out',
        StockMovementType.transfer => 'Transfer',
        StockMovementType.adjustment => 'Adjustment',
        StockMovementType.return_ => 'Return',
      };

  static StockMovementType fromStorage(String value) {
    switch (value) {
      case 'purchaseIn':
        return StockMovementType.purchaseIn;
      case 'saleOut':
        return StockMovementType.saleOut;
      case 'transfer':
        return StockMovementType.transfer;
      case 'adjustment':
        return StockMovementType.adjustment;
      case 'return':
        return StockMovementType.return_;
      default:
        return StockMovementType.adjustment;
    }
  }
}

/// One signed entry in the stock ledger.
class StockMovementEntity extends Equatable {
  const StockMovementEntity({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.warehouseId,
    this.targetWarehouseId,
    required this.type,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.referenceDocId,
    required this.timestamp,
  });

  final String id;
  final String companyId;
  final String productId;
  final String warehouseId;
  final String? targetWarehouseId;
  final StockMovementType type;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final String? referenceDocId;
  final DateTime timestamp;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        productId,
        warehouseId,
        targetWarehouseId,
        type,
        quantity,
        unitCost,
        totalCost,
        referenceDocId,
        timestamp,
      ];
}
