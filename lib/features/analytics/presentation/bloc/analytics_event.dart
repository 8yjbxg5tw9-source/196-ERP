import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Computes the full financial ratio set for a company and period.
class CalculateFinancialRatiosEvent extends AnalyticsEvent {
  const CalculateFinancialRatiosEvent({
    required this.companyId,
    required this.range,
  });

  final String companyId;
  final DateTimeRange range;

  @override
  List<Object?> get props => <Object?>[companyId, range];
}

/// Fetches the multi-period ratio trend series.
class FetchRatioTrendsEvent extends AnalyticsEvent {
  const FetchRatioTrendsEvent({
    required this.companyId,
    required this.numberOfPeriods,
  });

  final String companyId;
  final int numberOfPeriods;

  @override
  List<Object?> get props => <Object?>[companyId, numberOfPeriods];
}
