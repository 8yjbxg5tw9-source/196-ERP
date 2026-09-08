import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/product_item_entity.dart';
import '../entities/stock_movement_entity.dart';
import '../entities/warehouse_entity.dart';

/// Persistence + valuation boundary for multi-warehouse inventory.
abstract interface class InventoryRepository {
  Future<Either<Failure, List<WarehouseEntity>>> getWarehouses(
    String companyId,
  );

  Future<Either<Failure, List<ProductItemEntity>>> getProducts(
    String companyId,
  );

  Future<Either<Failure, ProductItemEntity>> createProduct(
    ProductItemEntity product,
  );

  Future<Either<Failure, void>> ensurePrimaryWarehouse(String companyId);

  /// Applies a stock movement, updates product aggregates (and FIFO layers),
  /// and posts a COGS journal entry when the movement is an outgoing sale.
  Future<Either<Failure, StockMovementEntity>> recordMovement(
    StockMovementEntity movement,
  );

  /// Moves [quantity] units of a product between two warehouses.
  Future<Either<Failure, List<StockMovementEntity>>> transferStock({
    required String companyId,
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
    required DateTime timestamp,
  });

  Future<Either<Failure, List<StockMovementEntity>>> getMovements(
    String companyId, {
    String? productId,
  });

  /// Quantity on hand per warehouse for a product.
  Future<Either<Failure, Map<String, double>>> getWarehouseQuantities(
    String productId,
  );
}
