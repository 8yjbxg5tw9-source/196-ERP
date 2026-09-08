import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../errors/failures.dart';

/// Contract implemented by application use cases.
///
/// Every use case returns a typed [Either] so expected failures are handled
/// explicitly rather than through unchecked exceptions.
abstract class UseCase<Output, Params> {
  Future<Either<Failure, Output>> call(Params params);
}

/// Parameter object for use cases that do not require input.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
