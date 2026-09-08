import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

abstract class ConsolidationEvent extends Equatable {
  const ConsolidationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadGroupsEvent extends ConsolidationEvent {
  const LoadGroupsEvent();
}

class CreateGroupEvent extends ConsolidationEvent {
  const CreateGroupEvent({
    required this.groupName,
    required this.parentCompanyId,
    required this.subsidiaryCompanyIds,
  });

  final String groupName;
  final String parentCompanyId;
  final List<String> subsidiaryCompanyIds;

  @override
  List<Object?> get props =>
      <Object?>[groupName, parentCompanyId, subsidiaryCompanyIds];
}

class SelectGroupEvent extends ConsolidationEvent {
  const SelectGroupEvent(this.groupId);

  final String groupId;

  @override
  List<Object?> get props => <Object?>[groupId];
}

class GenerateReportEvent extends ConsolidationEvent {
  const GenerateReportEvent({
    required this.groupId,
    required this.range,
  });

  final String groupId;
  final DateTimeRange range;

  @override
  List<Object?> get props => <Object?>[groupId, range];
}
