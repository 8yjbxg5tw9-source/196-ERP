import 'package:equatable/equatable.dart';

import '../../domain/entities/deferred_tax_calculation_entity.dart';
import '../../domain/entities/tax_base_comparison.dart';
import '../../domain/entities/temporary_difference_entity.dart';

abstract class DeferredTaxState extends Equatable {
  const DeferredTaxState();

  @override
  List<Object?> get props => const <Object?>[];
}

class DeferredTaxInitial extends DeferredTaxState {
  const DeferredTaxInitial();
}

class DeferredTaxLoading extends DeferredTaxState {
  const DeferredTaxLoading();
}

/// The book-vs-tax comparison grid is ready (before the calculation runs).
class DeferredTaxComparisonsLoaded extends DeferredTaxState {
  const DeferredTaxComparisonsLoaded({
    required this.comparisons,
    required this.year,
    required this.priorYearNetPosition,
    required this.accountingNetProfit,
  });

  final List<TaxBaseComparison> comparisons;
  final int year;
  final double priorYearNetPosition;
  final double accountingNetProfit;

  @override
  List<Object?> get props =>
      <Object?>[comparisons, year, priorYearNetPosition, accountingNetProfit];
}

/// A deferred tax calculation is ready, with its itemized differences.
class DeferredTaxCalculated extends DeferredTaxState {
  const DeferredTaxCalculated({
    required this.calculation,
    required this.items,
  });

  final DeferredTaxCalculationEntity calculation;
  final List<TemporaryDifferenceEntity> items;

  bool get hasMovement =>
      calculation.periodDeferredTaxExpenseBenefit.abs() > 0;

  @override
  List<Object?> get props => <Object?>[calculation, items];
}

/// The net movement journal was posted successfully.
class DeferredTaxPostedSuccess extends DeferredTaxState {
  const DeferredTaxPostedSuccess(this.calculation);

  final DeferredTaxCalculationEntity calculation;

  @override
  List<Object?> get props => <Object?>[calculation];
}

class DeferredTaxError extends DeferredTaxState {
  const DeferredTaxError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
