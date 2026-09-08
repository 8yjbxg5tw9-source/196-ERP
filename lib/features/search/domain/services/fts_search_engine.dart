import '../entities/entity_lineage_node.dart';

/// Pure search & lineage logic for the global FTS5 engine.
///
/// The SQL that reads the virtual table lives in the data source; this engine
/// owns the deterministic pieces that are worth testing in isolation: FTS5
/// MATCH expression formatting, `bm25()` rank-to-score conversion, and
/// directed-acyclic-graph assembly for the lineage inspector.
class FtsSearchEngine {
  const FtsSearchEngine();

  /// Formats raw user input as a safe FTS5 MATCH expression.
  ///
  /// Each whitespace token is wrapped as a quoted prefix phrase (`"token"*`)
  /// so input is treated literally (operator characters such as `-`, `AND`,
  /// or parentheses cannot change query semantics) while `*` still enables
  /// sub-millisecond prefix matching. Embedded quotes are escaped by doubling.
  String ftsMatchExpression(String raw) {
    final String escaped = raw.replaceAll('"', '""');
    final List<String> tokens = escaped
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return '';
    }
    return tokens.map((String token) => '"$token"*').join(' ');
  }

  /// Converts an FTS5 `bm25()` rank into a descending relevance score in
  /// `(0, 1]`, where `1.0` means "perfectly relevant" and the score decays as
  /// the rank grows.
  double relevanceScore(Object? rank) {
    final double value = rank is num ? rank.toDouble() : 0;
    final double clamped = value.isFinite && value > 0 ? value : 0;
    return 1.0 / (1.0 + clamped);
  }

  /// Assembles a lineage DAG from a flat list of linked nodes.
  ///
  /// Nodes are de-duplicated, dangling child/parent references are dropped,
  /// and the graph is topologically ordered (parents before children) so the
  /// drawer can render the lifecycle left-to-right without back-edges. The
  /// returned [EntityLineageGraph.root] is the node with [rootId] when present
  /// (the entity being inspected), falling back to the graph's source node.
  ///
  /// Returns `null` when [nodes] is empty.
  EntityLineageGraph? assembleLineage(
    List<EntityLineageNode> nodes, {
    String? rootId,
  }) {
    if (nodes.isEmpty) {
      return null;
    }

    final Map<String, EntityLineageNode> byId = <String, EntityLineageNode>{
      for (final EntityLineageNode node in nodes) node.id: node,
    };

    final List<EntityLineageNode> normalized = <EntityLineageNode>[
      for (final EntityLineageNode node in nodes)
        node.copyWith(
          childNodeIds: <String>[
            for (final String child in node.childNodeIds)
              if (byId.containsKey(child)) child,
          ],
          parentNodeIds: <String>[
            for (final String parent in node.parentNodeIds)
              if (byId.containsKey(parent)) parent,
          ],
        ),
    ];

    final List<EntityLineageNode> ordered = _topologicalOrder(normalized);
    final EntityLineageNode root = rootId != null && byId.containsKey(rootId)
        ? byId[rootId]!
        : ordered.firstWhere(
            (EntityLineageNode node) => node.parentNodeIds.isEmpty,
            orElse: () => ordered.first,
          );

    return EntityLineageGraph(root: root, nodes: ordered);
  }

  /// Kahn's algorithm over child links, with a stable timestamp tie-break.
  static List<EntityLineageNode> _topologicalOrder(
    List<EntityLineageNode> nodes,
  ) {
    final Map<String, EntityLineageNode> byId = <String, EntityLineageNode>{
      for (final EntityLineageNode node in nodes) node.id: node,
    };

    final Map<String, int> indegree = <String, int>{
      for (final EntityLineageNode node in nodes) node.id: 0,
    };
    for (final EntityLineageNode node in nodes) {
      for (final String child in node.childNodeIds) {
        if (byId.containsKey(child)) {
          indegree[child] = (indegree[child] ?? 0) + 1;
        }
      }
    }

    final List<EntityLineageNode> queue = <EntityLineageNode>[
      for (final EntityLineageNode node in nodes)
        if ((indegree[node.id] ?? 0) == 0) node,
    ]..sort(
        (EntityLineageNode a, EntityLineageNode b) =>
            a.timestamp.compareTo(b.timestamp),
      );

    final List<EntityLineageNode> ordered = <EntityLineageNode>[];
    while (queue.isNotEmpty) {
      final EntityLineageNode node = queue.removeAt(0);
      ordered.add(node);
      for (final String child in node.childNodeIds) {
        final EntityLineageNode? childNode = byId[child];
        if (childNode == null) {
          continue;
        }
        final int remaining = (indegree[child] ?? 0) - 1;
        indegree[child] = remaining;
        if (remaining == 0) {
          queue.add(childNode);
        }
      }
    }

    // A cycle (or missing nodes) can leave a few entries unvisited; append them
    // so no node is silently dropped from the visualization.
    if (ordered.length < nodes.length) {
      for (final EntityLineageNode node in nodes) {
        if (!ordered.contains(node)) {
          ordered.add(node);
        }
      }
    }

    return ordered;
  }
}
