import 'dart:convert';

import '../../domain/entities/tax_query_entity.dart';

/// SQLite representation of a company-scoped copilot query.
class TaxQueryModel extends TaxQueryEntity {
  const TaxQueryModel({
    required super.id,
    required super.companyId,
    required super.question,
    required super.answer,
    required super.citedArticles,
    required super.timestamp,
  });

  factory TaxQueryModel.fromSqflite(Map<String, Object?> row) {
    return TaxQueryModel(
      id: _requiredString(row['id'], 'id'),
      companyId: _requiredString(row['company_id'], 'company_id'),
      question: _requiredString(row['question'], 'question'),
      answer: _requiredString(row['answer'], 'answer'),
      citedArticles: _readCitations(row['cited_articles_json']),
      timestamp: _readDate(row['timestamp']),
    );
  }

  Map<String, Object?> toSqflite() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'question': question,
      'answer': answer,
      'cited_articles_json': jsonEncode(citedArticles),
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}

List<String> _readCitations(Object? raw) {
  Object? decoded = raw;
  if (raw is String) {
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <String>[];
    }
  }
  if (decoded is! Iterable<Object?>) {
    return const <String>[];
  }
  return decoded
      .whereType<String>()
      .where((String value) => value.trim().isNotEmpty)
      .toList(growable: false);
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Tax query is missing $field.');
}

DateTime _readDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw const FormatException('Tax query has an invalid timestamp.');
}
