import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/revaluation/fx_balance_entity.dart';
import '../../domain/revaluation/fx_revaluation_entity.dart';
import '../models/fx_balance_model.dart';
import '../models/fx_revaluation_model.dart';

/// One journal line to persist to the general ledger.
class FxJournalEntryInput {
  const FxJournalEntryInput({
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

/// SQLite boundary for FX balances and revaluation runs.
abstract interface class FxRevaluationLocalDataSource {
  Future<List<FxBalanceModel>> getBalances(String companyId);

  Future<void> upsertBalance(FxBalanceModel balance);

  Future<void> insertRevaluation(FxRevaluationModel revaluation);

  Future<void> updateRevaluation(FxRevaluationModel revaluation);

  Future<FxRevaluationModel?> getRevaluation(String revaluationId);

  Future<List<FxRevaluationModel>> getHistory(String companyId);

  Future<void> writeJournalEntry(FxJournalEntryInput entry);
}

class FxRevaluationLocalDataSourceImpl
    implements FxRevaluationLocalDataSource {
  FxRevaluationLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<FxBalanceModel>> getBalances(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.fxBalances,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'foreign_currency ASC, account_id ASC',
    );
    return rows.map(FxBalanceModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> upsertBalance(FxBalanceModel balance) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.fxBalances,
      balance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertRevaluation(FxRevaluationModel revaluation) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.fxRevaluations,
      revaluation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateRevaluation(FxRevaluationModel revaluation) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.fxRevaluations,
      revaluation.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[revaluation.id],
    );
  }

  @override
  Future<FxRevaluationModel?> getRevaluation(String revaluationId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.fxRevaluations,
      where: 'id = ?',
      whereArgs: <Object?>[revaluationId],
      limit: 1,
    );
    return rows.isEmpty ? null : FxRevaluationModel.fromMap(rows.first);
  }

  @override
  Future<List<FxRevaluationModel>> getHistory(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.fxRevaluations,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'revaluation_date DESC',
    );
    return rows.map(FxRevaluationModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> writeJournalEntry(FxJournalEntryInput entry) async {
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
}
