import 'dart:async';

import 'package:dio/dio.dart';

/// Retries transient gateway, timeout, and connection failures with
/// exponential backoff. A request is retried at most [maxRetries] times after
/// its initial attempt.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 250),
  });

  static const String _retryCountKey = '_finai_retry_count';

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions requestOptions = error.requestOptions;
    final Object? rawAttempt = requestOptions.extra[_retryCountKey];
    final int attempt = rawAttempt is int ? rawAttempt : 0;

    if (!_shouldRetry(error) || attempt >= maxRetries) {
      handler.next(error);
      return;
    }

    final int nextAttempt = attempt + 1;
    requestOptions.extra = <String, dynamic>{
      ...requestOptions.extra,
      _retryCountKey: nextAttempt,
    };
    final Duration delay = _backoffFor(nextAttempt);

    await Future<void>.delayed(delay);

    try {
      final Response<dynamic> response = await _dio.fetch<dynamic>(
        requestOptions,
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      // The same interceptor sees the retried request, so its retry counter is
      // preserved in RequestOptions.extra and the final error is normalized by
      // the remaining interceptor chain.
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException error) {
    if (!_isReplayable(error.requestOptions)) {
      return false;
    }

    final int? statusCode = error.response?.statusCode;
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }

    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.transformTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.error is TimeoutException;
  }

  bool _isReplayable(RequestOptions options) {
    // Stream bodies may not be safely replayable after the first attempt.
    // JSON and primitive request bodies are safe to retry.
    if (options.data is Stream<Object?>) {
      return false;
    }

    return options.method.isNotEmpty;
  }

  Duration _backoffFor(int attempt) {
    final int multiplier = 1 << (attempt - 1);
    return Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
  }
}
