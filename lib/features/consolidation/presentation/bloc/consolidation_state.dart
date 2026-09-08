import 'package:equatable/equatable.dart';

import '../../domain/entities/company_group_entity.dart';
import '../../domain/entities/consolidated_report_entity.dart';

abstract class ConsolidationState extends Equatable {
  const ConsolidationState();

  @override
  List<Object?> get props => const <Object?>[];
}

class ConsolidationInitial extends ConsolidationState {
  const ConsolidationInitial();
}

class ConsolidationLoadingGroups extends ConsolidationState {
  const ConsolidationLoadingGroups();
}

class ConsolidationGroupsLoaded extends ConsolidationState {
  const ConsolidationGroupsLoaded({
    required this.groups,
    this.selectedGroupId,
    this.report,
    this.isGenerating = false,
  });

  final List<CompanyGroupEntity> groups;
  final String? selectedGroupId;
  final ConsolidatedReportEntity? report;
  final bool isGenerating;

  CompanyGroupEntity? get selectedGroup {
    for (final CompanyGroupEntity group in groups) {
      if (group.id == selectedGroupId) {
        return group;
      }
    }
    return null;
  }

  ConsolidationGroupsLoaded copyWith({
    List<CompanyGroupEntity>? groups,
    Object? selectedGroupId = _unset,
    Object? report = _unset,
    bool? isGenerating,
  }) {
    return ConsolidationGroupsLoaded(
      groups: groups ?? this.groups,
      selectedGroupId: identical(selectedGroupId, _unset)
          ? this.selectedGroupId
          : selectedGroupId as String?,
      report: identical(report, _unset)
          ? this.report
          : report as ConsolidatedReportEntity?,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[groups, selectedGroupId, report, isGenerating];
}

class ConsolidationError extends ConsolidationState {
  const ConsolidationError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

const Object _unset = Object();
