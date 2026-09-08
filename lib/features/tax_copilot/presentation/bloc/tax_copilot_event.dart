import 'package:equatable/equatable.dart';

/// User intents handled by [TaxCopilotBloc].
abstract class TaxCopilotEvent extends Equatable {
  const TaxCopilotEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class AskTaxQuestionEvent extends TaxCopilotEvent {
  const AskTaxQuestionEvent(this.question, this.companyId);

  final String question;
  final String companyId;

  @override
  List<Object?> get props => <Object?>[question, companyId];
}

class LoadTaxHistoryEvent extends TaxCopilotEvent {
  const LoadTaxHistoryEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class ClearChatHistoryEvent extends TaxCopilotEvent {
  const ClearChatHistoryEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}
