import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../models/bank_transaction_model.dart';

abstract interface class ReconciliationLocalDataSource {
  Future<List<BankTransactionModel>> getTransactions(String companyId);

  Future<BankTransactionModel?> getTransaction(String transactionId);

  Future<void> saveTransactions(List<BankTransactionModel> transactions);

  /// Updates every reconciliation column in one SQLite transaction.
  Future<void> updateTransaction(BankTransactionModel transaction);
}

class ReconciliationLocalDataSourceImpl
    implements ReconciliationLocalDataSource {
  ReconciliationLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<BankTransactionModel>> getTransactions(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.transactions,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'date DESC',
    );
    return rows
        .map(BankTransactionModel.fromMap)
        .toList(growable: false);
  }

  @override
  Future<BankTransactionModel?> getTransaction(String transactionId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.transactions,
      where: 'id = ?',
      whereArgs: <Object?>[transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : BankTransactionModel.fromMap(rows.first);
  }

  @override
  Future<void> saveTransactions(List<BankTransactionModel> transactions) async {
    if (transactions.isEmpty) {
      return;
    }
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      for (final BankTransactionModel bankTransaction in transactions) {
        await transaction.insert(
          DatabaseTables.transactions,
          bankTransaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> updateTransaction(BankTransactionModel transaction) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction databaseTransaction) async {
      final int updatedRows = await databaseTransaction.update(
        DatabaseTables.transactions,
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[transaction.id],
      );
      if (updatedRows == 0) {
        throw StateError('Unknown bank transaction: ${transaction.id}');
      }
    });
  }
}
