import 'package:equatable/equatable.dart';

import '../../domain/entities/tax_base_comparison.dart';

abstract class DeferredTaxEvent extends Equatable {
  const DeferredTaxEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Loads the book-vs-tax comparisons for a company and fiscal year.
class FetchTaxBaseComparisonEvent extends DeferredTaxEvent {
  const FetchTaxBaseComparisonEvent({
    required this.companyId,
    required this.year,
  });

  final String companyId;
  final int year;

  @override
  List<Object?> get props => <Object?>[companyId, year];
}

/// Runs the deferred tax computation at the given statutory rate.
class CalculateDeferredTaxEvent extends DeferredTaxEvent {
  const CalculateDeferredTaxEvent({
    required this.companyId,
    required this.year,
    required this.taxRate,
  });

  final String companyId;
  final int year;
  final double taxRate;

  @override
  List<Object?> get props => <Object?>[companyId, year, taxRate];
}

/// Posts the period-end net deferred tax movement to the general ledger.
class PostDeferredTaxJournalEvent extends DeferredTaxEvent {
  const PostDeferredTaxJournalEvent();
}

/// Adds a manual book-vs-tax comparison line to the workspace grid.
class AddManualComparisonEvent extends DeferredTaxEvent {
  const AddManualComparisonEvent(this.comparison);

  final TaxBaseComparison comparison;

  @override
  List<Object?> get props => <Object?>[comparison];
}

/// Removes a manual comparison line by its display name.
class RemoveManualComparisonEvent extends DeferredTaxEvent {
  const RemoveManualComparisonEvent(this.name);

  final String name;

  @override
  List<Object?> get props => <Object?>[name];
}
