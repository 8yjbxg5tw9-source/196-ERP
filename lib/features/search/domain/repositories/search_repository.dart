import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/search_result_entity.dart';

/// Unified global search contract spanning invoices, companies, transactions,
/// and tax/legal articles.
abstract interface class SearchRepository {
  /// Full-text search across all indexed sources. An empty [query] returns the
  /// most recently completed documents instead.
  Future<Either<Failure, List<SearchResultEntity>>> globalSearch(
    String query, {
    int limit = 20,
  });

  /// The newest approved documents, used to prime the command palette.
  Future<Either<Failure, List<SearchResultEntity>>> recentDocuments({
    String? companyId,
    int limit = 5,
  });
}
