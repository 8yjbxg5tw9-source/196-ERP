import 'package:equatable/equatable.dart';

/// A persisted, traceable question and answer from the tax copilot.
class TaxQueryEntity extends Equatable {
  const TaxQueryEntity({
    required this.id,
    this.companyId = '',
    required this.question,
    required this.answer,
    required this.citedArticles,
    required this.timestamp,
  });

  final String id;
  final String companyId;
  final String question;
  final String answer;
  final List<String> citedArticles;
  final DateTime timestamp;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        question,
        answer,
        citedArticles,
        timestamp,
      ];
}
