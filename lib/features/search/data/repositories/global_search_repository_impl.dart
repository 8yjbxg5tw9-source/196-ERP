import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/entity_lineage_node.dart';
import '../../domain/entities/entity_type.dart';
import '../../domain/entities/search_query_entity.dart';
import '../../domain/entities/search_result_item_entity.dart';
import '../../domain/repositories/global_search_repository.dart';
import '../datasources/global_fts_data_source.dart';

/// FTS5-backed implementation of the unified global search & lineage contract.
class GlobalSearchRepositoryImpl implements GlobalSearchRepository {
  GlobalSearchRepositoryImpl(this._dataSource);

  final GlobalFtsDataSource _dataSource;

  @override
  Future<Result<List<SearchResultItemEntity>>> executeQuery(
    SearchQueryEntity query,
  ) async {
    try {
      final List<SearchResultItemEntity> results =
          await _dataSource.search(query);
      return Right<Failure, List<SearchResultItemEntity>>(results);
    } on DatabaseException catch (error) {
      return Left<Failure, List<SearchResultItemEntity>>(
        DatabaseFailure(
          message: 'Global search could not be executed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<SearchResultItemEntity>>(
        CacheFailure(
          message: 'Global search failed locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<EntityLineageGraph>> fetchLineage({
    required String entityId,
    required EntityType type,
  }) async {
    try {
      final EntityLineageGraph graph = await _dataSource.lineage(
        entityId: entityId,
        type: type,
      );
      return Right<Failure, EntityLineageGraph>(graph);
    } on StateError catch (error) {
      return Left<Failure, EntityLineageGraph>(
        NotFoundFailure(
          message: 'The requested record could not be found.',
          cause: error,
        ),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, EntityLineageGraph>(
        DatabaseFailure(
          message: 'Entity lineage could not be traced.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, EntityLineageGraph>(
        CacheFailure(
          message: 'Entity lineage could not be assembled locally.',
          cause: error,
        ),
      );
    }
  }
}
