import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// Computed cash flow statement for one company and date range.
class CashFlowEntity extends Equatable {
  const CashFlowEntity({
    required this.dateRange,
    required this.operatingCashFlow,
    required this.investingCashFlow,
    required this.financingCashFlow,
    required this.netCashChange,
    required this.endingCashBalance,
  });

  final DateTimeRange dateRange;
  final double operatingCashFlow;
  final double investingCashFlow;
  final double financingCashFlow;
  final double netCashChange;
  final double endingCashBalance;

  @override
  List<Object?> get props => <Object?>[
        dateRange,
        operatingCashFlow,
        investingCashFlow,
        financingCashFlow,
        netCashChange,
        endingCashBalance,
      ];
}
