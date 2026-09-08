import 'package:equatable/equatable.dart';

import 'entity_type.dart';

/// One ranked row returned by the global FTS5 search engine.
class SearchResultItemEntity extends Equatable {
  const SearchResultItemEntity({
    required this.id,
    required this.entityType,
    required this.title,
    required this.subtitle,
    this.voen,
    this.amount,
    this.timestamp,
    this.score = 0,
    this.deepLinkRoute = '',
  });

  /// The underlying entity UUID (the FTS `entity_id` column).
  final String id;

  final EntityType entityType;
  final String title;
  final String subtitle;

  /// VÖEN / TIN when the entity carries one (invoice vendor, counterparty).
  final String? voen;

  /// Display amount in AZN when the entity carries a monetary value.
  final double? amount;

  /// Source-record timestamp when the underlying table exposes one.
  final DateTime? timestamp;

  /// Relevance score (higher is better), derived from the FTS5 `bm25()` rank.
  final double score;

  /// Deep-link route (`finai://<entityType>/<id>`) for instant navigation.
  final String deepLinkRoute;

  /// Builds the canonical deep-link route for this result.
  static String routeFor(EntityType type, String id) =>
      'finai://${type.name}/$id';

  SearchResultItemEntity copyWith({double? score, String? subtitle}) {
    return SearchResultItemEntity(
      id: id,
      entityType: entityType,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      voen: voen,
      amount: amount,
      timestamp: timestamp,
      score: score ?? this.score,
      deepLinkRoute: deepLinkRoute,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        entityType,
        title,
        subtitle,
        voen,
        amount,
        timestamp,
        score,
        deepLinkRoute,
      ];
}
