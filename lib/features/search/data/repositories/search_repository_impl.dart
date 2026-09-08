import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/global_search_data_source.dart';

/// Cached-first global search over the local SQLite/FTS5 store.
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dataSource);

  final GlobalSearchDataSource _dataSource;

  @override
  Future<Either<Failure, List<SearchResultEntity>>> globalSearch(
    String query, {
    int limit = 20,
  }) async {
    try {
      final List<SearchResultEntity> results = await _dataSource.search(
        query,
        limit: limit,
      );
      return Right<Failure, List<SearchResultEntity>>(results);
    } on DatabaseException catch (error) {
      return Left<Failure, List<SearchResultEntity>>(
        DatabaseFailure(
          message: 'Global search could not be executed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<SearchResultEntity>>(
        CacheFailure(
          message: 'Global search failed locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<SearchResultEntity>>> recentDocuments({
    String? companyId,
    int limit = 5,
  }) async {
    try {
      final List<SearchResultEntity> results = await _dataSource.recentDocuments(
        companyId: companyId,
        limit: limit,
      );
      return Right<Failure, List<SearchResultEntity>>(results);
    } on DatabaseException catch (error) {
      return Left<Failure, List<SearchResultEntity>>(
        DatabaseFailure(
          message: 'Recent documents could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<SearchResultEntity>>(
        CacheFailure(
          message: 'Recent documents could not be read locally.',
          cause: error,
        ),
      );
    }
  }
}
