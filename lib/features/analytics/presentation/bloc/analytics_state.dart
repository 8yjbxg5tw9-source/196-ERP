import 'package:equatable/equatable.dart';

import '../../domain/entities/financial_ratio_entity.dart';

abstract class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => const <Object?>[];
}

class AnalyticsInitial extends AnalyticsState {
  const AnalyticsInitial();
}

class AnalyticsLoading extends AnalyticsState {
  const AnalyticsLoading();
}

/// Ratios are ready, optionally with multi-period trend series.
class RatiosCalculated extends AnalyticsState {
  const RatiosCalculated({
    required this.metrics,
    this.trendData = const <String, List<double>>{},
  });

  final FinancialRatioEntity metrics;
  final Map<String, List<double>> trendData;

  @override
  List<Object?> get props => <Object?>[metrics, trendData];
}

class AnalyticsError extends AnalyticsState {
  const AnalyticsError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
