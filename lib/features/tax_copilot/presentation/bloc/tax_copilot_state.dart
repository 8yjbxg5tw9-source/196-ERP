import 'package:equatable/equatable.dart';

import '../../domain/entities/tax_query_entity.dart';

abstract class TaxCopilotState extends Equatable {
  const TaxCopilotState({
    this.history = const <TaxQueryEntity>[],
    this.currentQuery,
  });

  final List<TaxQueryEntity> history;
  final TaxQueryEntity? currentQuery;

  @override
  List<Object?> get props => <Object?>[history, currentQuery];
}

class TaxCopilotInitial extends TaxCopilotState {
  const TaxCopilotInitial({
    super.history,
    super.currentQuery,
  });
}

class TaxCopilotThinking extends TaxCopilotState {
  const TaxCopilotThinking({
    super.history,
    super.currentQuery,
  });
}

class TaxCopilotAnswerReceived extends TaxCopilotState {
  const TaxCopilotAnswerReceived(
    this.query, {
    List<TaxQueryEntity> history = const <TaxQueryEntity>[],
  }) : super(history: history, currentQuery: query);

  final TaxQueryEntity query;

  @override
  List<Object?> get props => <Object?>[...super.props, query];
}

class TaxCopilotFailure extends TaxCopilotState {
  const TaxCopilotFailure(
    this.message, {
    super.history,
    super.currentQuery,
  });

  final String message;

  @override
  List<Object?> get props => <Object?>[...super.props, message];
}
