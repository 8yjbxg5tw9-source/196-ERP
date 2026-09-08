import 'package:equatable/equatable.dart';

import '../../domain/entities/product_item_entity.dart';
import '../../domain/entities/stock_movement_entity.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadWarehousesAndStockEvent extends InventoryEvent {
  const LoadWarehousesAndStockEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class CreateProductItemEvent extends InventoryEvent {
  const CreateProductItemEvent(this.product);

  final ProductItemEntity product;

  @override
  List<Object?> get props => <Object?>[product];
}

class RecordStockMovementEvent extends InventoryEvent {
  const RecordStockMovementEvent({
    required this.companyId,
    required this.productId,
    required this.warehouseId,
    required this.type,
    required this.quantity,
    required this.unitCost,
    this.referenceDocId,
  });

  final String companyId;
  final String productId;
  final String warehouseId;
  final StockMovementType type;
  final double quantity;
  final double unitCost;
  final String? referenceDocId;

  @override
  List<Object?> get props =>
      <Object?>[companyId, productId, warehouseId, type, quantity, unitCost, referenceDocId];
}

class TransferStockBetweenWarehousesEvent extends InventoryEvent {
  const TransferStockBetweenWarehousesEvent({
    required this.companyId,
    required this.productId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.quantity,
  });

  final String companyId;
  final String productId;
  final String fromWarehouseId;
  final String toWarehouseId;
  final double quantity;

  @override
  List<Object?> get props =>
      <Object?>[companyId, productId, fromWarehouseId, toWarehouseId, quantity];
}
