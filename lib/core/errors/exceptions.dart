/// Base exception for data-source errors.
abstract class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class ServerException extends AppException {
  const ServerException({
    String message = 'The server returned an error.',
    this.statusCode,
    Object? cause,
  }) : super(message, cause: cause);

  final int? statusCode;
}

class CacheException extends AppException {
  const CacheException({
    String message = 'The requested data was not available in the cache.',
    Object? cause,
  }) : super(message, cause: cause);
}

class NetworkException extends AppException {
  const NetworkException({
    String message = 'A network connection is unavailable.',
    Object? cause,
  }) : super(message, cause: cause);
}

class ParsingException extends AppException {
  const ParsingException({
    String message = 'The response could not be parsed.',
    Object? cause,
  }) : super(message, cause: cause);
}
