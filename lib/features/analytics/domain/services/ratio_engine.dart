import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../entities/financial_ratio_entity.dart';

/// Raw ledger-derived inputs assembled by the repository before the ratio
/// engine runs. Undefined inputs are passed as zero and reported with a
/// [RatioStatus.notApplicable] status.
class RatioEngineInput extends Equatable {
  const RatioEngineInput({
    this.revenue = 0,
    this.cogs = 0,
    this.grossProfit = 0,
    this.netProfit = 0,
    this.ebit = 0,
    this.interestExpense = 0,
    this.cashAndEquivalents = 0,
    this.marketableSecurities = 0,
    this.receivables = 0,
    this.inventory = 0,
    this.currentAssets = 0,
    this.currentLiabilities = 0,
    this.totalAssets = 0,
    this.totalLiabilities = 0,
    this.totalEquity = 0,
  });

  final double revenue;
  final double cogs;
  final double grossProfit;
  final double netProfit;
  final double ebit;
  final double interestExpense;
  final double cashAndEquivalents;
  final double marketableSecurities;
  final double receivables;
  final double inventory;
  final double currentAssets;
  final double currentLiabilities;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;

  @override
  List<Object?> get props => <Object?>[
        revenue,
        cogs,
        grossProfit,
        netProfit,
        ebit,
        interestExpense,
        cashAndEquivalents,
        marketableSecurities,
        receivables,
        inventory,
        currentAssets,
        currentLiabilities,
        totalAssets,
        totalLiabilities,
        totalEquity,
      ];
}

/// Corporate financial ratio engine (liquidity, profitability, leverage,
/// and operational efficiency) with zero-division-safe evaluation against
/// standard enterprise benchmarks.
class RatioEngine {
  const RatioEngine();

  static const double _epsilon = 0.000001;

  FinancialRatioEntity compute({
    required String id,
    required String companyId,
    required DateTimeRange period,
    required RatioEngineInput input,
  }) {
    final double currentRatio = _divide(
      input.currentAssets,
      input.currentLiabilities,
    );
    final double quickRatio = _divide(
      input.cashAndEquivalents +
          input.marketableSecurities +
          input.receivables,
      input.currentLiabilities,
    );
    final double cashRatio =
        _divide(input.cashAndEquivalents, input.currentLiabilities);

    final double grossProfitMargin =
        _percent(input.grossProfit, input.revenue);
    final double netProfitMargin = _percent(input.netProfit, input.revenue);
    final double returnOnAssets = _percent(input.netProfit, input.totalAssets);
    final double returnOnEquity = _percent(input.netProfit, input.totalEquity);

    final double debtToEquityRatio =
        _divide(input.totalLiabilities, input.totalEquity);
    final double interestCoverageRatio =
        _divide(input.ebit, input.interestExpense);

    final double assetTurnover = _divide(input.revenue, input.totalAssets);
    final double daysSalesOutstanding =
        _days(input.receivables, input.revenue);
    final double daysInventoryOutstanding = _days(input.inventory, input.cogs);

    final FinancialRatioEntity metrics = FinancialRatioEntity(
      id: id,
      companyId: companyId,
      period: period,
      currentRatio: currentRatio,
      quickRatio: quickRatio,
      cashRatio: cashRatio,
      grossProfitMargin: grossProfitMargin,
      netProfitMargin: netProfitMargin,
      returnOnAssets: returnOnAssets,
      returnOnEquity: returnOnEquity,
      debtToEquityRatio: debtToEquityRatio,
      interestCoverageRatio: interestCoverageRatio,
      assetTurnover: assetTurnover,
      daysSalesOutstanding: daysSalesOutstanding,
      daysInventoryOutstanding: daysInventoryOutstanding,
    );

    return FinancialRatioEntity(
      id: metrics.id,
      companyId: metrics.companyId,
      period: metrics.period,
      currentRatio: metrics.currentRatio,
      quickRatio: metrics.quickRatio,
      cashRatio: metrics.cashRatio,
      grossProfitMargin: metrics.grossProfitMargin,
      netProfitMargin: metrics.netProfitMargin,
      returnOnAssets: metrics.returnOnAssets,
      returnOnEquity: metrics.returnOnEquity,
      debtToEquityRatio: metrics.debtToEquityRatio,
      interestCoverageRatio: metrics.interestCoverageRatio,
      assetTurnover: metrics.assetTurnover,
      daysSalesOutstanding: metrics.daysSalesOutstanding,
      daysInventoryOutstanding: metrics.daysInventoryOutstanding,
      benchmarks: buildBenchmarks(input, metrics),
    );
  }

