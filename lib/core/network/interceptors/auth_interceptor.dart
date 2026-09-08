import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../storage/secure_storage_service.dart';

/// Adds credentials and safe client metadata to outgoing API requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);

  final SecureStorageService _secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final String? token = await _secureStorage.read(
        SecureStorageKeys.authorizationToken,
      );
      final String? normalizedToken = token?.trim();
      if (normalizedToken != null && normalizedToken.isNotEmpty) {
        options.headers.putIfAbsent(
          'Authorization',
          () => _asBearerToken(normalizedToken),
        );
      }

      final String? apiKey = await _secureStorage.read(
        SecureStorageKeys.localAiApiKey,
      );
      final String? normalizedApiKey = apiKey?.trim();
      if (normalizedApiKey != null && normalizedApiKey.isNotEmpty) {
        options.headers.putIfAbsent('X-API-Key', () => normalizedApiKey);
      }

      options.headers.putIfAbsent(
        'X-FinAI-Client',
        () => 'finai_studio',
      );
      options.headers.putIfAbsent(
        'X-Client-Platform',
        () => _platformName,
      );
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
          message: 'Unable to load secure request credentials.',
        ),
      );
    }
  }

  String _asBearerToken(String token) {
    if (token.toLowerCase().startsWith('bearer ')) {
      return token;
    }
    return 'Bearer $token';
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
    return 'unknown';
  }
}
