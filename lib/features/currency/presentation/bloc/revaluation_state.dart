import 'package:equatable/equatable.dart';

import '../../domain/revaluation/fx_balance_entity.dart';
import '../../domain/revaluation/fx_revaluation_entity.dart';

abstract class FxRevaluationState extends Equatable {
  const FxRevaluationState();

  @override
  List<Object?> get props => const <Object?>[];
}

class FxRevaluationInitial extends FxRevaluationState {
  const FxRevaluationInitial();
}

class FxRevaluationLoading extends FxRevaluationState {
  const FxRevaluationLoading();
}

class FxRevaluationCalculated extends FxRevaluationState {
  const FxRevaluationCalculated({
    required this.revaluation,
    required this.balances,
    this.history = const <FxRevaluationEntity>[],
  });

  final FxRevaluationEntity revaluation;
  final List<FxBalanceEntity> balances;
  final List<FxRevaluationEntity> history;

  @override
  List<Object?> get props => <Object?>[revaluation, balances, history];
}

class FxRevaluationPostedSuccess extends FxRevaluationState {
  const FxRevaluationPostedSuccess({
    required this.revaluation,
    this.balances = const <FxBalanceEntity>[],
    this.history = const <FxRevaluationEntity>[],
  });

  final FxRevaluationEntity revaluation;
  final List<FxBalanceEntity> balances;
  final List<FxRevaluationEntity> history;

  @override
  List<Object?> get props => <Object?>[revaluation, balances, history];
}

class FxRevaluationError extends FxRevaluationState {
  const FxRevaluationError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
