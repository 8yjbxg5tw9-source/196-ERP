import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/inventory_batch_entity.dart';
import '../../domain/entities/product_item_entity.dart';
import '../../domain/entities/stock_movement_entity.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/services/inventory_valuation_engine.dart';
import '../datasources/inventory_local_data_source.dart';
import '../models/inventory_batch_model.dart';
import '../models/product_item_model.dart';
import '../models/stock_movement_model.dart';
import '../models/warehouse_model.dart';

/// SQLite-backed inventory store with FIFO / moving-average valuation and
/// automatic COGS journal posting on outgoing sales.
class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(
    this._localDataSource, {
    InventoryValuationEngine valuationEngine =
        const InventoryValuationEngine(),
  }) : _valuationEngine = valuationEngine;

  /// Chart-of-accounts posting codes (journal entries store free-text account
  /// codes; see the step notes for the mapping to the seeded chart).
  static const String _cogsAccount = '601';
  static const String _inventoryAccount = '201';

  final InventoryLocalDataSource _localDataSource;
  final InventoryValuationEngine _valuationEngine;

  @override
  Future<Either<Failure, List<WarehouseEntity>>> getWarehouses(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<WarehouseEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }
    try {
      final List<WarehouseModel> warehouses =
          await _localDataSource.getWarehouses(normalizedCompanyId);
      return Right<Failure, List<WarehouseEntity>>(warehouses);
    } on DatabaseException catch (error) {
      return Left<Failure, List<WarehouseEntity>>(
        DatabaseFailure(message: 'Warehouses could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<WarehouseEntity>>(
        CacheFailure(message: 'Warehouses could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductItemEntity>>> getProducts(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<ProductItemEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }
    try {
      final List<ProductItemModel> products =
          await _localDataSource.getProducts(normalizedCompanyId);
      return Right<Failure, List<ProductItemEntity>>(products);
    } on DatabaseException catch (error) {
      return Left<Failure, List<ProductItemEntity>>(
        DatabaseFailure(message: 'Products could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<ProductItemEntity>>(
        CacheFailure(message: 'Products could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, ProductItemEntity>> createProduct(
    ProductItemEntity product,
  ) async {
    if (product.sku.trim().isEmpty || product.name.trim().isEmpty) {
      return Left<Failure, ProductItemEntity>(
        const ValidationFailure(message: 'SKU and name are required.'),
      );
    }
    if (product.companyId.trim().isEmpty) {
      return Left<Failure, ProductItemEntity>(
        const ValidationFailure(message: 'Select a company before adding stock.'),
      );
    }
    try {
      final ProductItemModel model = ProductItemModel(
        id: product.id.isEmpty
            ? 'product-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : product.id,
        companyId: product.companyId,
        sku: product.sku.trim(),
        barcode: product.barcode,
        name: product.name.trim(),
        category: product.category.trim(),
        unitOfMeasure: product.unitOfMeasure,
        valuationMethod: product.valuationMethod,
        reorderLevel: product.reorderLevel,
        totalQuantity: 0,
        totalValue: 0,
        averageUnitCost: 0,
        createdAt: product.createdAt ?? DateTime.now().toUtc(),
      );
      await _localDataSource.createProduct(model);
      return Right<Failure, ProductItemEntity>(model);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return Left<Failure, ProductItemEntity>(
          ValidationFailure(
            message: 'A product with SKU "${product.sku}" already exists.',
            cause: error,
          ),
        );
      }
      return Left<Failure, ProductItemEntity>(
        DatabaseFailure(message: 'The product could not be created.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, ProductItemEntity>(
        CacheFailure(message: 'The product could not be saved.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, void>> ensurePrimaryWarehouse(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, void>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }
    try {
      final int count = await _localDataSource.countWarehouses(
        normalizedCompanyId,
      );
      if (count == 0) {
        await _localDataSource.createWarehouse(
          WarehouseModel(
            id: 'warehouse-${DateTime.now().toUtc().microsecondsSinceEpoch}',
            companyId: normalizedCompanyId,
            code: 'WH-01',
            name: 'Main Warehouse',
            location: 'Head Office',
            isPrimary: true,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The default warehouse could not be created.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'The default warehouse could not be saved.'),
      );
    }
  }

  @override
  Future<Either<Failure, StockMovementEntity>> recordMovement(
    StockMovementEntity movement,
  ) async {
    if (movement.companyId.trim().isEmpty ||
        movement.productId.trim().isEmpty ||
        movement.warehouseId.trim().isEmpty) {
      return Left<Failure, StockMovementEntity>(
        const ValidationFailure(
          message: 'Company, product, and warehouse are required.',
        ),
      );
    }
    if (movement.quantity == 0) {
      return Left<Failure, StockMovementEntity>(
        const ValidationFailure(message: 'Quantity must not be zero.'),
      );
    }

    try {
      final ProductItemModel? product = await _localDataSource.getProduct(
        movement.productId,
      );
      if (product == null) {
        return Left<Failure, StockMovementEntity>(
          NotFoundFailure(message: 'Product ${movement.productId} was not found.'),
        );
      }

      final _Applied applied;
      switch (movement.type) {
        case StockMovementType.purchaseIn:
        case StockMovementType.return_:
          applied = await _applyReceipt(product, movement);
          break;
        case StockMovementType.saleOut:
          applied = await _applyDispatch(product, movement);
          break;
        case StockMovementType.adjustment:
          applied = await _applyAdjustment(product, movement);
          break;
        case StockMovementType.transfer:
          return Left<Failure, StockMovementEntity>(
            const ValidationFailure(
              message: 'Use transferStock for warehouse transfers.',
            ),
          );
      }

      final double signedQuantity =
          movement.type == StockMovementType.saleOut
              ? -movement.quantity.abs()
              : (movement.type == StockMovementType.adjustment
                    ? movement.quantity
                    : movement.quantity.abs());
      final StockMovementModel row = StockMovementModel(
        id: movement.id.isEmpty
            ? 'movement-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : movement.id,
        companyId: movement.companyId,
        productId: movement.productId,
        warehouseId: movement.warehouseId,
        targetWarehouseId: movement.targetWarehouseId,
        type: movement.type,
        quantity: _round(signedQuantity),
        unitCost: applied.unitCost,
        totalCost: _round(signedQuantity * applied.unitCost),
        referenceDocId: movement.referenceDocId,
        timestamp: movement.timestamp,
      );

      await _localDataSource.updateProduct(applied.product);
      await _localDataSource.insertMovement(row);

      if (movement.type == StockMovementType.saleOut) {
        await _localDataSource.writeJournalEntry(
          JournalEntryInput(
            companyId: movement.companyId,
            entryDate: movement.timestamp,
            description: 'COGS for ${product.sku} '
                '(${movement.quantity.abs()} ${product.unitOfMeasure.label})',
            debitAccount: _cogsAccount,
            creditAccount: _inventoryAccount,
            amount: applied.cogs.abs(),
            sourceType: 'inventory',
            sourceId: row.id,
          ),
        );
      }

      return Right<Failure, StockMovementEntity>(row);
    } on ValidationFailure catch (error) {
      return Left<Failure, StockMovementEntity>(error);
    } on DatabaseException catch (error) {
      return Left<Failure, StockMovementEntity>(
        DatabaseFailure(
          message: 'The stock movement could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, StockMovementEntity>(
        CacheFailure(message: 'The stock movement could not be applied.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, List<StockMovementEntity>>> transferStock({
    required String companyId,
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
    required DateTime timestamp,
  }) async {
    if (companyId.trim().isEmpty || productId.trim().isEmpty) {
      return Left<Failure, List<StockMovementEntity>>(
        const ValidationFailure(
          message: 'Company and product are required for a transfer.',
        ),
      );
    }
    if (fromWarehouseId == toWarehouseId) {
      return Left<Failure, List<StockMovementEntity>>(
        const ValidationFailure(
          message: 'Source and destination warehouses must differ.',
        ),
      );
    }
    if (quantity <= 0) {
      return Left<Failure, List<StockMovementEntity>>(
        const ValidationFailure(
          message: 'Transfer quantity must be greater than zero.',
        ),
      );
    }

    try {
      final ProductItemModel? product = await _localDataSource.getProduct(
        productId,
      );
      if (product == null) {
        return Left<Failure, List<StockMovementEntity>>(
          NotFoundFailure(message: 'Product $productId was not found.'),
        );
      }

      final double unitCost;
      final List<BatchConsumption> consumed;
      if (product.valuationMethod == InventoryValuationMethod.fifo) {
        final List<InventoryBatchModel> sourceBatches =
            await _localDataSource.getBatches(productId, fromWarehouseId);
        final double available = sourceBatches.fold<double>(
          0,
          (double sum, InventoryBatchEntity b) => sum + b.remainingQty,
        );
        if (available < quantity) {
          return Left<Failure, List<StockMovementEntity>>(
            const ValidationFailure(
              message: 'Insufficient stock in the source warehouse.',
            ),
          );
        }
        final ValuationResult result = _valuationEngine.consumeFifo(
          sourceBatches,
          quantity,
        );
        unitCost = result.unitCost;
        consumed = result.consumedBatches;
      } else {
        unitCost = product.averageUnitCost;
        consumed = const <BatchConsumption>[];
      }

      await _applyBatchConsumption(consumed);
      if (product.valuationMethod == InventoryValuationMethod.fifo) {
        await _localDataSource.createBatch(
          InventoryBatchModel(
            id: 'batch-${DateTime.now().toUtc().microsecondsSinceEpoch}',
            companyId: companyId,
            productId: productId,
            warehouseId: toWarehouseId,
            receivedAt: timestamp,
            purchaseUnitCost: unitCost,
            initialQty: quantity,
            remainingQty: quantity,
          ),
        );
      }

      final String seed = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final StockMovementModel outLeg = StockMovementModel(
        id: 'movement-$seed-out',
        companyId: companyId,
        productId: productId,
        warehouseId: fromWarehouseId,
        targetWarehouseId: toWarehouseId,
        type: StockMovementType.transfer,
        quantity: -quantity,
        unitCost: unitCost,
        totalCost: -quantity * unitCost,
        timestamp: timestamp,
      );
      final StockMovementModel inLeg = StockMovementModel(
        id: 'movement-$seed-in',
        companyId: companyId,
        productId: productId,
        warehouseId: toWarehouseId,
        targetWarehouseId: fromWarehouseId,
        type: StockMovementType.transfer,
        quantity: quantity,
        unitCost: unitCost,
        totalCost: quantity * unitCost,
        timestamp: timestamp,
      );
      await _localDataSource.insertMovement(outLeg);
      await _localDataSource.insertMovement(inLeg);

      return Right<Failure, List<StockMovementEntity>>(
        <StockMovementEntity>[outLeg, inLeg],
      );
    } on ValidationFailure catch (error) {
      return Left<Failure, List<StockMovementEntity>>(error);
    } on DatabaseException catch (error) {
      return Left<Failure, List<StockMovementEntity>>(
        DatabaseFailure(message: 'The stock transfer could not be saved.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<StockMovementEntity>>(
        CacheFailure(message: 'The stock transfer could not be applied.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, List<StockMovementEntity>>> getMovements(
    String companyId, {
    String? productId,
  }) async {
    try {
      final List<StockMovementModel> movements =
          await _localDataSource.getMovements(companyId, productId: productId);
      return Right<Failure, List<StockMovementEntity>>(movements);
    } on DatabaseException catch (error) {
      return Left<Failure, List<StockMovementEntity>>(
        DatabaseFailure(message: 'Stock movements could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<StockMovementEntity>>(
        CacheFailure(message: 'Stock movements could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getWarehouseQuantities(
    String productId,
  ) async {
    try {
      final Map<String, double> quantities =
          await _localDataSource.getWarehouseQuantities(productId);
      return Right<Failure, Map<String, double>>(quantities);
    } on DatabaseException catch (error) {
      return Left<Failure, Map<String, double>>(
        DatabaseFailure(
          message: 'Warehouse stock levels could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, Map<String, double>>(
        CacheFailure(
          message: 'Warehouse stock levels could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  Future<_Applied> _applyReceipt(
    ProductItemModel product,
    StockMovementEntity movement,
  ) async {
    final double quantity = movement.quantity.abs();
    final double unitCost = movement.unitCost;
    if (unitCost < 0) {
      throw const ValidationFailure(message: 'Unit cost must not be negative.');
    }

    if (product.valuationMethod == InventoryValuationMethod.fifo) {
      await _localDataSource.createBatch(
        InventoryBatchModel(
          id: 'batch-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          companyId: product.companyId,
          productId: product.id,
          warehouseId: movement.warehouseId,
          receivedAt: movement.timestamp,
          purchaseUnitCost: unitCost,
          initialQty: quantity,
          remainingQty: quantity,
        ),
      );
    }

    final double totalValue = product.totalValue + quantity * unitCost;
    final double totalQuantity = product.totalQuantity + quantity;
    final double average = totalQuantity <= 0
        ? 0
        : _round(totalValue / totalQuantity);
    return _Applied(
      product: ProductItemModel(
        id: product.id,
        companyId: product.companyId,
        sku: product.sku,
        barcode: product.barcode,
        name: product.name,
        category: product.category,
        unitOfMeasure: product.unitOfMeasure,
        valuationMethod: product.valuationMethod,
        reorderLevel: product.reorderLevel,
        totalQuantity: totalQuantity,
        totalValue: _round(totalValue),
        averageUnitCost: average,
        createdAt: product.createdAt,
      ),
      unitCost: unitCost,
      cogs: 0,
    );
  }

  Future<_Applied> _applyDispatch(
    ProductItemModel product,
    StockMovementEntity movement,
  ) async {
    final double quantity = movement.quantity.abs();
    if (product.totalQuantity < quantity) {
      throw ValidationFailure(
        message: 'Insufficient stock for ${product.sku}.',
      );
    }

    final double cogs;
    final double unitCost;
    final List<BatchConsumption> consumed;
    if (product.valuationMethod == InventoryValuationMethod.fifo) {
      final List<InventoryBatchModel> batches = await _localDataSource.getBatches(
        product.id,
        movement.warehouseId,
      );
      final double available = batches.fold<double>(
        0,
        (double sum, InventoryBatchEntity b) => sum + b.remainingQty,
      );
      if (available < quantity) {
        throw const ValidationFailure(
          message: 'Insufficient stock in the selected warehouse.',
        );
      }
      final ValuationResult result = _valuationEngine.consumeFifo(
        batches,
        quantity,
      );
      cogs = result.costOfGoods;
      unitCost = result.unitCost;
      consumed = result.consumedBatches;
    } else {
      cogs = _round(quantity * product.averageUnitCost);
      unitCost = product.averageUnitCost;
      consumed = const <BatchConsumption>[];
    }

    await _applyBatchConsumption(consumed);

    final double totalQuantity = product.totalQuantity - quantity;
    final double totalValue = product.totalValue - cogs;
    final double average = totalQuantity <= 0
        ? 0
        : _round(totalValue / totalQuantity);
    return _Applied(
      product: ProductItemModel(
        id: product.id,
        companyId: product.companyId,
        sku: product.sku,
        barcode: product.barcode,
        name: product.name,
        category: product.category,
        unitOfMeasure: product.unitOfMeasure,
        valuationMethod: product.valuationMethod,
        reorderLevel: product.reorderLevel,
        totalQuantity: totalQuantity,
        totalValue: _round(totalValue),
        averageUnitCost: average,
        createdAt: product.createdAt,
      ),
      unitCost: unitCost,
      cogs: cogs,
    );
  }

  Future<_Applied> _applyAdjustment(
    ProductItemModel product,
    StockMovementEntity movement,
  ) async {
    final double unitCost = movement.unitCost > 0
        ? movement.unitCost
        : product.averageUnitCost;
    final StockMovementEntity normalized = StockMovementEntity(
      id: movement.id,
      companyId: movement.companyId,
      productId: movement.productId,
      warehouseId: movement.warehouseId,
      targetWarehouseId: movement.targetWarehouseId,
      type: movement.type,
      quantity: movement.quantity,
      unitCost: unitCost,
      totalCost: movement.quantity * unitCost,
      referenceDocId: movement.referenceDocId,
      timestamp: movement.timestamp,
    );
    return movement.quantity > 0
        ? _applyReceipt(product, normalized)
        : _applyDispatch(
            product,
            StockMovementEntity(
              id: movement.id,
              companyId: movement.companyId,
              productId: movement.productId,
              warehouseId: movement.warehouseId,
              targetWarehouseId: movement.targetWarehouseId,
              type: movement.type,
              quantity: movement.quantity.abs(),
              unitCost: unitCost,
              totalCost: movement.quantity.abs() * unitCost,
              referenceDocId: movement.referenceDocId,
              timestamp: movement.timestamp,
            ),
          );
  }

  Future<void> _applyBatchConsumption(List<BatchConsumption> consumptions) async {
    for (final BatchConsumption consumption in consumptions) {
      final InventoryBatchModel? batch =
          await _localDataSource.getBatch(consumption.batchId);
      if (batch == null) {
        continue;
      }
      final double remaining = batch.remainingQty - consumption.quantity;
      if (remaining <= 0.0001) {
        await _localDataSource.deleteBatch(batch.id);
      } else {
        await _localDataSource.updateBatch(
          InventoryBatchModel(
            id: batch.id,
            companyId: batch.companyId,
            productId: batch.productId,
            warehouseId: batch.warehouseId,
            receivedAt: batch.receivedAt,
            purchaseUnitCost: batch.purchaseUnitCost,
            initialQty: batch.initialQty,
            remainingQty: remaining,
          ),
        );
      }
    }
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 100).roundToDouble() / 100;
  }
}

class _Applied {
  const _Applied({
    required this.product,
    required this.unitCost,
    required this.cogs,
  });

  final ProductItemModel product;
  final double unitCost;
  final double cogs;
}
