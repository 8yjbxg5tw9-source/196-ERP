import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/failures.dart';
import '../storage/secure_storage_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_transformer_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'network_info.dart';
import 'socket_exception_helper.dart';

/// Typed, resilient boundary around Dio used by remote data sources.
class ApiClient {
  ApiClient(
    this._dio, {
    required SecureStorageService secureStorage,
    required NetworkInfo networkInfo,
    bool enableLogging = kDebugMode,
  }) : _networkInfo = networkInfo {
    _configureDefaults();
    _attachInterceptors(secureStorage, enableLogging: enableLogging);
    if (kDebugMode) {
      debugPrint(
        '[ApiClient] Dio initialized with Auth, Retry, Logging, and '
        'ErrorTransformer interceptors.',
      );
    }
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  final Dio _dio;
  final NetworkInfo _networkInfo;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return _execute<T>(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _execute<T>(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _execute<T>(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _execute<T>(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _execute<T>(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Converts an arbitrary network error into a domain failure.
  static Failure failureFromException(Object error) {
    if (error is Failure) {
      return error;
    }
    if (error is DioException) {
      return failureFromDioException(error);
    }
    if (error is TimeoutException || isSocketException(error)) {
      return NetworkFailure(cause: error);
    }
    return ServerFailure(
      message: 'An unexpected network error occurred.',
      cause: error,
    );
  }

  /// Maps HTTP and transport-level Dio failures to stable domain failures.
  static Failure failureFromDioException(DioException error) {
    final Object? normalizedError = error.error;
    if (normalizedError is Failure) {
      return normalizedError;
    }

    final int? statusCode = error.response?.statusCode;
    switch (statusCode) {
      case 401:
      case 403:
        return UnauthenticatedFailure(
          statusCode: statusCode,
          cause: error,
        );
      case 404:
        return NotFoundFailure(cause: error);
      case 422:
        return ValidationFailure(
          message: _responseMessage(error.response?.data) ??
              'The server rejected the submitted data.',
          cause: error,
        );
      case 429:
        return RateLimitExceededFailure(
          retryAfter: _retryAfter(error.response),
          cause: error,
        );
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerFailure(
            statusCode: statusCode,
            message: 'The server could not process the request.',
            cause: error,
          );
        }
    }

    if (_isTransportFailure(error)) {
      return NetworkFailure(
        message: 'The network request could not be completed.',
        cause: error,
      );
    }

    return ServerFailure(
      statusCode: statusCode,
      message: error.message ?? 'The network request failed.',
      cause: error,
    );
  }

  Future<Response<T>> _execute<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      final bool connected = await _readConnectivity();
      if (kDebugMode) {
        debugPrint('[ApiClient] Connectivity check: $connected');
      }
      if (!connected) {
        throw const NetworkFailure();
      }
      return await request();
    } on Failure {
      rethrow;
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        failureFromDioException(error),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        failureFromException(error),
        stackTrace,
      );
    }
  }

  Future<bool> _readConnectivity() async {
    try {
      return await _networkInfo.isConnected;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NetworkFailure(
          message: 'Unable to determine network connectivity.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  void _configureDefaults() {
    _dio.options
      ..connectTimeout = connectTimeout
      ..receiveTimeout = receiveTimeout
      ..sendTimeout = sendTimeout;
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.headers['Accept'] = 'application/json';
  }

  void _attachInterceptors(
    SecureStorageService secureStorage, {
    required bool enableLogging,
  }) {
    _dio.interceptors.addAll(<Interceptor>[
      AuthInterceptor(secureStorage),
      RetryInterceptor(_dio),
      LoggingInterceptor(enabled: enableLogging),
      ErrorTransformerInterceptor(
        transformer: failureFromDioException,
      ),
    ]);
  }

  static bool _isTransportFailure(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.transformTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate ||
        error.error is TimeoutException ||
        isSocketException(error.error);
  }

  static String? _responseMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      const List<String> messageKeys = <String>[
        'message',
        'detail',
        'error',
      ];
      for (final String key in messageKeys) {
        final Object? value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return null;
  }

  static Duration? _retryAfter(Response<dynamic>? response) {
    final String? value = response?.headers.value('retry-after');
    final int? seconds = value == null ? null : int.tryParse(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
