import 'dart:convert';
import 'dart:math' as math;

/// Returns the cosine similarity between two vectors.
///
/// Vectors with different dimensions, empty vectors, non-finite values, or a
/// zero magnitude are treated as having no similarity. This keeps malformed
/// locally stored embeddings from affecting a ranked result set.
double cosineSimilarity(List<double> first, List<double> second) {
  if (first.isEmpty || first.length != second.length) {
    return 0;
  }

  double dotProduct = 0;
  double firstMagnitudeSquared = 0;
  double secondMagnitudeSquared = 0;
  for (int index = 0; index < first.length; index++) {
    final double firstValue = first[index];
    final double secondValue = second[index];
    if (!firstValue.isFinite || !secondValue.isFinite) {
      return 0;
    }
    dotProduct += firstValue * secondValue;
    firstMagnitudeSquared += firstValue * firstValue;
    secondMagnitudeSquared += secondValue * secondValue;
  }

  if (!dotProduct.isFinite ||
      !firstMagnitudeSquared.isFinite ||
      !secondMagnitudeSquared.isFinite ||
      firstMagnitudeSquared == 0 ||
      secondMagnitudeSquared == 0) {
    return 0;
  }

  final double denominator =
      math.sqrt(firstMagnitudeSquared) * math.sqrt(secondMagnitudeSquared);
  if (!denominator.isFinite || denominator == 0) {
    return 0;
  }
  return dotProduct / denominator;
}

/// Named aliases make the utility convenient from both functional and class-
/// oriented callers.
double calculateCosineSimilarity(List<double> first, List<double> second) {
  return cosineSimilarity(first, second);
}

abstract final class VectorMath {
  static double cosineSimilarity(List<double> first, List<double> second) {
    return calculateCosineSimilarity(first, second);
  }
}

/// Encodes an embedding in a stable JSON representation suitable for SQLite.
String encodeVector(List<double> vector) {
  return jsonEncode(vector);
}

/// Decodes a JSON or comma-separated vector supplied by an embedding client.
List<double>? decodeVector(String encoded) {
  final String value = encoded.trim();
  if (value.isEmpty) {
    return null;
  }

  final String body = value.startsWith('[') && value.endsWith(']')
      ? value.substring(1, value.length - 1)
      : value;
  if (body.trim().isEmpty) {
    return null;
  }

  final List<double> vector = <double>[];
  for (final String part in body.split(',')) {
    final double? parsed = double.tryParse(part.trim());
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    vector.add(parsed);
  }
  return vector.isEmpty ? null : vector;
}

/// Creates a deterministic local fallback embedding for offline development.
///
/// This is intentionally not a replacement for a semantic embedding model.
/// It lets a locally indexed corpus remain searchable when an OpenAI or Ollama
/// embedding endpoint is not configured, while preserving the same vector
/// dimension for indexing and querying.
List<double> localTextEmbedding(
  String text, {
  int dimensions = 128,
}) {
  if (dimensions <= 0) {
    throw ArgumentError.value(dimensions, 'dimensions', 'Must be positive.');
  }

  final List<double> vector = List<double>.filled(dimensions, 0);
  final List<String> tokens = text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((String token) => token.replaceAll(RegExp(r'[^\w.-]'), ''))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);

  for (final String token in tokens) {
    _addHashedToken(vector, token);
    for (int index = 0; index < token.length - 1; index++) {
      _addHashedToken(vector, '${token[index]}${token[index + 1]}');
    }
  }
  return vector;
}

void _addHashedToken(List<double> vector, String token) {
  final int hash = _stableHash(token);
  final int index = hash % vector.length;
  vector[index] += (hash & 1) == 0 ? 1 : -1;
}

int _stableHash(String value) {
  int hash = 0x811c9dc5;
  for (final int codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
