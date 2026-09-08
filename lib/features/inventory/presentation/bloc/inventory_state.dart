import 'package:equatable/equatable.dart';

import '../../domain/entities/product_item_entity.dart';
import '../../domain/entities/warehouse_entity.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => const <Object?>[];
}

class InventoryInitial extends InventoryState {
  const InventoryInitial();
}

class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

class StockLoaded extends InventoryState {
  const StockLoaded({
    required this.products,
    required this.warehouses,
    this.quantitiesByProduct = const <String, Map<String, double>>{},
  });

  final List<ProductItemEntity> products;
  final List<WarehouseEntity> warehouses;

  /// product id → (warehouse id → quantity on hand).
  final Map<String, Map<String, double>> quantitiesByProduct;

  @override
  List<Object?> get props => <Object?>[products, warehouses, quantitiesByProduct];
}

class StockMovementSuccess extends InventoryState {
  const StockMovementSuccess({
    required this.message,
    this.products = const <ProductItemEntity>[],
    this.warehouses = const <WarehouseEntity>[],
    this.quantitiesByProduct = const <String, Map<String, double>>{},
  });

  final String message;
  final List<ProductItemEntity> products;
  final List<WarehouseEntity> warehouses;
  final Map<String, Map<String, double>> quantitiesByProduct;

  @override
  List<Object?> get props =>
      <Object?>[message, products, warehouses, quantitiesByProduct];
}

class InventoryError extends InventoryState {
  const InventoryError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
