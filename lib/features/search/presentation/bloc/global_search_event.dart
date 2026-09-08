import 'package:equatable/equatable.dart';

import '../../domain/entities/entity_type.dart';

/// Intents dispatched to the unified global-search / lineage engine.
abstract class GlobalSearchEvent extends Equatable {
  const GlobalSearchEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Runs a full-text query across every indexed financial dimension.
class ExecuteGlobalQueryEvent extends GlobalSearchEvent {
  const ExecuteGlobalQueryEvent(this.query, {this.filters});

  final String query;

  /// Optional entity-dimension whitelist; `null` searches every dimension.
  final List<EntityType>? filters;

  @override
  List<Object?> get props => <Object?>[query, filters];
}

/// Traces the complete document lifecycle for a single record.
class FetchEntityLineageEvent extends GlobalSearchEvent {
  const FetchEntityLineageEvent({required this.entityId, required this.type});

  final String entityId;
  final EntityType type;

  @override
  List<Object?> get props => <Object?>[entityId, type];
}
