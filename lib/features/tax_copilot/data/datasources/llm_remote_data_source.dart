import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/vector_math.dart';
import '../../domain/entities/tax_rule_entity.dart';

/// Supported completion backends for the copilot.
enum LlmProvider {
  openAi,
  anthropic,
  ollama,
}

/// A normalized completion response independent of the selected provider.
class LlmAnswer {
  const LlmAnswer({
    required this.answer,
    required this.citedArticles,
  });

  final String answer;
  final List<String> citedArticles;
}

/// Remote/model boundary used by the RAG repository.
abstract interface class LlmRemoteDataSource {
  Future<List<double>> createEmbedding(String text);

  Future<LlmAnswer> answerQuestion({
    required String question,
    required List<TaxRuleEntity> retrievedRules,
  });
}

/// Calls OpenAI, Anthropic, or a local Ollama server and normalizes responses.
///
/// API keys are read from [SecureStorageService]. If no provider is configured
/// or a configured endpoint is unavailable, the deterministic local fallback
/// keeps the app usable offline and never invents a citation outside the
/// retrieved corpus.
class LlmRemoteDataSourceImpl implements LlmRemoteDataSource {
  LlmRemoteDataSourceImpl(
    this._apiClient,
    this._secureStorage, {
    LlmProvider? provider,
    this.openAiModel = 'gpt-4o',
    this.anthropicModel = 'claude-3-5-sonnet-20241022',
    this.ollamaModel = 'llama3.1',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.anthropicBaseUrl = 'https://api.anthropic.com/v1',
    this.ollamaBaseUrl = 'http://127.0.0.1:11434/api',
    this.allowOfflineFallback = true,
  }) : provider = provider ?? _providerFromEnvironment();

  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final LlmProvider provider;
  final String openAiModel;
  final String anthropicModel;
  final String ollamaModel;
  final String openAiBaseUrl;
  final String anthropicBaseUrl;
  final String ollamaBaseUrl;
  final bool allowOfflineFallback;

  static LlmProvider _providerFromEnvironment() {
    const String configured = String.fromEnvironment(
      'LLM_PROVIDER',
      defaultValue: 'openai',
    );
    return _providerFromName(configured) ?? LlmProvider.openAi;
  }

