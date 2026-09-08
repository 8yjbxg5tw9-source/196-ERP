import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/rules/reconciliation_rule_entity.dart';
import '../../domain/rules/rule_repository.dart';

/// Rule editor intents.
abstract class RulesEvent extends Equatable {
  const RulesEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadRulesEvent extends RulesEvent {
  const LoadRulesEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class CreateRuleEvent extends RulesEvent {
  const CreateRuleEvent(this.rule);

  final ReconciliationRuleEntity rule;

  @override
  List<Object?> get props => <Object?>[rule];
}

class ToggleRuleStatusEvent extends RulesEvent {
  const ToggleRuleStatusEvent(this.ruleId, this.isActive);

  final String ruleId;
  final bool isActive;

  @override
  List<Object?> get props => <Object?>[ruleId, isActive];
}

class ReorderRulesEvent extends RulesEvent {
  const ReorderRulesEvent(this.orderedRuleIds);

  final List<String> orderedRuleIds;

  @override
  List<Object?> get props => <Object?>[orderedRuleIds];
}

/// Rule editor state.
abstract class RulesState extends Equatable {
  const RulesState();

  @override
  List<Object?> get props => const <Object?>[];
}

class RulesInitial extends RulesState {
  const RulesInitial();
}

class RulesLoading extends RulesState {
  const RulesLoading();
}

class RulesLoaded extends RulesState {
  const RulesLoaded(this.rules);

  final List<ReconciliationRuleEntity> rules;

  @override
  List<Object?> get props => <Object?>[rules];
}

class RulesError extends RulesState {
  const RulesError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// Coordinates custom reconciliation rule CRUD, toggling, and reordering.
class RulesBloc extends Bloc<RulesEvent, RulesState> {
  RulesBloc({required RuleRepository repository}) : _repository = repository,
        super(const RulesInitial()) {
    on<LoadRulesEvent>(_onLoadRules);
    on<CreateRuleEvent>(_onCreateRule);
    on<ToggleRuleStatusEvent>(_onToggleRuleStatus);
    on<ReorderRulesEvent>(_onReorderRules);
  }

  final RuleRepository _repository;
  String? _companyId;

  Future<void> _onLoadRules(
    LoadRulesEvent event,
    Emitter<RulesState> emit,
  ) async {
    _companyId = event.companyId.trim();
    emit(const RulesLoading());
    final Either<Failure, List<ReconciliationRuleEntity>> result =
        await _repository.getRules(_companyId ?? '');
    result.fold(
      (Failure failure) => emit(RulesError(failure.message)),
      (List<ReconciliationRuleEntity> rules) => emit(RulesLoaded(rules)),
    );
  }

  Future<void> _onCreateRule(
    CreateRuleEvent event,
    Emitter<RulesState> emit,
  ) async {
    final String companyId = _companyId ?? event.rule.companyId;
    final ReconciliationRuleEntity rule = event.rule.copyWith(
      companyId: event.rule.companyId.trim().isEmpty
          ? companyId
          : event.rule.companyId,
    );
    final Either<Failure, ReconciliationRuleEntity> result =
        await _repository.createRule(rule);
    await result.fold(
      (Failure failure) async => emit(RulesError(failure.message)),
      (ReconciliationRuleEntity created) async {
        final Either<Failure, List<ReconciliationRuleEntity>> reload =
            await _repository.getRules(created.companyId);
        reload.fold(
          (Failure failure) => emit(RulesError(failure.message)),
          (List<ReconciliationRuleEntity> rules) => emit(RulesLoaded(rules)),
        );
      },
    );
  }

  Future<void> _onToggleRuleStatus(
    ToggleRuleStatusEvent event,
    Emitter<RulesState> emit,
  ) async {
    final RulesState current = state;
    final List<ReconciliationRuleEntity> currentRules =
        current is RulesLoaded ? current.rules : const <ReconciliationRuleEntity>[];
    emit(RulesLoaded(
      currentRules
          .map(
            (ReconciliationRuleEntity rule) => rule.id == event.ruleId
                ? rule.copyWith(isActive: event.isActive)
                : rule,
          )
          .toList(growable: false),
    ));
    final Either<Failure, ReconciliationRuleEntity> result =
        await _repository.toggleRuleStatus(event.ruleId, event.isActive);
    await result.fold(
      (Failure failure) async => emit(RulesError(failure.message)),
      (ReconciliationRuleEntity updated) async {
        final Either<Failure, List<ReconciliationRuleEntity>> reload =
            await _repository.getRules(updated.companyId);
        reload.fold(
          (Failure failure) => emit(RulesError(failure.message)),
          (List<ReconciliationRuleEntity> rules) => emit(RulesLoaded(rules)),
        );
      },
    );
  }

  Future<void> _onReorderRules(
    ReorderRulesEvent event,
    Emitter<RulesState> emit,
  ) async {
    final RulesState current = state;
    final List<ReconciliationRuleEntity> currentRules =
        current is RulesLoaded ? current.rules : const <ReconciliationRuleEntity>[];
    final Map<String, ReconciliationRuleEntity> byId =
        <String, ReconciliationRuleEntity>{
      for (final ReconciliationRuleEntity rule in currentRules) rule.id: rule,
    };
    final List<ReconciliationRuleEntity> reordered = <ReconciliationRuleEntity>[
      for (int index = 0; index < event.orderedRuleIds.length; index++)
        if (byId[event.orderedRuleIds[index]] != null)
          byId[event.orderedRuleIds[index]]!.copyWith(priority: index),
    ];
    emit(RulesLoaded(reordered));
    await _repository.reorderRules(event.orderedRuleIds);
  }
}
