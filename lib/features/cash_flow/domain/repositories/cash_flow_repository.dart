import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../../core/errors/failures.dart';
import '../entities/cash_flow_monthly_point.dart';
import '../entities/cash_flow_statement_entity.dart';

/// Compilation boundary for the IAS 7 cash flow engine.
abstract interface class CashFlowRepository {
  Future<Either<Failure, CashFlowStatementEntity>> generateStatement({
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowMethod method,
  });

  /// Net cash movement per calendar month, used for the liquidity waterfall.
  Future<Either<Failure, List<CashFlowMonthlyPoint>>> getMonthlyMovements({
    required String companyId,
    required DateTimeRange dateRange,
  });
}
