import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../../core/errors/failures.dart';
import '../entities/financial_ratio_entity.dart';

/// Boundary for the corporate financial ratio engine.
abstract interface class FinancialRatioRepository {
  Future<Either<Failure, FinancialRatioEntity>> calculateRatios(
    String companyId,
    DateTimeRange dateRange,
  );

  /// Multi-period ratio series keyed by metric name, oldest to newest.
  Future<Either<Failure, Map<String, List<double>>>> fetchRatioTrends(
    String companyId,
    int numberOfPeriods,
  );
}
