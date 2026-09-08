import 'package:equatable/equatable.dart';

import '../../domain/entities/cash_flow_monthly_point.dart';
import '../../domain/entities/cash_flow_statement_entity.dart';

abstract class CashFlowState extends Equatable {
  const CashFlowState();

  @override
  List<Object?> get props => const <Object?>[];
}

class CashFlowInitial extends CashFlowState {
  const CashFlowInitial();
}

class CashFlowLoading extends CashFlowState {
  const CashFlowLoading();
}

class CashFlowLoaded extends CashFlowState {
  const CashFlowLoaded({
    required this.statement,
    this.monthly = const <CashFlowMonthlyPoint>[],
    this.exportedPath,
  });

  final CashFlowStatementEntity statement;
  final List<CashFlowMonthlyPoint> monthly;
  final String? exportedPath;

  @override
  List<Object?> get props => <Object?>[statement, monthly, exportedPath];
}

class CashFlowError extends CashFlowState {
  const CashFlowError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
