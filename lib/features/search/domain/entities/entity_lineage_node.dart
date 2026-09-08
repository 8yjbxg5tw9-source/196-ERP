import 'package:equatable/equatable.dart';

import 'entity_type.dart';

/// One node in the deep entity lineage graph.
///
/// Nodes are connected with [childNodeIds] and [parentNodeIds] so the inspector
/// can render a directed acyclic graph tracing a record's full lifecycle, e.g.
/// `Purchase Order → Received Invoice (OCR) → Bank Payment → GL Entry`.
class EntityLineageNode extends Equatable {
  const EntityLineageNode({
    required this.id,
    required this.nodeType,
    required this.description,
    required this.amount,
    required this.status,
    required this.timestamp,
    required this.entityType,
    this.childNodeIds = const <String>[],
    this.parentNodeIds = const <String>[],
    this.rawMetadata = const <String, Object?>{},
  });

  final String id;

  /// Stable document reference label, e.g. `PO-2026-001`, `INV-882`,
  /// `BANK-TXN-104`, or `GL-ENTRY-992`.
  final String nodeType;

  final String description;
  final double amount;
  final String status;
  final DateTime timestamp;

  /// Which financial dimension this node belongs to (used for navigation).
  final EntityType entityType;

  final List<String> childNodeIds;
  final List<String> parentNodeIds;

  /// Raw source-row metadata shown by the inspector's JSON viewer.
  final Map<String, Object?> rawMetadata;

  EntityLineageNode copyWith({
    List<String>? childNodeIds,
    List<String>? parentNodeIds,
    Map<String, Object?>? rawMetadata,
  }) {
    return EntityLineageNode(
      id: id,
      nodeType: nodeType,
      description: description,
      amount: amount,
      status: status,
      timestamp: timestamp,
      entityType: entityType,
      childNodeIds: childNodeIds ?? this.childNodeIds,
      parentNodeIds: parentNodeIds ?? this.parentNodeIds,
      rawMetadata: rawMetadata ?? this.rawMetadata,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        nodeType,
        description,
        amount,
        status,
        timestamp,
        entityType,
        childNodeIds,
        parentNodeIds,
        rawMetadata,
      ];
}

/// The assembled lineage DAG for one entity: the root node plus every node in
/// the graph (linked through [EntityLineageNode.childNodeIds]).
class EntityLineageGraph extends Equatable {
  const EntityLineageGraph({required this.root, required this.nodes});

  final EntityLineageNode root;
  final List<EntityLineageNode> nodes;

  @override
  List<Object?> get props => <Object?>[root, nodes];
}
