import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/vector_math.dart';
import '../../domain/entities/tax_rule_entity.dart';

/// SQLite representation of a tax rule and its optional embedding vector.
class TaxRuleModel extends TaxRuleEntity {
  const TaxRuleModel({
    required super.id,
    required super.articleCode,
    required super.title,
    required super.content,
    required super.category,
    super.embedding,
  });

  factory TaxRuleModel.fromSqflite(Map<String, Object?> row) {
    final String description = _readString(row['description']);
    final String content = _readString(
      row['content'],
      fallback: description,
    );
    return TaxRuleModel(
      id: _requiredString(row['id'], 'id'),
      articleCode: _requiredString(row['article_code'], 'article_code'),
      title: _requiredString(row['title'], 'title'),
      content: content,
      category: _readString(row['category'], fallback: 'tax'),
      embedding: decodeStoredEmbedding(row['embedding_vector']),
    );
  }

  factory TaxRuleModel.fromEntity(TaxRuleEntity entity) {
    return TaxRuleModel(
      id: entity.id,
      articleCode: entity.articleCode,
      title: entity.title,
      content: entity.content,
      category: entity.category,
      embedding: entity.embedding ??
          localTextEmbedding('${entity.articleCode} ${entity.title} ${entity.content}'),
    );
  }

  Map<String, Object?> toSqflite() {
    return <String, Object?>{
      'id': id,
      'article_code': articleCode,
      'title': title,
      // Keep the legacy description column populated for existing readers.
      'description': content,
      'content': content,
      'category': category,
      'embedding_vector': embedding == null
          ? null
          : Uint8List.fromList(utf8.encode(encodeVector(embedding!))),
    };
  }
}

/// Reads vectors written as JSON text, UTF-8 SQLite blobs, or numeric lists.
List<double>? decodeStoredEmbedding(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return decodeVector(raw);
  }
  if (raw is Uint8List || raw is List<int>) {
    try {
      return decodeVector(utf8.decode(raw as List<int>));
    } on FormatException {
      return null;
    }
  }
  if (raw is Iterable<Object?>) {
    final List<double> values = <double>[];
    for (final Object? value in raw) {
      if (value is! num || !value.toDouble().isFinite) {
        return null;
      }
      values.add(value.toDouble());
    }
    return values.isEmpty ? null : values;
  }
  return null;
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Tax rule is missing $field.');
}

String _readString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}
