import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/deferred_tax_calculation_entity.dart';
import '../entities/deferred_tax_journal_entry.dart';
import '../entities/tax_base_comparison.dart';
import '../entities/temporary_difference_entity.dart';
import '../services/deferred_tax_engine.dart';

/// Boundary for the IAS 12 deferred tax engine.
abstract interface class DeferredTaxRepository {
  /// Loads the book-vs-tax comparisons for a company (asset register and
  /// provision heuristics) without running the calculation.
  Future<Either<Failure, List<TaxBaseComparison>>> fetchTaxBaseComparisons(
    String companyId,
    int year,
  );

  /// Runs the deferred tax computation, persists the calculation and its
  /// itemized differences, and returns the full bundle.
  Future<Either<Failure, DeferredTaxComputation>> calculate({
    required String companyId,
    required int year,
    required double taxRate,
    List<TaxBaseComparison> manualComparisons = const <TaxBaseComparison>[],
  });

  /// Posts the period-end net movement journal to the general ledger and
  /// marks the calculation as posted.
  Future<Either<Failure, DeferredTaxCalculationEntity>> postJournal({
    required DeferredTaxCalculationEntity calculation,
    required DeferredTaxJournalEntry journal,
  });

  /// Returns the most recent calculation for a company and fiscal year, if
  /// one has been stored.
  Future<Either<Failure, DeferredTaxCalculationEntity?>> getLatestCalculation(
    String companyId,
    int year,
  );

  /// Returns the itemized differences stored under a calculation.
  Future<Either<Failure, List<TemporaryDifferenceEntity>>> getDifferences(
    String calculationId,
  );
}
