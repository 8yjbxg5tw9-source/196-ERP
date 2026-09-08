import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../models/inventory_batch_model.dart';
import '../models/product_item_model.dart';
import '../models/stock_movement_model.dart';
import '../models/warehouse_model.dart';

/// One journal line to persist to the general ledger.
class JournalEntryInput {
  const JournalEntryInput({
    required this.companyId,
    required this.entryDate,
    required this.description,
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
  });

  final String companyId;
  final DateTime entryDate;
  final String description;
  final String debitAccount;
  final String creditAccount;
  final double amount;
  final String sourceType;
  final String sourceId;
}

/// SQLite boundary for warehouses, products, stock movements, and FIFO layers.
abstract interface class InventoryLocalDataSource {
  Future<List<WarehouseModel>> getWarehouses(String companyId);

  Future<int> countWarehouses(String companyId);

  Future<void> createWarehouse(WarehouseModel warehouse);

  Future<List<ProductItemModel>> getProducts(String companyId);

  Future<ProductItemModel?> getProduct(String productId);

  Future<void> createProduct(ProductItemModel product);

  Future<void> updateProduct(ProductItemModel product);

  Future<List<InventoryBatchModel>> getBatches(
    String productId,
    String warehouseId,
  );

  Future<InventoryBatchModel?> getBatch(String batchId);

  Future<void> createBatch(InventoryBatchModel batch);

  Future<void> updateBatch(InventoryBatchModel batch);

  Future<void> deleteBatch(String batchId);

  Future<void> insertMovement(StockMovementModel movement);

  Future<List<StockMovementModel>> getMovements(
    String companyId, {
    String? productId,
  });

  Future<Map<String, double>> getWarehouseQuantities(String productId);

  Future<void> writeJournalEntry(JournalEntryInput entry);
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  InventoryLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<WarehouseModel>> getWarehouses(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.warehouses,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'is_primary DESC, code ASC',
    );
    return rows.map(WarehouseModel.fromMap).toList(growable: false);
  }

  @override
  Future<int> countWarehouses(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.warehouses} '
      'WHERE company_id = ?',
      <Object?>[companyId],
    );
    final Object? total = rows.isEmpty ? null : rows.first['total'];
    return total is int ? total : (int.tryParse(total?.toString() ?? '') ?? 0);
  }

  @override
  Future<void> createWarehouse(WarehouseModel warehouse) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.warehouses,
      warehouse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<ProductItemModel>> getProducts(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.products,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'sku ASC',
    );
    return rows.map(ProductItemModel.fromMap).toList(growable: false);
  }

  @override
  Future<ProductItemModel?> getProduct(String productId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.products,
      where: 'id = ?',
      whereArgs: <Object?>[productId],
      limit: 1,
    );
    return rows.isEmpty ? null : ProductItemModel.fromMap(rows.first);
  }

  @override
  Future<void> createProduct(ProductItemModel product) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.products,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateProduct(ProductItemModel product) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.products,
      product.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[product.id],
    );
  }

  @override
  Future<List<InventoryBatchModel>> getBatches(
    String productId,
    String warehouseId,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.inventoryBatches,
      where: 'product_id = ? AND warehouse_id = ? AND remaining_qty > 0',
      whereArgs: <Object?>[productId, warehouseId],
      orderBy: 'received_at ASC, id ASC',
    );
    return rows.map(InventoryBatchModel.fromMap).toList(growable: false);
  }

  @override
  Future<InventoryBatchModel?> getBatch(String batchId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.inventoryBatches,
      where: 'id = ?',
      whereArgs: <Object?>[batchId],
      limit: 1,
    );
    return rows.isEmpty ? null : InventoryBatchModel.fromMap(rows.first);
  }

  @override
  Future<void> createBatch(InventoryBatchModel batch) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.inventoryBatches,
      batch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateBatch(InventoryBatchModel batch) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.inventoryBatches,
      batch.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[batch.id],
    );
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    final Database database = await _databaseService.database;
    await database.delete(
      DatabaseTables.inventoryBatches,
      where: 'id = ?',
      whereArgs: <Object?>[batchId],
    );
  }

  @override
  Future<void> insertMovement(StockMovementModel movement) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.stockMovements,
      movement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<StockMovementModel>> getMovements(
    String companyId, {
    String? productId,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
    if (productId != null) {
      where.write(' AND product_id = ?');
      args.add(productId);
    }
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.stockMovements,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'timestamp DESC',
    );
    return rows.map(StockMovementModel.fromMap).toList(growable: false);
  }

  @override
  Future<Map<String, double>> getWarehouseQuantities(String productId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT warehouse_id, COALESCE(SUM(quantity), 0) AS total '
      'FROM ${DatabaseTables.stockMovements} '
      'WHERE product_id = ? '
      'GROUP BY warehouse_id',
      <Object?>[productId],
    );
    final Map<String, double> result = <String, double>{};
    for (final Map<String, Object?> row in rows) {
      result[row['warehouse_id']?.toString() ?? ''] =
          _double(row['total']);
    }
    return result;
  }

  @override
  Future<void> writeJournalEntry(JournalEntryInput entry) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.journalEntries,
      <String, Object?>{
        'id': 'journal-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        'company_id': entry.companyId,
        'entry_date': entry.entryDate.toUtc().toIso8601String(),
        'description': entry.description,
        'debit_account': entry.debitAccount,
        'credit_account': entry.creditAccount,
        'amount': entry.amount,
        'source_type': entry.sourceType,
        'source_id': entry.sourceId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
