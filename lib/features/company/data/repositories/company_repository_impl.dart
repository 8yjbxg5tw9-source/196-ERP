import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_local_data_source.dart';
import '../models/company_model.dart';

/// Company repository backed by SQLite and secure active-context storage.
class CompanyRepositoryImpl implements CompanyRepository {
  const CompanyRepositoryImpl(this._localDataSource);

  final CompanyLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, List<CompanyEntity>>> getCompanies() async {
    try {
      final List<CompanyModel> companies =
          await _localDataSource.getCompanies();
      return Right<Failure, List<CompanyEntity>>(companies);
    } on DatabaseException catch (error) {
      return Left<Failure, List<CompanyEntity>>(
        DatabaseFailure(
          message: 'Companies could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on StateError catch (error) {
      return Left<Failure, List<CompanyEntity>>(
        DatabaseFailure(
          message: 'The company database is not ready.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<CompanyEntity>>(
        CacheFailure(
          message: 'Saved companies could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CompanyEntity>> createCompany(
    CompanyEntity company,
  ) async {
    try {
      final CompanyModel created = await _localDataSource.createCompany(
        CompanyModel(
          id: company.id,
          name: company.name,
          voenTin: company.voenTin,
          taxType: company.taxType,
          createdAt: company.createdAt,
        ),
      );
      return Right<Failure, CompanyEntity>(created);
    } on DatabaseException catch (error) {
      return Left<Failure, CompanyEntity>(
        DatabaseFailure(
          message: 'The company could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, CompanyEntity>(
        CacheFailure(
          message: 'The company could not be saved locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteCompany(String id) async {
    try {
      await _localDataSource.deleteCompany(id);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The company could not be deleted from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'The company could not be deleted locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CompanyEntity?>> getActiveCompany() async {
    try {
      final CompanyModel? active = await _localDataSource.getActiveCompany();
      return Right<Failure, CompanyEntity?>(active);
    } on DatabaseException catch (error) {
      return Left<Failure, CompanyEntity?>(
        DatabaseFailure(
          message: 'The active company could not be read from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, CompanyEntity?>(
        CacheFailure(
          message: 'The active company context could not be restored.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> setActiveCompany(String companyId) async {
    try {
      await _localDataSource.setActiveCompany(companyId);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The active company could not be validated in SQLite.',
          cause: error,
        ),
      );
    } on StateError catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The selected company does not exist.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'The active company context could not be saved.',
          cause: error,
        ),
      );
    }
  }
}
