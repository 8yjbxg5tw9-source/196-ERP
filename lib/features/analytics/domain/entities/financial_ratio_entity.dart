import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// The four families of corporate financial ratios.
enum KpiCategory { liquidity, profitability, leverage, efficiency }

extension KpiCategoryLabel on KpiCategory {
  String get label => switch (this) {
        KpiCategory.liquidity => 'Liquidity',
        KpiCategory.profitability => 'Profitability',
        KpiCategory.leverage => 'Leverage & Solvency',
        KpiCategory.efficiency => 'Operational Efficiency',
      };
}

/// Health classification of a ratio against its benchmark thresholds.
enum RatioStatus { optimal, caution, critical, notApplicable }

extension RatioStatusLabel on RatioStatus {
  String get label => switch (this) {
        RatioStatus.optimal => 'Optimal',
        RatioStatus.caution => 'Caution',
        RatioStatus.critical => 'Critical Risk',
        RatioStatus.notApplicable => 'n/a',
      };
}

/// A metric value, its benchmark target, and its evaluated status.
class RatioBenchmark extends Equatable {
  const RatioBenchmark({
    required this.name,
    required this.category,
    required this.value,
    required this.unit,
    required this.target,
    required this.status,
  });

  final String name;
  final KpiCategory category;
  final double value;

  /// Display unit: `x`, `%`, or `days`.
  final String unit;

  /// Human-readable benchmark, e.g. `> 1.5`.
  final String target;
  final RatioStatus status;

  @override
  List<Object?> get props =>
      <Object?>[name, category, value, unit, target, status];
}

/// A full set of corporate financial ratios for one company and period.
class FinancialRatioEntity extends Equatable {
  const FinancialRatioEntity({
    required this.id,
    required this.companyId,
    required this.period,
    required this.currentRatio,
    required this.quickRatio,
    required this.cashRatio,
    required this.grossProfitMargin,
    required this.netProfitMargin,
    required this.returnOnAssets,
    required this.returnOnEquity,
    required this.debtToEquityRatio,
    required this.interestCoverageRatio,
    required this.assetTurnover,
    required this.daysSalesOutstanding,
    required this.daysInventoryOutstanding,
    this.benchmarks = const <RatioBenchmark>[],
  });

  final String id;
  final String companyId;
  final DateTimeRange period;

  // Liquidity.
  final double currentRatio;
  final double quickRatio;
  final double cashRatio;

  // Profitability (percentages).
  final double grossProfitMargin;
  final double netProfitMargin;
  final double returnOnAssets;
  final double returnOnEquity;

  // Leverage & solvency.
  final double debtToEquityRatio;
  final double interestCoverageRatio;

  // Operational efficiency.
  final double assetTurnover;
  final double daysSalesOutstanding;
  final double daysInventoryOutstanding;

  final List<RatioBenchmark> benchmarks;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        period,
        currentRatio,
        quickRatio,
        cashRatio,
        grossProfitMargin,
        netProfitMargin,
        returnOnAssets,
        returnOnEquity,
        debtToEquityRatio,
        interestCoverageRatio,
        assetTurnover,
        daysSalesOutstanding,
        daysInventoryOutstanding,
        benchmarks,
      ];
}
