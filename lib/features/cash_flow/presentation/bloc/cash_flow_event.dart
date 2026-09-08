import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../domain/entities/cash_flow_statement_entity.dart';

abstract class CashFlowEvent extends Equatable {
  const CashFlowEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class GenerateCashFlowReportEvent extends CashFlowEvent {
  const GenerateCashFlowReportEvent({
    required this.companyId,
    required this.range,
    required this.method,
  });

  final String companyId;
  final DateTimeRange range;
  final CashFlowMethod method;

  @override
  List<Object?> get props => <Object?>[companyId, range, method];
}

class ExportCashFlowPdfEvent extends CashFlowEvent {
  const ExportCashFlowPdfEvent();
}
