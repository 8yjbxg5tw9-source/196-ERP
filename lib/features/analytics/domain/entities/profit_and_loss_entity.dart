import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// Computed profit & loss statement for one company and date range.
class ProfitAndLossEntity extends Equatable {
  const ProfitAndLossEntity({
    required this.dateRange,
    required this.totalRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.totalExpenses,
    required this.ebitda,
    required this.netProfit,
    required this.profitMarginPercentage,
    this.outputVat = 0,
    this.inputVat = 0,
    this.netPayableVat = 0,
  });

  final DateTimeRange dateRange;
  final double totalRevenue;
  final double cogs;
  final double grossProfit;

  /// Operating expenses keyed by human-readable account name.
  final Map<String, double> operatingExpenses;
  final double totalExpenses;
  final double ebitda;
  final double netProfit;
  final double profitMarginPercentage;

  final double outputVat;
  final double inputVat;
  final double netPayableVat;

  @override
  List<Object?> get props => <Object?>[
        dateRange,
        totalRevenue,
        cogs,
        grossProfit,
        operatingExpenses,
        totalExpenses,
        ebitda,
        netProfit,
        profitMarginPercentage,
        outputVat,
        inputVat,
        netPayableVat,
      ];
}
