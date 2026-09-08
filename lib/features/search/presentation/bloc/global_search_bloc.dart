import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entity_lineage_node.dart';
import '../../domain/entities/search_query_entity.dart';
import '../../domain/entities/search_result_item_entity.dart';
import '../../domain/repositories/global_search_repository.dart';
import 'global_search_event.dart';
import 'global_search_state.dart';

/// Coordinates FTS5-backed global search and entity lineage tracing.
class GlobalSearchBloc extends Bloc<GlobalSearchEvent, GlobalSearchState> {
  GlobalSearchBloc({required GlobalSearchRepository repository})
      : _repository = repository,
        super(const GlobalSearchInitial()) {
    on<ExecuteGlobalQueryEvent>(_onExecuteQuery);
    on<FetchEntityLineageEvent>(_onFetchLineage);
  }

  final GlobalSearchRepository _repository;

  Future<void> _onExecuteQuery(
    ExecuteGlobalQueryEvent event,
    Emitter<GlobalSearchState> emit,
  ) async {
    final String query = event.query.trim();
    if (query.isEmpty) {
      emit(const GlobalSearchInitial());
      return;
    }

    emit(GlobalSearchLoading(query));
    final result = await _repository.executeQuery(
      SearchQueryEntity(query: query, filters: event.filters),
    );
    result.fold(
      (failure) => emit(GlobalSearchError(failure.message)),
      (List<SearchResultItemEntity> results) {
        emit(GlobalSearchResultsLoaded(results: results, query: query));
      },
    );
  }

  Future<void> _onFetchLineage(
    FetchEntityLineageEvent event,
    Emitter<GlobalSearchState> emit,
  ) async {
    emit(GlobalSearchLoading(''));
    final result = await _repository.fetchLineage(
      entityId: event.entityId,
      type: event.type,
    );
    result.fold(
      (failure) => emit(GlobalSearchError(failure.message)),
      (EntityLineageGraph graph) {
        emit(
          EntityLineageLoaded(
            rootNode: graph.root,
            nodes: graph.nodes,
          ),
        );
      },
    );
  }
}
