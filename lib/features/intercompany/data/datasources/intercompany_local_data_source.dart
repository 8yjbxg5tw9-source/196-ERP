import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/services/intercompany_engine.dart';
import '../models/dividend_distribution_model.dart';
import '../models/interest_schedule_model.dart';
import '../models/intercompany_loan_model.dart';

/// SQLite boundary for intercompany loans, schedules, and dividends.
abstract interface class IntercompanyLocalDataSource {
  Future<List<IntercompanyLoanModel>> getLoans();

  Future<IntercompanyLoanModel?> getLoan(String loanId);

  Future<void> createLoan(IntercompanyLoanModel loan);

  Future<void> updateLoan(IntercompanyLoanModel loan);

  Future<void> insertSchedule(InterestScheduleModel schedule);

  Future<List<InterestScheduleModel>> getSchedule(String loanId);

  Future<List<DividendDistributionModel>> getDividends();

  Future<DividendDistributionModel?> getDividend(String dividendId);

  Future<void> insertDividend(DividendDistributionModel dividend);

  Future<void> writeJournalEntry(JournalEntryPlan plan);
}

class IntercompanyLocalDataSourceImpl implements IntercompanyLocalDataSource {
  IntercompanyLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<IntercompanyLoanModel>> getLoans() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.intercompanyLoans,
      orderBy: 'created_at ASC',
    );
    return rows.map(IntercompanyLoanModel.fromMap).toList(growable: false);
  }

  @override
  Future<IntercompanyLoanModel?> getLoan(String loanId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.intercompanyLoans,
      where: 'id = ?',
      whereArgs: <Object?>[loanId],
      limit: 1,
    );
    return rows.isEmpty ? null : IntercompanyLoanModel.fromMap(rows.first);
  }

  @override
  Future<void> createLoan(IntercompanyLoanModel loan) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.intercompanyLoans,
      loan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateLoan(IntercompanyLoanModel loan) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.intercompanyLoans,
      loan.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[loan.id],
    );
  }

  @override
  Future<void> insertSchedule(InterestScheduleModel schedule) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.interestSchedules,
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<InterestScheduleModel>> getSchedule(String loanId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.interestSchedules,
      where: 'loan_id = ?',
      whereArgs: <Object?>[loanId],
      orderBy: 'period_date ASC',
    );
    return rows.map(InterestScheduleModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<DividendDistributionModel>> getDividends() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.dividendDistributions,
      orderBy: 'declaration_date DESC',
    );
    return rows
        .map(DividendDistributionModel.fromMap)
        .toList(growable: false);
  }

  @override
  Future<DividendDistributionModel?> getDividend(String dividendId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.dividendDistributions,
      where: 'id = ?',
      whereArgs: <Object?>[dividendId],
      limit: 1,
    );
    return rows.isEmpty ? null : DividendDistributionModel.fromMap(rows.first);
  }

  @override
  Future<void> insertDividend(DividendDistributionModel dividend) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.dividendDistributions,
      dividend.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> writeJournalEntry(JournalEntryPlan plan) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.journalEntries,
      <String, Object?>{
        'id': 'journal-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        'company_id': plan.companyId,
        'entry_date': plan.entryDate.toUtc().toIso8601String(),
        'description': plan.description,
        'debit_account': plan.debitAccount,
        'credit_account': plan.creditAccount,
        'amount': plan.amount,
        'source_type': plan.sourceType,
        'source_id': plan.sourceId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
