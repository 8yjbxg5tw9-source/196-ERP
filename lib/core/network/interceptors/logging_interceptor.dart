import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only structured request logging with recursive secret masking.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({bool? enabled, this.maxPayloadLength = 4000})
      : enabled = enabled ?? kDebugMode;

  final bool enabled;
  final int maxPayloadLength;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (enabled && kDebugMode) {
      debugPrint(
        '[Dio] → ${options.method.toUpperCase()} '
        '${_formatUri(options.uri)}',
      );
      debugPrint('[Dio]   headers: ${_format(options.headers)}');
      if (options.data != null) {
        debugPrint('[Dio]   body: ${_format(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled && kDebugMode) {
      debugPrint(
        '[Dio] ← ${response.statusCode} '
        '${response.requestOptions.method.toUpperCase()} '
        '${_formatUri(response.requestOptions.uri)}',
      );
      if (response.data != null) {
        debugPrint('[Dio]   response: ${_format(response.data)}');
      }
    }
    handler.next(response);
  }

  @override
  void onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    if (enabled && kDebugMode) {
      debugPrint(
        '[Dio] ✕ ${error.response?.statusCode ?? error.type.name} '
        '${error.requestOptions.method.toUpperCase()} '
        '${_formatUri(error.requestOptions.uri)}',
      );
      if (error.response?.data != null) {
        debugPrint(
          '[Dio]   error: ${_format(error.response?.data)}',
        );
      }
    }
    handler.next(error);
  }

  String _formatUri(Uri uri) {
    if (uri.queryParameters.isEmpty) {
      return uri.toString();
    }

    final Map<String, String> maskedQuery = <String, String>{};
    uri.queryParameters.forEach((String key, String value) {
      maskedQuery[key] = _isSensitiveKey(key)
          ? '***REDACTED***'
          : _maskString(value);
    });
    return uri.replace(queryParameters: maskedQuery).toString();
  }

  String _format(Object? payload) {
    final Object? maskedPayload = _maskPayload(payload);
    String output;
    try {
      output = const JsonEncoder.withIndent('  ').convert(maskedPayload);
    } on Object {
      output = maskedPayload.toString();
    }

    if (output.length <= maxPayloadLength) {
      return output;
    }
    return '${output.substring(0, maxPayloadLength)}…';
  }

  Object? _maskPayload(Object? payload) {
    if (payload == null) {
      return null;
    }

    if (payload is String) {
      final String trimmed = payload.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _maskPayload(jsonDecode(trimmed));
        } on FormatException {
          // Fall through to bearer/API-key masking for plain text payloads.
        }
      }
      return _maskString(payload);
    }

    if (payload is Map<Object?, Object?>) {
      final Map<String, Object?> masked = <String, Object?>{};
      payload.forEach((Object? key, Object? value) {
        final String keyString = key.toString();
        masked[keyString] = _isSensitiveKey(keyString)
            ? '***REDACTED***'
            : _maskPayload(value);
      });
      return masked;
    }

    if (payload is Iterable<Object?>) {
      return payload.map(_maskPayload).toList(growable: false);
    }

    if (payload is FormData) {
      return '<multipart payload redacted>';
    }

    return payload;
  }

  String _maskString(String value) {
    final RegExp bearerToken = RegExp(
      r'Bearer\s+[^\s,}]+',
      caseSensitive: false,
    );
    final RegExp secretAssignment = RegExp(
      r'((?:password|passwd|secret|token|authorization|api[_-]?key|'
      r'client[_-]?secret|access[_-]?token|refresh[_-]?token)\s*[:=]\s*)'
      r'[^,}\s]+',
      caseSensitive: false,
    );
    return value
        .replaceAll(bearerToken, 'Bearer ***REDACTED***')
        .replaceAllMapped(
          secretAssignment,
          (Match match) => '${match.group(1)}***REDACTED***',
        );
  }

  bool _isSensitiveKey(String key) {
    final String normalized = key
        .toLowerCase()
        .replaceAll(RegExp(r'[-\s]'), '_');
    const List<String> sensitiveNames = <String>[
      'password',
      'api_key',
      'apikey',
      'authorization',
      'bearer',
      'token',
      'secret',
      'client_secret',
      'access_token',
      'refresh_token',
      'database_encryption_key',
      'encryption_key',
      'private_key',
      'cookie',
      'set_cookie',
      'credential',
    ];

    return sensitiveNames.any(
      (String sensitiveName) => normalized.contains(sensitiveName),
    );
  }
}
