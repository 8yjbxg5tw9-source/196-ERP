import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';

/// One bank-statement cash movement row.
class BankCashRow {
  const BankCashRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.counterpartyName,
  });

  final DateTime date;
  final String description;
  final double amount;
  final String type; // 'credit' | 'debit'
  final String category;
  final String? counterpartyName;
}

/// One general-ledger journal line row.
class JournalCashRow {
  const JournalCashRow({
    required this.entryDate,
    required this.description,
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
  });

  final DateTime entryDate;
  final String description;
  final String debitAccount;
  final String creditAccount;
  final double amount;
}

/// Split of unrealized FX P&L posted in a period.
class FxImpactRow {
  const FxImpactRow({required this.gain, required this.loss});

  final double gain;
  final double loss;
}

/// SQLite boundary for the cash flow engine: bank ledger, general ledger
/// cash postings, non-cash adjustments, and working-capital deltas.
abstract interface class CashFlowLocalDataSource {
  Future<List<BankCashRow>> getBankTransactions(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<List<JournalCashRow>> getJournalEntries(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<double> sumDepreciation(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<FxImpactRow> sumUnrealizedFx(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  /// Outstanding sales invoices (receivables) as of [before].
  Future<double> receivablesAt(String companyId, DateTime before);

  /// Net inventory value change over the period (purchases − COGS).
  Future<double> netInventoryChange(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  /// Net accounts-payable change over the period from journal postings.
  Future<double> netPayablesChange(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });
}

class CashFlowLocalDataSourceImpl implements CashFlowLocalDataSource {
  CashFlowLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<BankCashRow>> getBankTransactions(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
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
      orderBy: 'date ASC',
    );
    return rows.map(_bankRowFromMap).toList(growable: false);
  }

  @override
  Future<List<JournalCashRow>> getJournalEntries(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
    if (start != null) {
      where.write(' AND entry_date >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND entry_date < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.journalEntries,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'entry_date ASC',
    );
    return rows.map(_journalRowFromMap).toList(growable: false);
  }

  @override
  Future<double> sumDepreciation(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ? AND is_posted = 1');
    if (start != null) {
      where.write(' AND period_date >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND period_date < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(depreciation_amount), 0) AS total '
      'FROM ${DatabaseTables.depreciationSchedules} '
      'WHERE $where',
      args,
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  @override
  Future<FxImpactRow> sumUnrealizedFx(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ? AND is_posted = 1');
    if (start != null) {
      where.write(' AND revaluation_date >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND revaluation_date < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(total_unrealized_gain), 0) AS gain, '
      'COALESCE(SUM(total_unrealized_loss), 0) AS loss '
      'FROM ${DatabaseTables.fxRevaluations} '
      'WHERE $where',
      args,
    );
    if (rows.isEmpty) {
      return const FxImpactRow(gain: 0, loss: 0);
    }
    return FxImpactRow(
      gain: _doubleValue(rows.first['gain']),
      loss: _doubleValue(rows.first['loss']),
    );
  }

  @override
  Future<double> receivablesAt(String companyId, DateTime before) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) AS total '
      'FROM ${DatabaseTables.documents} '
      'WHERE company_id = ? AND status = ? '
      'AND COALESCE(issue_date, created_at) < ?',
      <Object?>[companyId, 'completed', before.toUtc().toIso8601String()],
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  @override
  Future<double> netInventoryChange(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
    if (start != null) {
      where.write(' AND timestamp >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND timestamp < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(total_cost), 0) AS total '
      'FROM ${DatabaseTables.stockMovements} '
      'WHERE $where',
      args,
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  @override
  Future<double> netPayablesChange(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
    if (start != null) {
      where.write(' AND entry_date >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND entry_date < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT '
      'COALESCE(SUM(CASE WHEN credit_account = ? THEN amount ELSE 0 END), 0) '
      'AS credit_total, '
      'COALESCE(SUM(CASE WHEN debit_account = ? THEN amount ELSE 0 END), 0) '
      'AS debit_total '
      'FROM ${DatabaseTables.journalEntries} '
      'WHERE $where',
      <Object?>['201', '201', ...args],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return _doubleValue(rows.first['credit_total']) -
        _doubleValue(rows.first['debit_total']);
  }

  static BankCashRow _bankRowFromMap(Map<String, Object?> map) {
    return BankCashRow(
      date:
          DateTime.tryParse(map['date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      description: map['description']?.toString() ?? '',
      amount: _doubleValue(map['amount']),
      type: map['transaction_type']?.toString().toLowerCase() == 'credit'
          ? 'credit'
          : 'debit',
      category: map['category']?.toString() ?? '',
      counterpartyName: map['counterparty_name']?.toString(),
    );
  }

  static JournalCashRow _journalRowFromMap(Map<String, Object?> map) {
    return JournalCashRow(
      entryDate:
          DateTime.tryParse(map['entry_date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      description: map['description']?.toString() ?? '',
      debitAccount: map['debit_account']?.toString() ?? '',
      creditAccount: map['credit_account']?.toString() ?? '',
      amount: _doubleValue(map['amount']),
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
