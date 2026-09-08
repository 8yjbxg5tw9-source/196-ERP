import 'package:equatable/equatable.dart';

import 'entity_type.dart';

/// A normalized global-search request handed to the FTS5 engine.
class SearchQueryEntity extends Equatable {
  const SearchQueryEntity({
    required this.query,
    this.filters,
    this.limit = 25,
  });

  /// Raw keyword / VÖEN / amount text typed by the user.
  final String query;

  /// Optional entity-dimension whitelist; `null` searches every dimension.
  final List<EntityType>? filters;

  /// Maximum number of results to return.
  final int limit;

  bool get hasQuery => query.trim().isNotEmpty;

  @override
  List<Object?> get props => <Object?>[query, filters, limit];
}