  /// Evaluates every metric against its benchmark thresholds.
  List<RatioBenchmark> buildBenchmarks(
    RatioEngineInput input,
    FinancialRatioEntity metrics,
  ) {
    return <RatioBenchmark>[
      RatioBenchmark(
        name: 'Current Ratio',
        category: KpiCategory.liquidity,
        value: metrics.currentRatio,
        unit: 'x',
        target: '> 1.5',
        status: input.currentLiabilities <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.currentRatio, 2.0, 1.5),
      ),
      RatioBenchmark(
        name: 'Quick Ratio',
        category: KpiCategory.liquidity,
        value: metrics.quickRatio,
        unit: 'x',
        target: '> 1.0',
        status: input.currentLiabilities <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.quickRatio, 1.0, 0.8),
      ),
      RatioBenchmark(
        name: 'Cash Ratio',
        category: KpiCategory.liquidity,
        value: metrics.cashRatio,
        unit: 'x',
        target: '> 0.5',
        status: input.currentLiabilities <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.cashRatio, 0.5, 0.2),
      ),
      RatioBenchmark(
        name: 'Gross Profit Margin',
        category: KpiCategory.profitability,
        value: metrics.grossProfitMargin,
        unit: '%',
        target: '> 40%',
        status: input.revenue <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.grossProfitMargin, 40, 20),
      ),
      RatioBenchmark(
        name: 'Net Profit Margin',
        category: KpiCategory.profitability,
        value: metrics.netProfitMargin,
        unit: '%',
        target: '> 15%',
        status: input.revenue <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.netProfitMargin, 15, 5),
      ),
      RatioBenchmark(
        name: 'Return on Assets',
        category: KpiCategory.profitability,
        value: metrics.returnOnAssets,
        unit: '%',
        target: '> 8%',
        status: input.totalAssets <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.returnOnAssets, 8, 3),
      ),
      RatioBenchmark(
        name: 'Return on Equity',
        category: KpiCategory.profitability,
        value: metrics.returnOnEquity,
        unit: '%',
        target: '> 15%',
        status: input.totalEquity <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.returnOnEquity, 15, 8),
      ),
      RatioBenchmark(
        name: 'Debt-to-Equity',
        category: KpiCategory.leverage,
        value: metrics.debtToEquityRatio,
        unit: 'x',
        target: '< 2.0',
        status: input.totalEquity <= _epsilon
            ? RatioStatus.notApplicable
            : _lowIsBetter(metrics.debtToEquityRatio, 1.0, 2.0),
      ),
      RatioBenchmark(
        name: 'Interest Coverage',
        category: KpiCategory.leverage,
        value: metrics.interestCoverageRatio,
        unit: 'x',
        target: '> 5',
        status: input.interestExpense <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.interestCoverageRatio, 5, 1.5),
      ),
      RatioBenchmark(
        name: 'Asset Turnover',
        category: KpiCategory.efficiency,
        value: metrics.assetTurnover,
        unit: 'x',
        target: '> 1.0',
        status: input.totalAssets <= _epsilon
            ? RatioStatus.notApplicable
            : _highIsBetter(metrics.assetTurnover, 1.0, 0.5),
      ),
      RatioBenchmark(
        name: 'Days Sales Outstanding',
        category: KpiCategory.efficiency,
        value: metrics.daysSalesOutstanding,
        unit: 'days',
        target: '< 30',
        status: input.revenue <= _epsilon
            ? RatioStatus.notApplicable
            : _lowIsBetter(metrics.daysSalesOutstanding, 30, 60),
      ),
      RatioBenchmark(
        name: 'Days Inventory Outstanding',
        category: KpiCategory.efficiency,
        value: metrics.daysInventoryOutstanding,
        unit: 'days',
        target: '< 30',
        status: input.cogs <= _epsilon
            ? RatioStatus.notApplicable
            : _lowIsBetter(metrics.daysInventoryOutstanding, 30, 60),
      ),
    ];
  }

  /// Builds a plain-language executive summary from the benchmark results.
  String buildExecutiveSummary(List<RatioBenchmark> benchmarks) {
    final List<RatioBenchmark> strengths = benchmarks
        .where((RatioBenchmark b) => b.status == RatioStatus.optimal)
        .toList(growable: false);
    final List<RatioBenchmark> risks = benchmarks
        .where((RatioBenchmark b) => b.status == RatioStatus.critical)
        .toList(growable: false);

    final StringBuffer buffer = StringBuffer();
    if (strengths.isNotEmpty) {
      buffer.write('Strengths: ');
      buffer.write(
        strengths
            .take(3)
            .map(
              (RatioBenchmark b) =>
                  '${b.name} is healthy at ${_formatValue(b)}',
            )
            .join('; '),
      );
      buffer.write('. ');
    }
    if (risks.isNotEmpty) {
      buffer.write('Key risks: ');
      buffer.write(
        risks
            .map(
              (RatioBenchmark b) =>
                  '${b.name} at ${_formatValue(b)} against target ${b.target}',
            )
            .join('; '),
      );
      buffer.write('.');
    }
    if (strengths.isEmpty && risks.isEmpty) {
      buffer.write(
        'Financial position is stable; no metrics exceeded benchmarks '
        'this period.',
      );
    }
    return buffer.toString().trim();
  }

  static String _formatValue(RatioBenchmark benchmark) {
    final double value = benchmark.value;
    return benchmark.unit == '%'
        ? '${value.toStringAsFixed(1)}%'
        : benchmark.unit == 'days'
            ? '${value.toStringAsFixed(0)} days'
            : value.toStringAsFixed(2);
  }

  static RatioStatus _highIsBetter(
    double value,
    double optimalThreshold,
    double cautionThreshold,
  ) {
    if (value >= optimalThreshold) {
      return RatioStatus.optimal;
    }
    if (value >= cautionThreshold) {
      return RatioStatus.caution;
    }
    return RatioStatus.critical;
  }

  static RatioStatus _lowIsBetter(
    double value,
    double optimalThreshold,
    double cautionThreshold,
  ) {
    if (value <= optimalThreshold) {
      return RatioStatus.optimal;
    }
    if (value <= cautionThreshold) {
      return RatioStatus.caution;
    }
    return RatioStatus.critical;
  }

  static double _divide(double numerator, double denominator) {
    if (denominator.abs() <= _epsilon) {
      return 0;
    }
    return numerator / denominator;
  }

  static double _percent(double numerator, double denominator) {
    return _divide(numerator, denominator) * 100;
  }

  static double _days(double balance, double flow) {
    if (flow.abs() <= _epsilon) {
      return 0;
    }
    return balance / flow * 365;
  }
}
