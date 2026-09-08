import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/services/payroll_engine.dart';
import '../models/employee_model.dart';
import '../models/payroll_record_model.dart';

/// SQLite boundary for employees and computed payroll records.
abstract interface class PayrollLocalDataSource {
  Future<List<EmployeeModel>> getEmployees(String companyId);

  Future<void> createEmployee(EmployeeModel employee);

  Future<void> upsertPayrollRecord(PayrollRecordModel record);

  Future<List<PayrollRecordModel>> getPayrollRecords({
    required String companyId,
    int? periodMonth,
    int? periodYear,
  });

  Future<void> writeJournalEntry(PayrollJournalEntry entry);
}

class PayrollLocalDataSourceImpl implements PayrollLocalDataSource {
  PayrollLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<EmployeeModel>> getEmployees(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.employees,
      where: 'company_id = ? AND is_active = 1',
      whereArgs: <Object?>[companyId],
      orderBy: 'full_name COLLATE NOCASE ASC',
    );
    return rows.map(EmployeeModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> createEmployee(EmployeeModel employee) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.employees,
      employee.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> upsertPayrollRecord(PayrollRecordModel record) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.payrollRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<PayrollRecordModel>> getPayrollRecords({
    required String companyId,
    int? periodMonth,
    int? periodYear,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
    if (periodMonth != null) {
      where.write(' AND period_month = ?');
      args.add(periodMonth);
    }
    if (periodYear != null) {
      where.write(' AND period_year = ?');
      args.add(periodYear);
    }
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.payrollRecords,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'period_year DESC, period_month DESC, id ASC',
    );
    return rows.map(PayrollRecordModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> writeJournalEntry(PayrollJournalEntry entry) async {
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
