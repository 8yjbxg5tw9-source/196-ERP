import 'package:equatable/equatable.dart';

/// The logical buckets a global-search result can belong to.
enum SearchCategory { document, company, transaction, taxRule }

extension SearchCategoryLabel on SearchCategory {
  /// Human-readable group header shown in the command palette.
  String get label => switch (this) {
        SearchCategory.document => 'Invoices',
        SearchCategory.company => 'Companies',
        SearchCategory.transaction => 'Transactions',
        SearchCategory.taxRule => 'Tax & Legal',
      };
}

/// One lightweight, categorized row returned by the global search engine.
class SearchResultEntity extends Equatable {
  const SearchResultEntity({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    this.entityId,
    this.companyId,
  });

  /// Stable row identifier (unique within a category).
  final String id;

  final SearchCategory category;
  final String title;
  final String subtitle;

  /// The underlying entity id used for navigation: a document id, company id,
  /// transaction id, or tax-rule article code.
  final String? entityId;

  /// Workspace scope when the result belongs to a specific company.
  final String? companyId;

  @override
  List<Object?> get props =>
      <Object?>[id, category, title, subtitle, entityId, companyId];
}