  static LlmProvider? _providerFromName(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'anthropic':
      case 'claude':
        return LlmProvider.anthropic;
      case 'ollama':
      case 'local':
        return LlmProvider.ollama;
      case 'openai':
        return LlmProvider.openAi;
      default:
        return null;
    }
  }

  Future<LlmProvider> _configuredProvider() async {
    try {
      final String? configured = await _secureStorage.read(
        SecureStorageKeys.llmProvider,
      );
      return _providerFromName(configured) ?? provider;
    } on Object {
      return provider;
    }
  }

  /// Builds the exact system instruction used by every provider.
  static String buildSystemPrompt(List<TaxRuleEntity> retrievedRules) {
    final String context = retrievedRules.isEmpty
        ? 'No matching indexed tax articles were retrieved.'
        : retrievedRules
            .map(
              (TaxRuleEntity rule) =>
                  'Article ${rule.articleCode}: ${rule.title}\n'
                  'Category: ${rule.category}\n${rule.content}',
            )
            .join('\n\n');

    return '''You are an expert Tax & Legal AI Assistant for enterprise accountants.
Answer the user's question accurately based strictly on the provided Tax Code Context below.
Always cite exact article numbers (e.g., Article 105.1).

CONTEXT:
$context''';
  }

  @override
  Future<List<double>> createEmbedding(String text) async {
    final String question = text.trim();
    if (question.isEmpty) {
      throw const ValidationFailure(message: 'An embedding requires text.');
    }

    final LlmProvider selectedProvider = await _configuredProvider();
    if (selectedProvider == LlmProvider.anthropic ||
        (kIsWeb && selectedProvider == LlmProvider.ollama)) {
      return localTextEmbedding(question);
    }

    try {
      final String? apiKey = await _apiKey(selectedProvider);
      if (selectedProvider == LlmProvider.openAi &&
          (apiKey == null || apiKey.trim().isEmpty)) {
        return localTextEmbedding(question);
      }

      final Object? response = selectedProvider == LlmProvider.openAi
          ? await _post(
              Uri.parse('${_withoutTrailingSlash(openAiBaseUrl)}/embeddings'),
              <String, Object?>{
                'model': 'text-embedding-3-small',
                'input': question,
              },
              _headers(selectedProvider, apiKey),
            )
          : await _post(
              Uri.parse('${_withoutTrailingSlash(ollamaBaseUrl)}/embeddings'),
              <String, Object?>{
                'model': ollamaModel,
                'prompt': question,
              },
              const <String, String>{'Content-Type': 'application/json'},
            );
      final List<double>? vector = _embeddingFromResponse(response);
      if (vector == null || vector.isEmpty) {
        throw const ParsingFailure(
          message: 'The embedding provider returned no vector.',
        );
      }
      return vector;
    } on Failure {
      if (allowOfflineFallback) {
        return localTextEmbedding(question);
      }
      rethrow;
    } on Object catch (error) {
      if (allowOfflineFallback) {
        return localTextEmbedding(question);
      }
      throw ServerFailure(
        message: 'The embedding provider could not be reached.',
        cause: error,
      );
    }
  }

  @override
  Future<LlmAnswer> answerQuestion({
    required String question,
    required List<TaxRuleEntity> retrievedRules,
  }) async {
    final String normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw const ValidationFailure(message: 'Ask a tax or legal question.');
    }
    final LlmProvider selectedProvider = await _configuredProvider();
    if (kIsWeb && selectedProvider == LlmProvider.ollama) {
      return _offlineAnswer(retrievedRules);
    }

    try {
      final String? apiKey = await _apiKey(selectedProvider);
      if (selectedProvider != LlmProvider.ollama &&
          (apiKey == null || apiKey.trim().isEmpty)) {
        return _offlineAnswer(retrievedRules);
      }

      final String prompt = buildSystemPrompt(retrievedRules);
      final Object? response;
      switch (selectedProvider) {
        case LlmProvider.openAi:
          response = await _post(
            Uri.parse(
              '${_withoutTrailingSlash(openAiBaseUrl)}/chat/completions',
            ),
            <String, Object?>{
              'model': openAiModel,
              'temperature': 0.1,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'system', 'content': prompt},
                <String, String>{
                  'role': 'user',
                  'content': normalizedQuestion,
                },
              ],
            },
            _headers(selectedProvider, apiKey),
          );
        case LlmProvider.anthropic:
          response = await _post(
            Uri.parse(
              '${_withoutTrailingSlash(anthropicBaseUrl)}/messages',
            ),
            <String, Object?>{
              'model': anthropicModel,
              'max_tokens': 1200,
              'temperature': 0.1,
              'system': prompt,
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'user',
                  'content': normalizedQuestion,
                },
              ],
            },
            <String, String>{
              ..._headers(selectedProvider, apiKey),
              'anthropic-version': '2023-06-01',
            },
          );
        case LlmProvider.ollama:
          response = await _post(
            Uri.parse('${_withoutTrailingSlash(ollamaBaseUrl)}/chat'),
            <String, Object?>{
              'model': ollamaModel,
              'stream': false,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'system', 'content': prompt},
                <String, String>{
                  'role': 'user',
                  'content': normalizedQuestion,
                },
              ],
            },
            const <String, String>{'Content-Type': 'application/json'},
          );
      }

      final String? answer = _answerFromResponse(response);
      if (answer == null || answer.trim().isEmpty) {
        throw const ParsingFailure(
          message: 'The language model returned an empty answer.',
        );
      }
      final String normalizedAnswer = answer.trim();
      final List<String> citations = _citations(
        normalizedAnswer,
        retrievedRules,
      );
      return LlmAnswer(
        answer: _withExplicitCitations(normalizedAnswer, citations),
        citedArticles: citations,
      );
    } on Failure {
      if (allowOfflineFallback) {
        return _offlineAnswer(retrievedRules);
      }
      rethrow;
    } on Object catch (error) {
      if (allowOfflineFallback) {
        return _offlineAnswer(retrievedRules);
      }
      throw ServerFailure(
        message: 'The language model could not be reached.',
        cause: error,
      );
    }
  }

  Future<String?> _apiKey(LlmProvider selectedProvider) async {
    switch (selectedProvider) {
      case LlmProvider.openAi:
        return _secureStorage.read(SecureStorageKeys.openAiApiKey);
      case LlmProvider.anthropic:
        return _secureStorage.read(SecureStorageKeys.anthropicApiKey);
      case LlmProvider.ollama:
        return null;
    }
  }

  Future<Object?> _post(
    Uri endpoint,
    Object payload,
    Map<String, String> headers,
  ) async {
    final Response<Object?> response = await _apiClient.post<Object?>(
      endpoint.toString(),
      data: payload,
      options: Options(headers: headers),
    );
    final int? statusCode = response.statusCode;
    if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
      throw ServerFailure(
        message: 'The language model rejected the request ($statusCode).',
        cause: response.data,
      );
    }
    return response.data;
  }

  Map<String, String> _headers(
    LlmProvider selectedProvider,
    String? apiKey,
  ) {
    switch (selectedProvider) {
      case LlmProvider.openAi:
        return <String, String>{
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey.isNotEmpty)
            'Authorization': 'Bearer $apiKey',
        };
      case LlmProvider.anthropic:
        return <String, String>{
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey.isNotEmpty) 'x-api-key': apiKey,
        };
      case LlmProvider.ollama:
        return const <String, String>{'Content-Type': 'application/json'};
    }
  }

  static List<double>? _embeddingFromResponse(Object? response) {
    final Map<String, Object?>? map = _asMap(response);
    if (map == null) {
      return null;
    }

    final Object? data = map['data'];
    if (data is Iterable<Object?> && data.isNotEmpty) {
      final Map<String, Object?>? first = _asMap(data.first);
      final List<double>? embedding = _doubleList(first?['embedding']);
      if (embedding != null) {
        return embedding;
      }
    }
    return _doubleList(map['embedding']);
  }

  static String? _answerFromResponse(Object? response) {
    final Map<String, Object?>? map = _asMap(response);
    if (map == null) {
      return null;
    }

    final Object? choices = map['choices'];
    if (choices is Iterable<Object?> && choices.isNotEmpty) {
      final Map<String, Object?>? choice = _asMap(choices.first);
      final Map<String, Object?>? message = _asMap(choice?['message']);
      final String? content = _textFromContent(message?['content']);
      if (content != null) {
        return content;
      }
      return _textFromContent(choice?['text']);
    }

    final Map<String, Object?>? message = _asMap(map['message']);
    final String? ollamaContent = _textFromContent(message?['content']);
    if (ollamaContent != null) {
      return ollamaContent;
    }

    final Object? content = map['content'];
    if (content is Iterable<Object?>) {
      return _textFromContent(content);
    }
    return _textFromContent(content);
  }

  static String? _textFromContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is Iterable<Object?>) {
      final StringBuffer text = StringBuffer();
      for (final Object? part in content) {
        final Map<String, Object?>? map = _asMap(part);
        final Object? value = map?['text'] ?? map?['content'];
        if (value is String) {
          text.write(value);
        }
      }
      final String result = text.toString();
      return result.isEmpty ? null : result;
    }
    return null;
  }

  static List<double>? _doubleList(Object? value) {
    if (value is! Iterable<Object?>) {
      return null;
    }
    final List<double> result = <double>[];
    for (final Object? item in value) {
      if (item is! num || !item.toDouble().isFinite) {
        return null;
      }
      result.add(item.toDouble());
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    return null;
  }

  static List<String> _citations(
    String answer,
    List<TaxRuleEntity> rules,
  ) {
    final List<String> matched = rules
        .where(
          (TaxRuleEntity rule) =>
              answer.contains(rule.articleCode) ||
              answer.contains('Article ${rule.articleCode}'),
        )
        .map((TaxRuleEntity rule) => rule.articleCode)
        .toList(growable: false);
    if (matched.isNotEmpty) {
      return matched;
    }
    return rules
        .map((TaxRuleEntity rule) => rule.articleCode)
        .toList(growable: false);
  }

  static String _withExplicitCitations(
    String answer,
    List<String> citations,
  ) {
    if (citations.isEmpty ||
        citations.any(
          (String article) =>
              answer.contains('Article $article') ||
              answer.contains('article $article'),
        )) {
      return answer;
    }

    final String sourceList = citations
        .map((String article) => 'Article $article')
        .join(', ');
    return '$answer\n\nSources: $sourceList';
  }

  static LlmAnswer _offlineAnswer(List<TaxRuleEntity> rules) {
    if (rules.isEmpty) {
      return const LlmAnswer(
        answer:
            'No matching indexed tax articles were found. Add the relevant '
            'jurisdictional rules to the local corpus before relying on this answer.',
        citedArticles: <String>[],
      );
    }

    final StringBuffer answer = StringBuffer(
      'The configured language model is unavailable, so this response is '
      'limited to the retrieved local context:\n\n',
    );
    for (final TaxRuleEntity rule in rules.take(3)) {
      answer
        ..writeln('Article ${rule.articleCode} — ${rule.title}')
        ..writeln(rule.content)
        ..writeln();
    }
    answer.write(
      'Verify the current jurisdictional wording with a qualified tax adviser '
      'before filing or posting an accounting entry.',
    );
    return LlmAnswer(
      answer: answer.toString(),
      citedArticles: rules
          .map((TaxRuleEntity rule) => rule.articleCode)
          .toList(growable: false),
    );
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
  }
}
