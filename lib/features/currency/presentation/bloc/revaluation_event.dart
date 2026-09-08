import 'package:equatable/equatable.dart';

import '../../domain/revaluation/fx_balance_entity.dart';

abstract class FxRevaluationEvent extends Equatable {
  const FxRevaluationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class CalculateFxRevaluationEvent extends FxRevaluationEvent {
  const CalculateFxRevaluationEvent(this.companyId, this.date);

  final String companyId;
  final DateTime date;

  @override
  List<Object?> get props => <Object?>[companyId, date];
}

class PostFxRevaluationJournalEvent extends FxRevaluationEvent {
  const PostFxRevaluationJournalEvent({this.withReversal = false});

  final bool withReversal;

  @override
  List<Object?> get props => <Object?>[withReversal];
}

class FetchFxHistoryEvent extends FxRevaluationEvent {
  const FetchFxHistoryEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class UpsertFxBalanceEvent extends FxRevaluationEvent {
  const UpsertFxBalanceEvent(this.balance);

  final FxBalanceEntity balance;

  @override
  List<Object?> get props => <Object?>[balance];
}

class PostFxReversalEvent extends FxRevaluationEvent {
  const PostFxReversalEvent();
}
