import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/deferred_tax_journal_entry.dart';
import '../../domain/entities/tax_base_comparison.dart';
import '../models/deferred_tax_calculation_model.dart';
import '../models/temporary_difference_model.dart';

/// One raw fixed-asset row used to build the book-vs-tax comparison.
class AssetComparisonRow {
  const AssetComparisonRow({
    required this.name,
    required this.category,
    required this.purchaseDate,
    required this.purchasePrice,
    required this.salvageValue,
    required this.bookValue,
  });

  final String name;
  final String category;
  final DateTime purchaseDate;
  final double purchasePrice;
  final double salvageValue;
  final double bookValue;
}

/// SQLite boundary for the deferred tax engine: asset register reads,
/// provision heuristics, and calculation persistence.
abstract interface class DeferredTaxLocalDataSource {
  Future<List<TaxBaseComparison>> loadAssetComparisons(
    String companyId,
    DateTime asOfDate,
  );

  Future<List<TaxBaseComparison>> loadProvisionComparisons(String companyId);

  Future<DeferredTaxCalculationModel?> getLatestCalculation(
    String companyId,
    int year,
  );

  Future<List<TemporaryDifferenceModel>> getDifferences(String calculationId);

  Future<void> replaceCalculation(DeferredTaxCalculationModel calculation);

  Future<void> replaceDifferences(
    String calculationId,
    List<TemporaryDifferenceModel> items,
  );

  Future<void> markCalculationPosted(String calculationId);

  Future<void> writeJournalEntry(DeferredTaxJournalEntry entry);
}

class DeferredTaxLocalDataSourceImpl implements DeferredTaxLocalDataSource {
  DeferredTaxLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  /// Default allowance applied to outstanding receivables for the doubtful
  /// debt provision heuristic (provisions are deductible for tax only upon
  /// actual write-off).
  static const double _provisionRate = 0.05;

  @override
  Future<List<TaxBaseComparison>> loadAssetComparisons(
    String companyId,
    DateTime asOfDate,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.assets,
      where: "company_id = ? AND status != 'disposed'",
      whereArgs: <Object?>[companyId],
      orderBy: 'asset_code ASC',
    );
    return <TaxBaseComparison>[
      for (final Map<String, Object?> row in rows)
        _assetComparison(_assetRowFromMap(row), asOfDate),
    ];
  }

  @override
  Future<List<TaxBaseComparison>> loadProvisionComparisons(
    String companyId,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) AS total '
      'FROM ${DatabaseTables.documents} '
      'WHERE company_id = ? AND status = ?',
      <Object?>[companyId, 'completed'],
    );
    final double receivables = rows.isEmpty ? 0 : _doubleValue(rows.first['total']);
    final double provision = receivables * _provisionRate;
    if (provision <= 0.000001) {
      return const <TaxBaseComparison>[];
    }
    return <TaxBaseComparison>[
      TaxBaseComparison(
        name: 'Doubtful Debt Provision',
        nature: BalanceSheetNature.liability,
        accountingValue: provision,
        taxBase: 0,
      ),
    ];
  }

  @override
  Future<DeferredTaxCalculationModel?> getLatestCalculation(
    String companyId,
    int year,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.deferredTaxCalculations,
      where: 'company_id = ? AND period_year = ?',
      whereArgs: <Object?>[companyId, year],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DeferredTaxCalculationModel.fromMap(rows.first);
  }

  @override
  Future<List<TemporaryDifferenceModel>> getDifferences(
    String calculationId,
  ) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.temporaryDifferences,
      where: 'calculation_id = ?',
      whereArgs: <Object?>[calculationId],
      orderBy: 'deferred_amount DESC',
    );
    return rows.map(TemporaryDifferenceModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> replaceCalculation(
    DeferredTaxCalculationModel calculation,
  ) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.deferredTaxCalculations,
      calculation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> replaceDifferences(
    String calculationId,
    List<TemporaryDifferenceModel> items,
  ) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      await transaction.delete(
        DatabaseTables.temporaryDifferences,
        where: 'calculation_id = ?',
        whereArgs: <Object?>[calculationId],
      );
      for (final TemporaryDifferenceModel item in items) {
        await transaction.insert(
          DatabaseTables.temporaryDifferences,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> markCalculationPosted(String calculationId) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.deferredTaxCalculations,
      <String, Object?>{'is_posted': 1},
      where: 'id = ?',
      whereArgs: <Object?>[calculationId],
    );
  }

  @override
  Future<void> writeJournalEntry(DeferredTaxJournalEntry entry) async {
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
        'source_type': 'deferred_tax',
        'source_id': entry.sourceId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  static AssetComparisonRow _assetRowFromMap(Map<String, Object?> map) {
    return AssetComparisonRow(
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'machinery',
      purchaseDate:
          DateTime.tryParse(map['purchase_date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      purchasePrice: _doubleValue(map['purchase_price']),
      salvageValue: _doubleValue(map['salvage_value']),
      bookValue: _doubleValue(map['book_value']),
    );
  }

  static TaxBaseComparison _assetComparison(
    AssetComparisonRow row,
    DateTime asOfDate,
  ) {
    final double taxBase = _taxCarryingBase(row, asOfDate);
    return TaxBaseComparison(
      name: row.name,
      nature: BalanceSheetNature.asset,
      accountingValue: row.bookValue,
      taxBase: taxBase,
    );
  }

  /// Tax carrying value = cost − tax accumulated depreciation, where tax
  /// depreciation follows the Tax Code declining/normative annual rates.
  static double _taxCarryingBase(AssetComparisonRow row, DateTime asOfDate) {
    final double depreciableBase = row.purchasePrice - row.salvageValue;
    if (depreciableBase <= 0.000001) {
      return row.salvageValue;
    }
    final double annualRate = _normativeRateFor(row.category);
    final int totalDays = asOfDate.difference(row.purchaseDate).inDays;
    final int daysHeld = totalDays < 0 ? 0 : totalDays;
    final double yearsHeld = daysHeld / 365.0;
    final double taxDepreciation = row.purchasePrice * annualRate * yearsHeld;
    final double accumulated = taxDepreciation > depreciableBase
        ? depreciableBase
        : taxDepreciation;
    return row.purchasePrice - accumulated;
  }

  static double _normativeRateFor(String category) {
    return switch (category.trim().toLowerCase()) {
      'buildings' => 0.07,
      'machinery' => 0.20,
      'vehicles' => 0.25,
      'computers' => 0.25,
      'intangible' => 0.20,
      _ => 0.20,
    };
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
