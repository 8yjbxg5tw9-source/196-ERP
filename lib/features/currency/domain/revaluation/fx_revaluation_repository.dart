import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import 'fx_balance_entity.dart';
import 'fx_revaluation_entity.dart';

/// Persistence + engine boundary for FX revaluation and period-end closure.
abstract interface class FxRevaluationRepository {
  Future<Either<Failure, List<FxBalanceEntity>>> getBalances(
    String companyId,
  );

  Future<Either<Failure, FxBalanceEntity>> upsertBalance(
    FxBalanceEntity balance,
  );

  /// Marks open foreign balances to market for [date], persists the run, and
  /// returns the computed revaluation (not yet posted).
  Future<Either<Failure, FxRevaluationEntity>> calculateRevaluation({
    required String companyId,
    required DateTime date,
  });

  /// Posts the revaluation journal and marks the run as posted.
  Future<Either<Failure, FxRevaluationEntity>> postRevaluation(
    FxRevaluationEntity revaluation,
  );

  /// Posts a reversing journal on the first day of the following period for
  /// an unrealized mark-to-market run.
  Future<Either<Failure, void>> postReversal(FxRevaluationEntity revaluation);

  Future<Either<Failure, List<FxRevaluationEntity>>> getHistory(
    String companyId,
  );
}
