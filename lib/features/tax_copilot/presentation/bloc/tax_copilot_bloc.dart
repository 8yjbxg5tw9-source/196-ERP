import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tax_query_entity.dart';
import '../../domain/repositories/tax_copilot_repository.dart';
import 'tax_copilot_event.dart';
import 'tax_copilot_state.dart';

/// Coordinates copilot questions, history loading, thread selection, and
/// history clearing.
class TaxCopilotBloc extends Bloc<TaxCopilotEvent, TaxCopilotState> {
  TaxCopilotBloc({required TaxCopilotRepository repository})
      : _repository = repository,
        super(const TaxCopilotInitial()) {
    on<AskTaxQuestionEvent>(_onAskTaxQuestion);
    on<LoadTaxHistoryEvent>(_onLoadTaxHistory);
    on<ClearChatHistoryEvent>(_onClearChatHistory);
    on<StartNewChatEvent>(_onStartNewChat);
    on<SelectTaxQueryEvent>(_onSelectTaxQuery);
  }

  final TaxCopilotRepository _repository;

  Future<void> _onAskTaxQuestion(
    AskTaxQuestionEvent event,
    Emitter<TaxCopilotState> emit,
  ) async {
    final String question = event.question.trim();
    final String companyId = event.companyId.trim();
    if (question.isEmpty || companyId.isEmpty) {
      emit(
        TaxCopilotFailure(
          question.isEmpty
              ? 'Ask a tax or legal question first.'
              : 'Select a company before asking.',
          history: state.history,
          currentQuery: state.currentQuery,
        ),
      );
      return;
    }

    final TaxQueryEntity? previousQuery = state.currentQuery;
    emit(
      TaxCopilotThinking(
        history: state.history,
        currentQuery: null,
        activeQuestion: question,
      ),
    );
    final result = await _repository.askTaxCopilot(question, companyId);
    result.fold(
      (failure) => emit(
        TaxCopilotFailure(
          failure.message,
          history: state.history,
          currentQuery: previousQuery,
          activeQuestion: question,
        ),
      ),
      (TaxQueryEntity query) {
        final List<TaxQueryEntity> updatedHistory = <TaxQueryEntity>[
          query,
          ...state.history.where(
            (TaxQueryEntity item) => item.id != query.id,
          ),
        ];
        emit(
          TaxCopilotAnswerReceived(
            query,
            history: updatedHistory,
          ),
        );
      },
    );
  }

  Future<void> _onLoadTaxHistory(
    LoadTaxHistoryEvent event,
    Emitter<TaxCopilotState> emit,
  ) async {
    final String companyId = event.companyId.trim();
    if (companyId.isEmpty) {
      emit(const TaxCopilotInitial());
      return;
    }

    final result = await _repository.getQueryHistory(companyId);
    result.fold(
      (failure) => emit(
        TaxCopilotFailure(
          failure.message,
          currentQuery: state.currentQuery,
        ),
      ),
      (List<TaxQueryEntity> history) => emit(
        TaxCopilotInitial(
          history: history,
          currentQuery: history.isEmpty ? null : history.first,
        ),
      ),
    );
  }

  Future<void> _onClearChatHistory(
    ClearChatHistoryEvent event,
    Emitter<TaxCopilotState> emit,
  ) async {
    final String companyId = event.companyId.trim();
    if (companyId.isEmpty) {
      emit(const TaxCopilotInitial());
      return;
    }

    final result = await _repository.clearQueryHistory(companyId);
    result.fold(
      (failure) => emit(
        TaxCopilotFailure(
          failure.message,
          history: state.history,
          currentQuery: state.currentQuery,
        ),
      ),
      (_) => emit(const TaxCopilotInitial()),
    );
  }

  void _onStartNewChat(
    StartNewChatEvent _event,
    Emitter<TaxCopilotState> emit,
  ) {
    emit(TaxCopilotInitial(history: state.history));
  }

  void _onSelectTaxQuery(
    SelectTaxQueryEvent event,
    Emitter<TaxCopilotState> emit,
  ) {
    emit(
      TaxCopilotAnswerReceived(
        event.query,
        history: state.history,
      ),
    );
  }
}
