import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/audit_log_entity.dart';
import '../models/audit_log_model.dart';

/// SQLite boundary for the append-only audit trail.
abstract interface class AuditLocalDataSource {
  Future<void> insertLog(AuditLogEntity log);

  Future<List<AuditLogEntity>> getLogs({
    String? companyId,
    DateTime? from,
    DateTime? to,
    AuditAction? action,
    String? userId,
    String? search,
  });

  /// The most recent chained hash for [companyId], or null when no chained
  /// record exists yet (the next write starts from the genesis hash).
  Future<String?> getLatestHash(String companyId);

  /// All audit rows for [companyId] in ascending chronological order, for
  /// chain verification (no row limit, unlike [getLogs]).
  Future<List<AuditLogEntity>> getAllLogsAscending(String companyId);
}

class AuditLocalDataSourceImpl implements AuditLocalDataSource {
  AuditLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  static const int _maxRows = 2000;

  @override
  Future<void> insertLog(AuditLogEntity log) async {
    final Database database = await _databaseService.database;
    final AuditLogModel model = log is AuditLogModel
        ? log
        : AuditLogModel(
            id: log.id,
            companyId: log.companyId,
            userId: log.userId,
            userName: log.userName,
            userRole: log.userRole,
            action: log.action,
            entityName: log.entityName,
            entityId: log.entityId,
            beforeState: log.beforeState,
            afterState: log.afterState,
            ipAddress: log.ipAddress,
            timestamp: log.timestamp,
          );
    await database.insert(
      DatabaseTables.auditLogs,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<AuditLogEntity>> getLogs({
    String? companyId,
    DateTime? from,
    DateTime? to,
    AuditAction? action,
    String? userId,
    String? search,
  }) async {
    final Database database = await _databaseService.database;
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    if (companyId != null && companyId.isNotEmpty) {
      clauses.add('company_id = ?');
      args.add(companyId);
    }
    if (from != null) {
      clauses.add('timestamp >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      clauses.add('timestamp <= ?');
      args.add(to.toUtc().toIso8601String());
    }
    if (action != null) {
      clauses.add('action = ?');
      args.add(action.name);
    }
    if (userId != null && userId.isNotEmpty) {
      clauses.add('user_id = ?');
      args.add(userId);
    }
    if (search != null && search.trim().isNotEmpty) {
      clauses.add(
        '(user_name LIKE ? OR entity_name LIKE ? OR entity_id LIKE ? OR '
        'action LIKE ?)',
      );
      final String pattern = '%${search.trim()}%';
      args
        ..add(pattern)
        ..add(pattern)
        ..add(pattern)
        ..add(pattern);
    }

    final String where = clauses.isEmpty ? '' : clauses.join(' AND ');
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.auditLogs,
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: _maxRows,
    );
    return rows.map(AuditLogModel.fromMap).toList(growable: false);
  }

  @override
  Future<String?> getLatestHash(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.auditLogs,
      columns: const <String>['current_hash'],
      where: "company_id = ? AND current_hash IS NOT NULL AND current_hash != ''",
      whereArgs: <Object?>[companyId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['current_hash']?.toString();
  }

  @override
  Future<List<AuditLogEntity>> getAllLogsAscending(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.auditLogs,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(AuditLogModel.fromMap).toList(growable: false);
  }
}
