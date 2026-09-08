import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/services/asset_depreciation_engine.dart';
import '../models/asset_model.dart';
import '../models/depreciation_schedule_model.dart';

/// SQLite boundary for the fixed asset register and depreciation schedules.
abstract interface class AssetLocalDataSource {
  Future<List<AssetModel>> getAssets(String companyId);

  Future<AssetModel?> getAsset(String assetId);

  Future<void> createAsset(AssetModel asset);

  Future<void> updateAsset(AssetModel asset);

  Future<void> insertSchedule(DepreciationScheduleModel schedule);

  Future<List<DepreciationScheduleModel>> getSchedules(String assetId);

  Future<void> writeJournalEntry(AssetJournalEntry entry);
}

class AssetLocalDataSourceImpl implements AssetLocalDataSource {
  AssetLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<AssetModel>> getAssets(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.assets,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'asset_code ASC',
    );
    return rows.map(AssetModel.fromMap).toList(growable: false);
  }

  @override
  Future<AssetModel?> getAsset(String assetId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.assets,
      where: 'id = ?',
      whereArgs: <Object?>[assetId],
      limit: 1,
    );
    return rows.isEmpty ? null : AssetModel.fromMap(rows.first);
  }

  @override
  Future<void> createAsset(AssetModel asset) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.assets,
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateAsset(AssetModel asset) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.assets,
      asset.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[asset.id],
    );
  }

  @override
  Future<void> insertSchedule(DepreciationScheduleModel schedule) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.depreciationSchedules,
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<DepreciationScheduleModel>> getSchedules(String assetId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.depreciationSchedules,
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
      orderBy: 'period_date ASC',
    );
    return rows.map(DepreciationScheduleModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> writeJournalEntry(AssetJournalEntry entry) async {
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
