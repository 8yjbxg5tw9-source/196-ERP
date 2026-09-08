import 'package:equatable/equatable.dart';

import '../../domain/entities/dividend_distribution_entity.dart';
import '../../domain/entities/intercompany_loan_entity.dart';
import '../../domain/services/intercompany_engine.dart';

abstract class IntercompanyState extends Equatable {
  const IntercompanyState();

  @override
  List<Object?> get props => const <Object?>[];
}

class IntercompanyInitial extends IntercompanyState {
  const IntercompanyInitial();
}

class IntercompanyLoading extends IntercompanyState {
  const IntercompanyLoading();
}

class AgreementsLoaded extends IntercompanyState {
  const AgreementsLoaded({
    required this.loans,
    required this.dividends,
  });

  final List<IntercompanyLoanEntity> loans;
  final List<DividendDistributionEntity> dividends;

  @override
  List<Object?> get props => <Object?>[loans, dividends];
}

class AccrualExecutionSuccess extends IntercompanyState {
  const AccrualExecutionSuccess({
    required this.plans,
    this.loans = const <IntercompanyLoanEntity>[],
    this.dividends = const <DividendDistributionEntity>[],
  });

  final List<JournalEntryPlan> plans;
  final List<IntercompanyLoanEntity> loans;
  final List<DividendDistributionEntity> dividends;

  int get journalLineCount => plans.length;

  @override
  List<Object?> get props => <Object?>[plans, loans, dividends];
}

class IntercompanyError extends IntercompanyState {
  const IntercompanyError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
