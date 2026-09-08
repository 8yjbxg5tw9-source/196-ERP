import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dividend_distribution_entity.dart';
import '../entities/interest_schedule_entity.dart';
import '../entities/intercompany_loan_entity.dart';
import '../services/intercompany_engine.dart';

/// Persistence + engine boundary for intercompany loans and dividends.
abstract interface class IntercompanyRepository {
  Future<Either<Failure, List<IntercompanyLoanEntity>>> getLoans();

  Future<Either<Failure, List<DividendDistributionEntity>>> getDividends();

  Future<Either<Failure, IntercompanyLoanEntity>> createLoan(
    IntercompanyLoanEntity loan,
  );

  /// Computes a period's interest across all active loans, persists schedule
  /// lines, and returns the reciprocal journal plans to post.
  Future<Either<Failure, List<JournalEntryPlan>>> runMonthlyInterestAccrual({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String requestedByCompanyId,
  });

  Future<Either<Failure, DividendDistributionEntity>> declareDividend(
    DividendDistributionEntity dividend,
  );

  Future<Either<Failure, List<JournalEntryPlan>>> postDividendJournals(
    String dividendId,
  );

  Future<Either<Failure, List<InterestScheduleEntity>>> getSchedule(
    String loanId,
  );

  /// Persists journal-entry plans produced by the engine.
  Future<Either<Failure, void>> writeJournalPlans(
    List<JournalEntryPlan> plans,
  );
}
