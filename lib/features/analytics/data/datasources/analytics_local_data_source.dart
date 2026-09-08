import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/chart_of_accounts.dart';
import '../models/account_model.dart';
import 'chart_of_accounts_seeder.dart';

/// One row of the grouped ledger aggregation query.
class TransactionAggregate {
  const TransactionAggregate({
    required this.category,
    required this.type,
    required this.total,
  });

  final String category;
  final String type;
  final double total;
}

/// One row of the month-grouped ledger aggregation query.
class MonthlyTransactionAggregate {
  const MonthlyTransactionAggregate({
    required this.month,
    required this.category,
    required this.type,
    required this.total,
  });

  /// `yyyy-MM` bucket label.
  final String month;
  final String category;
  final String type;
  final double total;
}

/// SQLite boundary for the reporting engine and chart of accounts.
abstract interface class AnalyticsLocalDataSource {
  Future<List<AccountModel>> getAccounts(String companyId);

  Future<void> seedDefaultAccounts(String companyId);

  Future<List<TransactionAggregate>> aggregateTransactions(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<List<MonthlyTransactionAggregate>> aggregateMonthlyTransactions(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<double> sumDocuments(
    String companyId, {
    required String column,
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<Map<String, double>> sumDocumentsByMonth(
    String companyId, {
    required String column,
    DateTime? start,
    DateTime? endExclusive,
  });

  Future<int> countDocuments(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  });

  /// Cumulative inventory value from the stock ledger up to [endExclusive].
  Future<double> sumInventoryValue(
    String companyId, {
    DateTime? endExclusive,
  });

  /// Net book value of the fixed asset register.
  Future<double> sumFixedAssetsBookValue(String companyId);
}

class AnalyticsLocalDataSourceImpl implements AnalyticsLocalDataSource {
  AnalyticsLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<AccountModel>> getAccounts(String companyId) async {
    await seedDefaultAccounts(companyId);
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.accounts,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'code ASC',
    );
    return rows.map(AccountModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> seedDefaultAccounts(String companyId) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      for (final AccountEntity account
          in ChartOfAccountsSeeder.defaultAccounts(companyId)) {
        await transaction.insert(
          DatabaseTables.accounts,
          AccountModel.fromEntity(account).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<List<TransactionAggregate>> aggregateTransactions(
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

    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT LOWER(category) AS category, '
      'LOWER(transaction_type) AS type, '
      'COALESCE(SUM(amount), 0) AS total '
      'FROM ${DatabaseTables.transactions} '
      'WHERE $where '
      'GROUP BY LOWER(category), LOWER(transaction_type)',
      args,
    );
    return rows
        .map(
          (Map<String, Object?> row) => TransactionAggregate(
            category: row['category']?.toString() ?? '',
            type: row['type']?.toString() ?? '',
            total: _doubleValue(row['total']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MonthlyTransactionAggregate>> aggregateMonthlyTransactions(
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

    final List<Map<String, Object?>> rows = await database.rawQuery(
      "SELECT strftime('%Y-%m', date) AS month, "
      'LOWER(category) AS category, '
      'LOWER(transaction_type) AS type, '
      'COALESCE(SUM(amount), 0) AS total '
      'FROM ${DatabaseTables.transactions} '
      'WHERE $where '
      "GROUP BY strftime('%Y-%m', date), LOWER(category), "
      'LOWER(transaction_type)',
      args,
    );
    return rows
        .map(
          (Map<String, Object?> row) => MonthlyTransactionAggregate(
            month: row['month']?.toString() ?? '',
            category: row['category']?.toString() ?? '',
            type: row['type']?.toString() ?? '',
            total: _doubleValue(row['total']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<double> sumDocuments(
    String companyId, {
    required String column,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    _validateDocumentColumn(column);
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId, 'completed'];
    final StringBuffer where = StringBuffer('company_id = ? AND status = ?');
    if (start != null) {
      where.write(' AND COALESCE(issue_date, created_at) >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND COALESCE(issue_date, created_at) < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }

    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM($column), 0) AS total '
      'FROM ${DatabaseTables.documents} '
      'WHERE $where',
      args,
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  @override
  Future<Map<String, double>> sumDocumentsByMonth(
    String companyId, {
    required String column,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    _validateDocumentColumn(column);
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId, 'completed'];
    final StringBuffer where = StringBuffer('company_id = ? AND status = ?');
    if (start != null) {
      where.write(' AND COALESCE(issue_date, created_at) >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND COALESCE(issue_date, created_at) < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }

    final List<Map<String, Object?>> rows = await database.rawQuery(
      "SELECT strftime('%Y-%m', COALESCE(issue_date, created_at)) AS month, "
      'COALESCE(SUM($column), 0) AS total '
      'FROM ${DatabaseTables.documents} '
      'WHERE $where '
      "GROUP BY strftime('%Y-%m', COALESCE(issue_date, created_at))",
      args,
    );
    final Map<String, double> result = <String, double>{};
    for (final Map<String, Object?> row in rows) {
      result[row['month']?.toString() ?? ''] = _doubleValue(row['total']);
    }
    return result;
  }

  @override
  Future<int> countDocuments(
    String companyId, {
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId, 'completed'];
    final StringBuffer where = StringBuffer('company_id = ? AND status = ?');
    if (start != null) {
      where.write(' AND COALESCE(issue_date, created_at) >= ?');
      args.add(start.toUtc().toIso8601String());
    }
    if (endExclusive != null) {
      where.write(' AND COALESCE(issue_date, created_at) < ?');
      args.add(endExclusive.toUtc().toIso8601String());
    }

    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM ${DatabaseTables.documents} '
      'WHERE $where',
      args,
    );
    final Object? total = rows.isEmpty ? null : rows.first['total'];
    return total is int ? total : (int.tryParse(total?.toString() ?? '') ?? 0);
  }

  @override
  Future<double> sumInventoryValue(
    String companyId, {
    DateTime? endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[companyId];
    final StringBuffer where = StringBuffer('company_id = ?');
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
  Future<double> sumFixedAssetsBookValue(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(book_value), 0) AS total '
      'FROM ${DatabaseTables.assets} '
      "WHERE company_id = ? AND status != 'disposed'",
      <Object?>[companyId],
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  static void _validateDocumentColumn(String column) {
    const List<String> allowed = <String>[
      'total_amount',
      'vat_amount',
      'subtotal',
    ];
    if (!allowed.contains(column)) {
      throw ArgumentError.value(column, 'column', 'Unsupported document column');
    }
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
