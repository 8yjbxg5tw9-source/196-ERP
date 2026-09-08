import 'package:equatable/equatable.dart';

/// A searchable article or compliance rule in the local legal corpus.
class TaxRuleEntity extends Equatable {
  const TaxRuleEntity({
    required this.id,
    required this.articleCode,
    required this.title,
    required this.content,
    required this.category,
    this.embedding,
  });

  final String id;
  final String articleCode;
  final String title;
  final String content;
  final String category;
  final List<double>? embedding;

  @override
  List<Object?> get props => <Object?>[
        id,
        articleCode,
        title,
        content,
        category,
        embedding,
      ];
}
