import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/dividend_distribution_entity.dart';
import '../../domain/entities/intercompany_loan_entity.dart';
import '../../domain/repositories/intercompany_repository.dart';
import '../../domain/services/intercompany_engine.dart';
import 'intercompany_event.dart';
import 'intercompany_state.dart';

/// Coordinates intercompany loans, accruals, and dividends.
class IntercompanyBloc extends Bloc<IntercompanyEvent, IntercompanyState> {
  IntercompanyBloc({required IntercompanyRepository repository})
      : _repository = repository,
        super(const IntercompanyInitial()) {
    on<LoadIntercompanyAgreementsEvent>(_onLoad);
    on<CreateLoanAgreementEvent>(_onCreateLoan);
    on<RunMonthlyInterestAccrualEvent>(_onAccrue);
    on<DeclareDividendEvent>(_onDeclareDividend);
  }

  final IntercompanyRepository _repository;

  Future<void> _onLoad(
    LoadIntercompanyAgreementsEvent event,
    Emitter<IntercompanyState> emit,
  ) async {
    emit(const IntercompanyLoading());
    final Either<Failure, List<IntercompanyLoanEntity>> loansResult =
        await _repository.getLoans();
    final Either<Failure, List<DividendDistributionEntity>> dividendsResult =
        await _repository.getDividends();

    final Failure? loansFailure = loansResult.fold(
      (Failure failure) => failure,
      (List<IntercompanyLoanEntity> _) => null,
    );
    if (loansFailure != null) {
      emit(IntercompanyError(loansFailure.message));
      return;
    }
    final Failure? dividendsFailure = dividendsResult.fold(
      (Failure failure) => failure,
      (List<DividendDistributionEntity> _) => null,
    );
    if (dividendsFailure != null) {
      emit(IntercompanyError(dividendsFailure.message));
      return;
    }

    emit(
      AgreementsLoaded(
        loans: loansResult.fold(
          (Failure _) => const <IntercompanyLoanEntity>[],
          (List<IntercompanyLoanEntity> value) => value,
        ),
        dividends: dividendsResult.fold(
          (Failure _) => const <DividendDistributionEntity>[],
          (List<DividendDistributionEntity> value) => value,
        ),
      ),
    );
  }

  Future<void> _onCreateLoan(
    CreateLoanAgreementEvent event,
    Emitter<IntercompanyState> emit,
  ) async {
    final Either<Failure, IntercompanyLoanEntity> result =
        await _repository.createLoan(event.loan);
    await result.fold(
      (Failure failure) async => emit(IntercompanyError(failure.message)),
      (IntercompanyLoanEntity created) async {
        await _reload(emit);
      },
    );
  }

  Future<void> _onAccrue(
    RunMonthlyInterestAccrualEvent event,
    Emitter<IntercompanyState> emit,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime periodEnd = DateTime(now.year, now.month, now.day);
    final DateTime periodStart =
        periodEnd.subtract(Duration(days: event.days));
    final Either<Failure, List<JournalEntryPlan>> result =
        await _repository.runMonthlyInterestAccrual(
      periodStart: periodStart,
      periodEnd: periodEnd,
      requestedByCompanyId: '',
    );
    await result.fold(
      (Failure failure) async => emit(IntercompanyError(failure.message)),
      (List<JournalEntryPlan> plans) async {
        final Either<Failure, List<IntercompanyLoanEntity>> loansResult =
            await _repository.getLoans();
        final Either<Failure, List<DividendDistributionEntity>> dividendsResult =
            await _repository.getDividends();
        emit(
          AccrualExecutionSuccess(
            plans: plans,
            loans: loansResult.fold(
              (Failure _) => const <IntercompanyLoanEntity>[],
              (List<IntercompanyLoanEntity> value) => value,
            ),
            dividends: dividendsResult.fold(
              (Failure _) => const <DividendDistributionEntity>[],
              (List<DividendDistributionEntity> value) => value,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDeclareDividend(
    DeclareDividendEvent event,
    Emitter<IntercompanyState> emit,
  ) async {
    final Either<Failure, DividendDistributionEntity> result =
        await _repository.declareDividend(event.dividend);
    await result.fold(
      (Failure failure) async => emit(IntercompanyError(failure.message)),
      (DividendDistributionEntity declared) async {
        await _repository.postDividendJournals(declared.id);
        await _reload(emit);
      },
    );
  }

  Future<void> _reload(Emitter<IntercompanyState> emit) async {
    final Either<Failure, List<IntercompanyLoanEntity>> loansResult =
        await _repository.getLoans();
    final Either<Failure, List<DividendDistributionEntity>> dividendsResult =
        await _repository.getDividends();
    emit(
      AgreementsLoaded(
        loans: loansResult.fold(
          (Failure _) => const <IntercompanyLoanEntity>[],
          (List<IntercompanyLoanEntity> value) => value,
        ),
        dividends: dividendsResult.fold(
          (Failure _) => const <DividendDistributionEntity>[],
          (List<DividendDistributionEntity> value) => value,
        ),
      ),
    );
  }
}
