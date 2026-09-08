import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../../core/errors/failures.dart';
import '../entities/company_group_entity.dart';
import '../entities/consolidated_report_entity.dart';

/// Persistence and computation contract for multi-company consolidation.
abstract interface class ConsolidationRepository {
  Future<Either<Failure, CompanyGroupEntity>> createGroup({
    required String groupName,
    required String parentCompanyId,
    required List<String> subsidiaryCompanyIds,
  });

  Future<Either<Failure, List<CompanyGroupEntity>>> getGroups();

  Future<Either<Failure, ConsolidatedReportEntity>> generateConsolidatedReport(
    String groupId,
    DateTimeRange range,
  );
}
