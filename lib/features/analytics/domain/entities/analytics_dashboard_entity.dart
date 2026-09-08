import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// Revenue versus expenses for a single month on the trend chart.
class MonthlyProfitTrend extends Equatable {
  const MonthlyProfitTrend({
    required this.monthLabel,
    required this.revenue,
    required this.expenses,
  });

  final String monthLabel;
  final double revenue;
  final double expenses;

  @override
  List<Object?> get props => <Object?>[monthLabel, revenue, expenses];
}

/// One slice of the expense-category donut chart.
class ExpenseCategoryBreakdown extends Equatable {
  const ExpenseCategoryBreakdown({
    required this.name,
    required this.amount,
  });

  final String name;
  final double amount;

  @override
  List<Object?> get props => <Object?>[name, amount];
}

/// A dated balance used by the cash-flow line chart.
class CashFlowPoint extends Equatable {
  const CashFlowPoint({required this.date, required this.balance});

  final DateTime date;
  final double balance;

  @override
  List<Object?> get props => <Object?>[date, balance];
}

/// AI-assist output describing a projected liquidity shortfall.
class CashCrunchPrediction extends Equatable {
  const CashCrunchPrediction({
    required this.atRisk,
    required this.advice,
    this.crunchDate,
    this.projectedLowestCash = 0,
  });

  final bool atRisk;
  final DateTime? crunchDate;
  final double projectedLowestCash;
  final String advice;

  @override
  List<Object?> get props => <Object?>[
        atRisk,
        crunchDate,
        projectedLowestCash,
        advice,
      ];
}

/// Aggregate payload powering the executive analytics dashboard.
class DashboardAnalyticsEntity extends Equatable {
  const DashboardAnalyticsEntity({
    required this.dateRange,
    required this.grossRevenue,
    required this.grossRevenueChangePercent,
    required this.netOperatingExpenses,
    required this.expenseBreakdown,
    required this.netProfitMargin,
    required this.cashBalance,
    required this.runwayMonths,
    required this.debtToAssetRatio,
    required this.currentRatio,
    required this.monthlyTrend,
    required this.cashFlowTrend,
    required this.cashFlowForecast,
    this.cashCrunch,
  });

  final DateTimeRange dateRange;

  final double grossRevenue;
  final double grossRevenueChangePercent;
  final double netOperatingExpenses;
  final List<ExpenseCategoryBreakdown> expenseBreakdown;
  final double netProfitMargin;
  final double cashBalance;
  final double runwayMonths;
  final double debtToAssetRatio;
  final double currentRatio;

  final List<MonthlyProfitTrend> monthlyTrend;
  final List<CashFlowPoint> cashFlowTrend;
  final List<CashFlowPoint> cashFlowForecast;
  final CashCrunchPrediction? cashCrunch;

  @override
  List<Object?> get props => <Object?>[
        dateRange,
        grossRevenue,
        grossRevenueChangePercent,
        netOperatingExpenses,
        expenseBreakdown,
        netProfitMargin,
        cashBalance,
        runwayMonths,
        debtToAssetRatio,
        currentRatio,
        monthlyTrend,
        cashFlowTrend,
        cashFlowForecast,
        cashCrunch,
      ];
}
