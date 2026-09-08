import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';

/// VAT ledger figures assembled from approved invoices and transactions.
class VatFilingInputs {
  const VatFilingInputs({
    this.taxableTurnover = 0,
    this.zeroRatedTurnover = 0,
    this.exemptTurnover = 0,
    this.vatCalculated = 0,
    this.vatDeductible = 0,
  });

  final double taxableTurnover;
  final double zeroRatedTurnover;
  final double exemptTurnover;
  final double vatCalculated;
  final double vatDeductible;

  double get netVatPayable => vatCalculated - vatDeductible;
}

/// Payroll figures assembled from approved payroll records.
class PayrollFilingInputs {
  const PayrollFilingInputs({
    this.grossPayroll = 0,
    this.dsmfContributions = 0,
  });

  final double grossPayroll;
  final double dsmfContributions;
}

/// SQLite boundary for the statutory tax declaration exporter.
abstract interface class TaxDeclarationLocalDataSource {
  Future<VatFilingInputs> loadVatFilingInputs(
    String companyId, {
    required DateTime start,
    required DateTime endExclusive,
  });

  Future<PayrollFilingInputs> loadPayrollFilingInputs(
    String companyId, {
    required int year,
    required List<int> months,
  });
}

class TaxDeclarationLocalDataSourceImpl implements TaxDeclarationLocalDataSource {
  TaxDeclarationLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<VatFilingInputs> loadVatFilingInputs(
    String companyId, {
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT '
      'COALESCE(SUM(CASE WHEN COALESCE(vat_amount, 0) > 0 '
      '  THEN COALESCE(subtotal, COALESCE(total_amount, 0) - COALESCE(vat_amount, 0)) '
      '  ELSE 0 END), 0) AS taxable_turnover, '
      'COALESCE(SUM(CASE WHEN COALESCE(vat_amount, 0) <= 0 '
      '  THEN COALESCE(subtotal, COALESCE(total_amount, 0) - COALESCE(vat_amount, 0)) '
      '  ELSE 0 END), 0) AS zero_rated_turnover, '
      'COALESCE(SUM(COALESCE(vat_amount, 0)), 0) AS vat_calculated '
      'FROM ${DatabaseTables.documents} '
      "WHERE company_id = ? AND status = 'completed' "
      'AND COALESCE(issue_date, created_at) >= ? '
      'AND COALESCE(issue_date, created_at) < ?',
      <Object?>[
        companyId,
        start.toUtc().toIso8601String(),
        endExclusive.toUtc().toIso8601String(),
      ],
    );

    final double inputVat = await _sumInputVat(companyId, start, endExclusive);
    final Map<String, Object?> row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    return VatFilingInputs(
      taxableTurnover: _doubleValue(row['taxable_turnover']),
      zeroRatedTurnover: _doubleValue(row['zero_rated_turnover']),
      vatCalculated: _doubleValue(row['vat_calculated']),
      vatDeductible: inputVat,
    );
  }

  @override
  Future<PayrollFilingInputs> loadPayrollFilingInputs(
    String companyId, {
    required int year,
    required List<int> months,
  }) async {
    if (months.isEmpty) {
      return const PayrollFilingInputs();
    }
    final Database database = await _databaseService.database;
    final String placeholders = List<String>.filled(months.length, '?').join(', ');
    final List<Object?> args = <Object?>[companyId, year, ...months];
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT '
      'COALESCE(SUM(gross_salary), 0) AS gross_payroll, '
      'COALESCE(SUM(employee_dsmf + employer_dsmf), 0) AS dsmf_contributions '
      'FROM ${DatabaseTables.payrollRecords} '
      'WHERE company_id = ? AND period_year = ? '
      'AND period_month IN ($placeholders)',
      args,
    );
    final Map<String, Object?> row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    return PayrollFilingInputs(
      grossPayroll: _doubleValue(row['gross_payroll']),
      dsmfContributions: _doubleValue(row['dsmf_contributions']),
    );
  }

  Future<double> _sumInputVat(
    String companyId,
    DateTime start,
    DateTime endExclusive,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM ${DatabaseTables.transactions} '
      "WHERE company_id = ? AND LOWER(category) IN ('input_vat', 'vat_input') "
      'AND date >= ? AND date < ?',
      <Object?>[
        companyId,
        start.toUtc().toIso8601String(),
        endExclusive.toUtc().toIso8601String(),
      ],
    );
    return rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
  }

  static double _doubleValue(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}
