import '../../../../../core/errors/failures.dart';
import '../entities/entity_lineage_node.dart';
import '../entities/entity_type.dart';
import '../entities/search_query_entity.dart';
import '../entities/search_result_item_entity.dart';

/// Unified FTS5-backed search and entity lineage contract.
abstract interface class GlobalSearchRepository {
  /// Full-text search across every indexed financial dimension. An empty
  /// query returns no rows (the palette shows quick actions instead).
  Future<Result<List<SearchResultItemEntity>>> executeQuery(
    SearchQueryEntity query,
  );

  /// Traces the complete document lifecycle for [entityId] of [type] and
  /// returns the assembled lineage DAG (root node plus all linked nodes).
  Future<Result<EntityLineageGraph>> fetchLineage({
    required String entityId,
    required EntityType type,
  });
}
