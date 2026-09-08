import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

/// A domain-safe error that can cross data, domain, and presentation layers.
abstract class Failure extends Equatable {
  const Failure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  List<Object?> get props => <Object?>[message, cause];
}

class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'A server error occurred.',
    this.statusCode,
    Object? cause,
  }) : super(message: message, cause: cause);

  final int? statusCode;

  @override
  List<Object?> get props => <Object?>[message, statusCode, cause];
}

class CacheFailure extends Failure {
  const CacheFailure({
    String message = 'A cache error occurred.',
    Object? cause,
  }) : super(message: message, cause: cause);
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    String message = 'A network connection is unavailable.',
    Object? cause,
  }) : super(message: message, cause: cause);
}

class ParsingFailure extends Failure {
  const ParsingFailure({
    String message = 'The response could not be parsed.',
    Object? cause,
  }) : super(message: message, cause: cause);
}

/// Standard result type for use cases and repository contracts.
typedef Result<T> = Either<Failure, T>;
