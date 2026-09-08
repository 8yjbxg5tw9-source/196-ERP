import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/financial_ratio_entity.dart';
import '../../domain/repositories/financial_ratio_repository.dart';
import 'analytics_event.dart';
import 'analytics_state.dart';

/// Coordinates ratio computation and multi-period trend fetching for the
/// executive KPI dashboard.
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc({required FinancialRatioRepository repository})
      : _repository = repository,
        super(const AnalyticsInitial()) {
    on<CalculateFinancialRatiosEvent>(_onCalculate);
    on<FetchRatioTrendsEvent>(_onFetchTrends);
  }

  final FinancialRatioRepository _repository;

  FinancialRatioEntity? _metrics;
  Map<String, List<double>> _trendData = const <String, List<double>>{};

  Future<void> _onCalculate(
    CalculateFinancialRatiosEvent event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(const AnalyticsLoading());
    final Either<Failure, FinancialRatioEntity> metricsResult =
        await _repository.calculateRatios(event.companyId, event.range);

    if (metricsResult.isLeft()) {
      final Failure failure =
          (metricsResult as Left<Failure, FinancialRatioEntity>).value;
      emit(AnalyticsError(failure.message));
      return;
    }

    final FinancialRatioEntity metrics =
        (metricsResult as Right<Failure, FinancialRatioEntity>).value;
    _metrics = metrics;

    final Either<Failure, Map<String, List<double>>> trendsResult =
        await _repository.fetchRatioTrends(event.companyId, 4);
    _trendData = trendsResult.fold(
      (_) => const <String, List<double>>{},
      (Map<String, List<double>> value) => value,
    );

    emit(RatiosCalculated(metrics: metrics, trendData: _trendData));
  }

  Future<void> _onFetchTrends(
    FetchRatioTrendsEvent event,
    Emitter<AnalyticsState> emit,
  ) async {
    final FinancialRatioEntity? metrics = _metrics;
    if (metrics == null) {
      emit(const AnalyticsError('Calculate the ratios before loading trends.'));
      return;
    }
    emit(const AnalyticsLoading());
    final Either<Failure, Map<String, List<double>>> trendsResult =
        await _repository.fetchRatioTrends(
      event.companyId,
      event.numberOfPeriods,
    );

    if (trendsResult.isLeft()) {
      final Failure failure =
          (trendsResult as Left<Failure, Map<String, List<double>>>).value;
      emit(AnalyticsError(failure.message));
      return;
    }

    _trendData =
        (trendsResult as Right<Failure, Map<String, List<double>>>).value;
    emit(RatiosCalculated(metrics: metrics, trendData: _trendData));
  }
}
