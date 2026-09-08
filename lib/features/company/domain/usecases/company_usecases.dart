import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/company_entity.dart';
import '../repositories/company_repository.dart';

/// Loads every company available in the local workspace.
class GetCompaniesUseCase
    implements UseCase<List<CompanyEntity>, NoParams> {
  const GetCompaniesUseCase(this._repository);

  final CompanyRepository _repository;

  @override
  Future<Either<Failure, List<CompanyEntity>>> call(NoParams params) {
    return _repository.getCompanies();
  }
}

/// Creates and persists a company profile.
class CreateCompanyUseCase
    implements UseCase<CompanyEntity, CompanyEntity> {
  const CreateCompanyUseCase(this._repository);

  final CompanyRepository _repository;

  @override
  Future<Either<Failure, CompanyEntity>> call(CompanyEntity params) {
    return _repository.createCompany(params);
  }
}

/// Deletes a company profile from the local workspace.
class DeleteCompanyUseCase implements UseCase<void, String> {
  const DeleteCompanyUseCase(this._repository);

  final CompanyRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return _repository.deleteCompany(params);
  }
}

/// Reads the company persisted as the current application context.
class GetActiveCompanyUseCase
    implements UseCase<CompanyEntity?, NoParams> {
  const GetActiveCompanyUseCase(this._repository);

  final CompanyRepository _repository;

  @override
  Future<Either<Failure, CompanyEntity?>> call(NoParams params) {
    return _repository.getActiveCompany();
  }
}

/// Persists the company used by feature modules as their active context.
class SwitchActiveCompanyUseCase implements UseCase<void, String> {
  const SwitchActiveCompanyUseCase(this._repository);

  final CompanyRepository _repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return _repository.setActiveCompany(params);
  }
}
