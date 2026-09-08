import 'package:equatable/equatable.dart';

import '../../domain/entities/dividend_distribution_entity.dart';
import '../../domain/entities/intercompany_loan_entity.dart';

abstract class IntercompanyEvent extends Equatable {
  const IntercompanyEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadIntercompanyAgreementsEvent extends IntercompanyEvent {
  const LoadIntercompanyAgreementsEvent();
}

class CreateLoanAgreementEvent extends IntercompanyEvent {
  const CreateLoanAgreementEvent(this.loan);

  final IntercompanyLoanEntity loan;

  @override
  List<Object?> get props => <Object?>[loan];
}

class RunMonthlyInterestAccrualEvent extends IntercompanyEvent {
  const RunMonthlyInterestAccrualEvent({
    this.days = 30,
  });

  final int days;

  @override
  List<Object?> get props => <Object?>[days];
}

class DeclareDividendEvent extends IntercompanyEvent {
  const DeclareDividendEvent(this.dividend);

  final DividendDistributionEntity dividend;

  @override
  List<Object?> get props => <Object?>[dividend];
}
