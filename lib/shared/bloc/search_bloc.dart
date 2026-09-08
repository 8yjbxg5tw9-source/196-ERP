import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/search/domain/entities/search_result_entity.dart';
import '../../features/search/domain/repositories/search_repository.dart';

/// Global-search intents dispatched from the command palette and filter UI.
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class ExecuteGlobalSearchEvent extends SearchEvent {
  const ExecuteGlobalSearchEvent(this.query, {this.limit = 20});

  final String query;
  final int limit;

  @override
  List<Object?> get props => <Object?>[query, limit];
}

class SelectSearchResultEvent extends SearchEvent {
  const SelectSearchResultEvent(this.result);

  final SearchResultEntity result;

  @override
  List<Object?> get props => <Object?>[result];
}

class ApplyFiltersEvent extends SearchEvent {
  const ApplyFiltersEvent(this.filters);

  final Map<String, dynamic> filters;

  @override
  List<Object?> get props => <Object?>[filters];
}

/// Global-search UI state.
abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => const <Object?>[];
}

class SearchInitial extends SearchState {
  const SearchInitial();
}

class SearchLoading extends SearchState {
  const SearchLoading(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

class SearchResultsLoaded extends SearchState {
  const SearchResultsLoaded({
    required this.results,
    required this.query,
    this.selectedResult,
  });

  final List<SearchResultEntity> results;
  final String query;
  final SearchResultEntity? selectedResult;

  @override
  List<Object?> get props => <Object?>[results, query, selectedResult];
}

class SearchEmpty extends SearchState {
  const SearchEmpty(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// Coordinates FTS5-backed global search for the command palette.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({required SearchRepository repository})
      : _repository = repository,
        super(const SearchInitial()) {
    on<ExecuteGlobalSearchEvent>(_onExecuteSearch);
    on<SelectSearchResultEvent>(_onSelectResult);
    on<ApplyFiltersEvent>(_onApplyFilters);
  }

  final SearchRepository _repository;

  Future<void> _onExecuteSearch(
    ExecuteGlobalSearchEvent event,
    Emitter<SearchState> emit,
  ) async {
    final String query = event.query.trim();
    emit(SearchLoading(query));
    final result = await _repository.globalSearch(query, limit: event.limit);
    result.fold(
      (failure) => emit(SearchEmpty(query)),
      (List<SearchResultEntity> results) {
        if (results.isEmpty) {
          emit(SearchEmpty(query));
        } else {
          emit(SearchResultsLoaded(results: results, query: query));
        }
      },
    );
  }

  void _onSelectResult(
    SelectSearchResultEvent event,
    Emitter<SearchState> emit,
  ) {
    // Selection is consumed by the command palette listener for navigation;
    // the last chosen result is surfaced so the state stays inspectable.
    final SearchState current = state;
    if (current is SearchResultsLoaded) {
      emit(
        SearchResultsLoaded(
          results: current.results,
          query: current.query,
          selectedResult: event.result,
        ),
      );
    }
  }

  void _onApplyFilters(
    ApplyFiltersEvent event,
    Emitter<SearchState> emit,
  ) {
    // Filter criteria are applied by the owning feature BLoCs (for example
    // ReconciliationFilter); this keeps the global state contract explicit.
    final SearchState current = state;
    if (current is SearchResultsLoaded) {
      emit(
        SearchResultsLoaded(
          results: current.results,
          query: current.query,
          selectedResult: current.selectedResult,
        ),
      );
    }
  }
}
