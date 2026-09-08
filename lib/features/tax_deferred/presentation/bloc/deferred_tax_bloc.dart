import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/deferred_tax_calculation_entity.dart';
import '../../domain/entities/deferred_tax_journal_entry.dart';
import '../../domain/entities/tax_base_comparison.dart';
import '../../domain/repositories/deferred_tax_repository.dart';
import '../../domain/services/deferred_tax_engine.dart';
import 'deferred_tax_event.dart';
import 'deferred_tax_state.dart';

/// Coordinates tax-base comparison loading, IAS 12 calculation, and
/// period-end journal posting for the deferred tax workspace.
class DeferredTaxBloc extends Bloc<DeferredTaxEvent, DeferredTaxState> {
  DeferredTaxBloc({required DeferredTaxRepository repository})
      : _repository = repository,
        super(const DeferredTaxInitial()) {
    on<FetchTaxBaseComparisonEvent>(_onFetch);
    on<CalculateDeferredTaxEvent>(_onCalculate);
    on<PostDeferredTaxJournalEvent>(_onPost);
    on<AddManualComparisonEvent>(_onAddComparison);
    on<RemoveManualComparisonEvent>(_onRemoveComparison);
  }

  final DeferredTaxRepository _repository;

  final List<TaxBaseComparison> _manualComparisons = <TaxBaseComparison>[];
  DeferredTaxJournalEntry? _pendingJournal;

  Future<void> _onFetch(
    FetchTaxBaseComparisonEvent event,
    Emitter<DeferredTaxState> emit,
  ) async {
    emit(const DeferredTaxLoading());
    final result = await _repository.fetchTaxBaseComparisons(
      event.companyId,
      event.year,
    );
    await result.fold(
      (failure) async => emit(DeferredTaxError(failure.message)),
      (List<TaxBaseComparison> comparisons) async {
        final priorResult = await _repository.getLatestCalculation(
          event.companyId,
          event.year - 1,
        );
        final double priorNet = priorResult.fold(
          (_) => 0,
          (DeferredTaxCalculationEntity? value) =>
              value?.netDeferredTaxPosition ?? 0,
        );
        emit(
          DeferredTaxComparisonsLoaded(
            comparisons: <TaxBaseComparison>[
              ...comparisons,
              ..._manualComparisons,
            ],
            year: event.year,
            priorYearNetPosition: priorNet,
            accountingNetProfit: 0,
          ),
        );
      },
    );
  }

  Future<void> _onAddComparison(
    AddManualComparisonEvent event,
    Emitter<DeferredTaxState> emit,
  ) async {
    _manualComparisons.add(event.comparison);
    final DeferredTaxState current = state;
    if (current is DeferredTaxComparisonsLoaded) {
      emit(
        DeferredTaxComparisonsLoaded(
          comparisons: <TaxBaseComparison>[
            ...current.comparisons,
            event.comparison,
          ],
          year: current.year,
          priorYearNetPosition: current.priorYearNetPosition,
          accountingNetProfit: current.accountingNetProfit,
        ),
      );
    }
  }

  Future<void> _onRemoveComparison(
    RemoveManualComparisonEvent event,
    Emitter<DeferredTaxState> emit,
  ) async {
    _manualComparisons.removeWhere(
      (TaxBaseComparison comparison) => comparison.name == event.name,
    );
    final DeferredTaxState current = state;
    if (current is DeferredTaxComparisonsLoaded) {
      emit(
        DeferredTaxComparisonsLoaded(
          comparisons: current.comparisons
              .where((TaxBaseComparison comparison) =>
                  comparison.name != event.name)
              .toList(growable: false),
          year: current.year,
          priorYearNetPosition: current.priorYearNetPosition,
          accountingNetProfit: current.accountingNetProfit,
        ),
      );
    }
  }

  Future<void> _onCalculate(
    CalculateDeferredTaxEvent event,
    Emitter<DeferredTaxState> emit,
  ) async {
    emit(const DeferredTaxLoading());
    final result = await _repository.calculate(
      companyId: event.companyId,
      year: event.year,
      taxRate: event.taxRate,
      manualComparisons: List<TaxBaseComparison>.unmodifiable(
        _manualComparisons,
      ),
    );
    await result.fold(
      (failure) async => emit(DeferredTaxError(failure.message)),
      (DeferredTaxComputation computation) async {
        _pendingJournal = computation.journal;
        emit(
          DeferredTaxCalculated(
            calculation: computation.calculation,
            items: computation.items,
          ),
        );
      },
    );
  }

  Future<void> _onPost(
    PostDeferredTaxJournalEvent event,
    Emitter<DeferredTaxState> emit,
  ) async {
    final DeferredTaxState current = state;
    final DeferredTaxJournalEntry? journal = _pendingJournal;
    if (current is! DeferredTaxCalculated ||
        journal == null ||
        current.calculation.isPosted) {
      emit(const DeferredTaxError(
        'There is no pending deferred tax movement to post.',
      ));
      return;
    }
    emit(const DeferredTaxLoading());
    final result = await _repository.postJournal(
      calculation: current.calculation,
      journal: journal,
    );
    await result.fold(
      (failure) async => emit(DeferredTaxError(failure.message)),
      (DeferredTaxCalculationEntity posted) async {
        _pendingJournal = null;
        emit(DeferredTaxPostedSuccess(posted));
      },
    );
  }
}
