import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/company_group_entity.dart';
import '../../domain/entities/consolidated_report_entity.dart';
import '../../domain/repositories/consolidation_repository.dart';
import 'consolidation_event.dart';
import 'consolidation_state.dart';

/// Coordinates group management and consolidated report generation.
class ConsolidationBloc
    extends Bloc<ConsolidationEvent, ConsolidationState> {
  ConsolidationBloc({required ConsolidationRepository repository})
      : _repository = repository,
        super(const ConsolidationInitial()) {
    on<LoadGroupsEvent>(_onLoadGroups);
    on<CreateGroupEvent>(_onCreateGroup);
    on<SelectGroupEvent>(_onSelectGroup);
    on<GenerateReportEvent>(_onGenerateReport);
  }

  final ConsolidationRepository _repository;

  Future<void> _onLoadGroups(
    LoadGroupsEvent event,
    Emitter<ConsolidationState> emit,
  ) async {
    emit(const ConsolidationLoadingGroups());
    final Either<Failure, List<CompanyGroupEntity>> result =
        await _repository.getGroups();
    result.fold(
      (Failure failure) => emit(ConsolidationError(failure.message)),
      (List<CompanyGroupEntity> groups) => emit(
        ConsolidationGroupsLoaded(groups: groups),
      ),
    );
  }

  Future<void> _onCreateGroup(
    CreateGroupEvent event,
    Emitter<ConsolidationState> emit,
  ) async {
    final ConsolidationState current = state;
    final List<CompanyGroupEntity> groups =
        current is ConsolidationGroupsLoaded ? current.groups : const <CompanyGroupEntity>[];
    final String? selected =
        current is ConsolidationGroupsLoaded ? current.selectedGroupId : null;
    final ConsolidatedReportEntity? report =
        current is ConsolidationGroupsLoaded ? current.report : null;
    emit(
      ConsolidationGroupsLoaded(
        groups: groups,
        selectedGroupId: selected,
        report: report,
        isGenerating: true,
      ),
    );

    final Either<Failure, CompanyGroupEntity> result =
        await _repository.createGroup(
      groupName: event.groupName,
      parentCompanyId: event.parentCompanyId,
      subsidiaryCompanyIds: event.subsidiaryCompanyIds,
    );

    final Failure? failure = result.fold(
      (Failure value) => value,
      (CompanyGroupEntity _) => null,
    );
    if (failure != null) {
      emit(ConsolidationError(failure.message));
      return;
    }

    final Either<Failure, List<CompanyGroupEntity>> reload =
        await _repository.getGroups();
    reload.fold(
      (Failure value) => emit(ConsolidationError(value.message)),
      (List<CompanyGroupEntity> groups) => emit(
        ConsolidationGroupsLoaded(groups: groups),
      ),
    );
  }

  Future<void> _onSelectGroup(
    SelectGroupEvent event,
    Emitter<ConsolidationState> emit,
  ) async {
    final ConsolidationState current = state;
    if (current is! ConsolidationGroupsLoaded) {
      return;
    }
    emit(
      current.copyWith(
        selectedGroupId: event.groupId,
        report: null,
      ),
    );
  }

  Future<void> _onGenerateReport(
    GenerateReportEvent event,
    Emitter<ConsolidationState> emit,
  ) async {
    final ConsolidationState current = state;
    final List<CompanyGroupEntity> groups =
        current is ConsolidationGroupsLoaded ? current.groups : const <CompanyGroupEntity>[];
    emit(
      ConsolidationGroupsLoaded(
        groups: groups,
        selectedGroupId: event.groupId,
        report: current is ConsolidationGroupsLoaded ? current.report : null,
        isGenerating: true,
      ),
    );

    final Either<Failure, ConsolidatedReportEntity> result =
        await _repository.generateConsolidatedReport(event.groupId, event.range);
    result.fold(
      (Failure failure) => emit(ConsolidationError(failure.message)),
      (ConsolidatedReportEntity report) => emit(
        ConsolidationGroupsLoaded(
          groups: groups,
          selectedGroupId: event.groupId,
          report: report,
        ),
      ),
    );
  }
}
