import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/dividend_distribution_entity.dart';
import '../../domain/entities/interest_schedule_entity.dart';
import '../../domain/entities/intercompany_loan_entity.dart';
import '../../domain/repositories/intercompany_repository.dart';
import '../../domain/services/intercompany_engine.dart';
import '../datasources/intercompany_local_data_source.dart';
import '../models/dividend_distribution_model.dart';
import '../models/interest_schedule_model.dart';
import '../models/intercompany_loan_model.dart';

/// SQLite-backed intercompany agreements with automatic reciprocal posting.
class IntercompanyRepositoryImpl implements IntercompanyRepository {
  IntercompanyRepositoryImpl(
    this._localDataSource, {
    IntercompanyEngine engine = const IntercompanyEngine(),
  }) : _engine = engine;

  final IntercompanyLocalDataSource _localDataSource;
  final IntercompanyEngine _engine;

  @override
  Future<Either<Failure, List<IntercompanyLoanEntity>>> getLoans() async {
    try {
      final List<IntercompanyLoanModel> loans =
          await _localDataSource.getLoans();
      return Right<Failure, List<IntercompanyLoanEntity>>(loans);
    } on DatabaseException catch (error) {
      return Left<Failure, List<IntercompanyLoanEntity>>(
        DatabaseFailure(message: 'Loans could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<IntercompanyLoanEntity>>(
        CacheFailure(message: 'Loans could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, List<DividendDistributionEntity>>> getDividends() async {
    try {
      final List<DividendDistributionModel> dividends =
          await _localDataSource.getDividends();
      return Right<Failure, List<DividendDistributionEntity>>(dividends);
    } on DatabaseException catch (error) {
      return Left<Failure, List<DividendDistributionEntity>>(
        DatabaseFailure(message: 'Dividends could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<DividendDistributionEntity>>(
        CacheFailure(message: 'Dividends could not be read locally.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, IntercompanyLoanEntity>> createLoan(
    IntercompanyLoanEntity loan,
  ) async {
    if (loan.lenderCompanyId.trim().isEmpty ||
        loan.borrowerCompanyId.trim().isEmpty) {
      return Left<Failure, IntercompanyLoanEntity>(
        const ValidationFailure(message: 'Lender and borrower are required.'),
      );
    }
    if (loan.lenderCompanyId == loan.borrowerCompanyId) {
      return Left<Failure, IntercompanyLoanEntity>(
        const ValidationFailure(
          message: 'Lender and borrower must be different entities.',
        ),
      );
    }
    if (loan.principalAmount <= 0) {
      return Left<Failure, IntercompanyLoanEntity>(
        const ValidationFailure(message: 'Principal must be greater than zero.'),
      );
    }
    if (loan.interestRate < 0) {
      return Left<Failure, IntercompanyLoanEntity>(
        const ValidationFailure(message: 'Interest rate must not be negative.'),
      );
    }
    if (!loan.maturityDate.isAfter(loan.agreementDate)) {
      return Left<Failure, IntercompanyLoanEntity>(
        const ValidationFailure(
          message: 'Maturity date must be after the agreement date.',
        ),
      );
    }

    try {
      final IntercompanyLoanModel model = IntercompanyLoanModel(
        id: loan.id.isEmpty
            ? 'loan-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : loan.id,
        lenderCompanyId: loan.lenderCompanyId,
        borrowerCompanyId: loan.borrowerCompanyId,
        principalAmount: loan.principalAmount,
        interestRate: loan.interestRate,
        agreementDate: loan.agreementDate,
        maturityDate: loan.maturityDate,
        compoundingFrequency: loan.compoundingFrequency,
        withholdingTaxRate: loan.withholdingTaxRate,
        outstandingBalance: loan.principalAmount,
        status: LoanStatus.active,
        createdAt: loan.createdAt ?? DateTime.now().toUtc(),
      );
      await _localDataSource.createLoan(model);

      final List<JournalEntryPlan> plans = _engine.loanDisbursementPlans(
        lenderCompanyId: model.lenderCompanyId,
        borrowerCompanyId: model.borrowerCompanyId,
        principal: model.principalAmount,
        date: model.agreementDate,
        sourceId: model.id,
      );
      for (final JournalEntryPlan plan in plans) {
        await _localDataSource.writeJournalEntry(plan);
      }

      return Right<Failure, IntercompanyLoanEntity>(model);
    } on DatabaseException catch (error) {
      return Left<Failure, IntercompanyLoanEntity>(
        DatabaseFailure(message: 'The loan could not be created.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, IntercompanyLoanEntity>(
        CacheFailure(message: 'The loan could not be saved.', cause: error),
      );
    }
  }

  @override
  Future<Either<Failure, List<JournalEntryPlan>>> runMonthlyInterestAccrual({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String requestedByCompanyId,
  }) async {
    if (!periodEnd.isAfter(periodStart)) {
      return Left<Failure, List<JournalEntryPlan>>(
        const ValidationFailure(
          message: 'The accrual period must end after it starts.',
        ),
      );
    }

    try {
      final List<IntercompanyLoanModel> loans =
          await _localDataSource.getLoans();
      final int days = periodEnd.difference(periodStart).inDays;
      final List<JournalEntryPlan> plans = <JournalEntryPlan>[];

      for (final IntercompanyLoanModel loan in loans) {
        if (loan.status != LoanStatus.active) {
          continue;
        }
        final InterestAccrualResult accrual = _engine.accrualFor(
          principal: loan.outstandingBalance,
          annualRate: loan.interestRate,
          days: days,
          frequency: loan.compoundingFrequency,
          withholdingTaxRate: loan.withholdingTaxRate,
        );
        final String scheduleId =
            'schedule-${DateTime.now().toUtc().microsecondsSinceEpoch}-${loan.id}';
        await _localDataSource.insertSchedule(
          InterestScheduleModel(
            id: scheduleId,
            loanId: loan.id,
            periodDate: periodEnd,
            grossInterest: accrual.grossInterest,
            withholdingTax: accrual.withholdingTax,
            netInterest: accrual.netInterest,
            isAccrued: true,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        plans.addAll(
          _engine.interestAccrualPlans(
            lenderCompanyId: loan.lenderCompanyId,
            borrowerCompanyId: loan.borrowerCompanyId,
            date: periodEnd,
            accrual: accrual,
            sourceId: scheduleId,
          ),
        );

        final IntercompanyLoanModel updated = IntercompanyLoanModel(
          id: loan.id,
          lenderCompanyId: loan.lenderCompanyId,
          borrowerCompanyId: loan.borrowerCompanyId,
          principalAmount: loan.principalAmount,
          interestRate: loan.interestRate,
          agreementDate: loan.agreementDate,
          maturityDate: loan.maturityDate,
          compoundingFrequency: loan.compoundingFrequency,
          withholdingTaxRate: loan.withholdingTaxRate,
          outstandingBalance: loan.outstandingBalance + accrual.netInterest,
          status: loan.status,
          createdAt: loan.createdAt,
        );
        await _localDataSource.updateLoan(updated);
      }

      for (final JournalEntryPlan plan in plans) {
        await _localDataSource.writeJournalEntry(plan);
      }

      return Right<Failure, List<JournalEntryPlan>>(plans);
    } on DatabaseException catch (error) {
      return Left<Failure, List<JournalEntryPlan>>(
        DatabaseFailure(
          message: 'The interest accrual could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<JournalEntryPlan>>(
        CacheFailure(message: 'The interest accrual could not be computed.'),
      );
    }
  }

  @override
  Future<Either<Failure, DividendDistributionEntity>> declareDividend(
    DividendDistributionEntity dividend,
  ) async {
    if (dividend.distributingCompanyId.trim().isEmpty ||
        dividend.recipientEntityId.trim().isEmpty) {
      return Left<Failure, DividendDistributionEntity>(
        const ValidationFailure(
          message: 'Distributor and recipient are required.',
        ),
      );
    }
    if (dividend.distributingCompanyId == dividend.recipientEntityId) {
      return Left<Failure, DividendDistributionEntity>(
        const ValidationFailure(
          message: 'Distributor and recipient must be different entities.',
        ),
      );
    }
    if (dividend.declaredAmount <= 0) {
      return Left<Failure, DividendDistributionEntity>(
        const ValidationFailure(message: 'Declared amount must be positive.'),
      );
    }

    try {
      final double tax = dividend.declaredAmount * dividend.dividendTaxRate / 100;
      final double net = dividend.declaredAmount - tax;
      final DividendDistributionModel model = DividendDistributionModel(
        id: dividend.id.isEmpty
            ? 'dividend-${DateTime.now().toUtc().microsecondsSinceEpoch}'
            : dividend.id,
        distributingCompanyId: dividend.distributingCompanyId,
        recipientEntityId: dividend.recipientEntityId,
        declaredAmount: dividend.declaredAmount,
        dividendTaxRate: dividend.dividendTaxRate,
        netDividendPaid: net,
        declarationDate: dividend.declarationDate,
        createdAt: dividend.createdAt ?? DateTime.now().toUtc(),
      );
      await _localDataSource.insertDividend(model);
      return Right<Failure, DividendDistributionEntity>(model);
    } on DatabaseException catch (error) {
      return Left<Failure, DividendDistributionEntity>(
        DatabaseFailure(message: 'The dividend could not be saved.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, DividendDistributionEntity>(
        CacheFailure(message: 'The dividend could not be declared.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<JournalEntryPlan>>> postDividendJournals(
    String dividendId,
  ) async {
    try {
      final DividendDistributionModel? dividend =
          await _localDataSource.getDividend(dividendId);
      if (dividend == null) {
        return Left<Failure, List<JournalEntryPlan>>(
          NotFoundFailure(message: 'Dividend $dividendId was not found.'),
        );
      }
      final List<JournalEntryPlan> plans = _engine.dividendPlans(
        distributingCompanyId: dividend.distributingCompanyId,
        recipientEntityId: dividend.recipientEntityId,
        declaredAmount: dividend.declaredAmount,
        withholdingTax: dividend.withholdingTax,
        netPaid: dividend.netDividendPaid,
        date: dividend.declarationDate,
        sourceId: dividend.id,
      );
      for (final JournalEntryPlan plan in plans) {
        await _localDataSource.writeJournalEntry(plan);
      }
      return Right<Failure, List<JournalEntryPlan>>(plans);
    } on DatabaseException catch (error) {
      return Left<Failure, List<JournalEntryPlan>>(
        DatabaseFailure(message: 'The dividend journals could not be posted.'),
      );
    } on Object catch (error) {
      return Left<Failure, List<JournalEntryPlan>>(
        CacheFailure(message: 'The dividend journals could not be written.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<InterestScheduleEntity>>> getSchedule(
    String loanId,
  ) async {
    try {
      final List<InterestScheduleModel> schedules =
          await _localDataSource.getSchedule(loanId);
      return Right<Failure, List<InterestScheduleEntity>>(schedules);
    } on DatabaseException catch (error) {
      return Left<Failure, List<InterestScheduleEntity>>(
        DatabaseFailure(message: 'The schedule could not be loaded.', cause: error),
      );
    } on Object catch (error) {
      return Left<Failure, List<InterestScheduleEntity>>(
        CacheFailure(message: 'The schedule could not be read locally.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> writeJournalPlans(
    List<JournalEntryPlan> plans,
  ) async {
    try {
      for (final JournalEntryPlan plan in plans) {
        await _localDataSource.writeJournalEntry(plan);
      }
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(message: 'Journal entries could not be written.'),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'Journal entries could not be written locally.'),
      );
    }
  }
}
