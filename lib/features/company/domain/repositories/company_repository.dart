import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/company_entity.dart';

/// Persistence contract for company profiles and the active company context.
abstract interface class CompanyRepository {
  Future<Either<Failure, List<CompanyEntity>>> getCompanies();

  Future<Either<Failure, CompanyEntity>> createCompany(
    CompanyEntity company,
  );

  Future<Either<Failure, void>> deleteCompany(String id);

  Future<Either<Failure, CompanyEntity?>> getActiveCompany();

  Future<Either<Failure, void>> setActiveCompany(String companyId);
}
