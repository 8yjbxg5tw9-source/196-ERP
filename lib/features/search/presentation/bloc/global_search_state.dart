import 'package:equatable/equatable.dart';

import '../../domain/entities/entity_lineage_node.dart';
import '../../domain/entities/search_result_item_entity.dart';

/// UI state for the unified global-search / lineage engine.
abstract class GlobalSearchState extends Equatable {
  const GlobalSearchState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Idle state: the palette shows quick actions rather than results.
class GlobalSearchInitial extends GlobalSearchState {
  const GlobalSearchInitial();
}

/// A query is in flight (or a lineage graph is being traced).
class GlobalSearchLoading extends GlobalSearchState {
  const GlobalSearchLoading(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// Ranked FTS5 results for the current query.
class GlobalSearchResultsLoaded extends GlobalSearchState {
  const GlobalSearchResultsLoaded({
    required this.results,
    required this.query,
  });

  final List<SearchResultItemEntity> results;
  final String query;

  @override
  List<Object?> get props => <Object?>[results, query];
}

/// The lineage graph for a single record has been assembled.
class EntityLineageLoaded extends GlobalSearchState {
  const EntityLineageLoaded({
    required this.rootNode,
    required this.nodes,
  });

  final EntityLineageNode rootNode;
  final List<EntityLineageNode> nodes;

  @override
  List<Object?> get props => <Object?>[rootNode, nodes];
}

/// A query or lineage trace failed.
class GlobalSearchError extends GlobalSearchState {
  const GlobalSearchError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
