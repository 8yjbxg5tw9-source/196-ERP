import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../../document_ocr/data/models/document_model.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../../reconciliation/data/models/bank_transaction_model.dart';
import '../../../reconciliation/domain/entities/bank_transaction_entity.dart';
import '../models/company_group_model.dart';

/// SQLite boundary for company groups and the raw member activity the
/// elimination engine consumes.
abstract interface class ConsolidationLocalDataSource {
  Future<List<CompanyGroupModel>> getGroups();

  Future<CompanyGroupModel?> getGroup(String groupId);

  Future<CompanyGroupModel> createGroup(CompanyGroupModel group);

  Future<List<DocumentEntity>> getDocumentsForCompanies(
    List<String> companyIds, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<List<BankTransactionEntity>> getTransactionsForCompanies(
    List<String> companyIds, {
    DateTime? start,
    DateTime? endExclusive,
  });
}

class ConsolidationLocalDataSourceImpl implements ConsolidationLocalDataSource {
  ConsolidationLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<CompanyGroupModel>> getGroups() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.companyGroups,
      orderBy: 'created_at DESC',
    );
    return rows.map(CompanyGroupModel.fromMap).toList(growable: false);
  }

  @override
  Future<CompanyGroupModel?> getGroup(String groupId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.companyGroups,
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : CompanyGroupModel.fromMap(rows.first);
  }

  @override
  Future<CompanyGroupModel> createGroup(CompanyGroupModel group) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.companyGroups,
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return group;
  }

  @override
  Future<List<DocumentEntity>> getDocumentsForCompanies(
    List<String> companyIds, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    if (companyIds.isEmpty) {
      return const <DocumentEntity>[];
    }
    final Database database = await _databaseService.database;
    final String placeholders = List<String>.filled(companyIds.length, '?')
        .join(', ');
    final List<Object?> args = <Object?>[...companyIds];
    final StringBuffer where = StringBuffer('company_id IN ($placeholders)');
    if (start != null) {
      where.write(' AND COALESCE(issue_date, created_at) >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND COALESCE(issue_date, created_at) < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }

    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.documents,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'COALESCE(issue_date, created_at) DESC',
    );
    return rows
        .map(DocumentModel.fromSqflite)
        .toList(growable: false);
  }

  @override
  Future<List<BankTransactionEntity>> getTransactionsForCompanies(
    List<String> companyIds, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    if (companyIds.isEmpty) {
      return const <BankTransactionEntity>[];
    }
    final Database database = await _databaseService.database;
    final String placeholders = List<String>.filled(companyIds.length, '?')
        .join(', ');
    final List<Object?> args = <Object?>[...companyIds];
    final StringBuffer where = StringBuffer('company_id IN ($placeholders)');
    if (start != null) {
      where.write(' AND date >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND date < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }

    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.transactions,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return rows.map(BankTransactionModel.fromMap).toList(growable: false);
  }
}
