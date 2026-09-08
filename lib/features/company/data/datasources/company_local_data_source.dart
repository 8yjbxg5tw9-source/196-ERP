import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../analytics/data/datasources/chart_of_accounts_seeder.dart';
import '../../../analytics/data/models/account_model.dart';
import '../models/company_model.dart';

/// Local persistence boundary for company records and active context.
abstract interface class CompanyLocalDataSource {
  Future<List<CompanyModel>> getCompanies();

  Future<CompanyModel> createCompany(CompanyModel company);

  Future<void> deleteCompany(String id);

  Future<CompanyModel?> getActiveCompany();

  Future<void> setActiveCompany(String companyId);
}

class CompanyLocalDataSourceImpl implements CompanyLocalDataSource {
  CompanyLocalDataSourceImpl(this._databaseService, this._secureStorage);

  final DatabaseService _databaseService;
  final SecureStorageService _secureStorage;

  @override
  Future<List<CompanyModel>> getCompanies() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.companies,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(CompanyModel.fromSqflite).toList(growable: false);
  }

  @override
  Future<CompanyModel> createCompany(CompanyModel company) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      await transaction.insert(
        DatabaseTables.companies,
        company.toSqflite(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      // Seed the standard chart of accounts together with the company profile
      // so every workspace starts with a reportable ledger structure.
      for (final account in ChartOfAccountsSeeder.defaultAccounts(company.id)) {
        await transaction.insert(
          DatabaseTables.accounts,
          AccountModel.fromEntity(account).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    return company;
  }

  @override
  Future<void> deleteCompany(String id) async {
    final Database database = await _databaseService.database;
    await database.delete(
      DatabaseTables.companies,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    final String? activeCompanyId = await _secureStorage.read(
      SecureStorageKeys.activeCompanyId,
    );
    if (activeCompanyId == id) {
      await _secureStorage.delete(SecureStorageKeys.activeCompanyId);
    }
  }

  @override
  Future<CompanyModel?> getActiveCompany() async {
    final String? activeCompanyId = await _secureStorage.read(
      SecureStorageKeys.activeCompanyId,
    );
    if (activeCompanyId == null || activeCompanyId.trim().isEmpty) {
      return null;
    }

    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.companies,
      where: 'id = ?',
      whereArgs: <Object?>[activeCompanyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      // Remove stale context if a company was deleted outside this repository.
      await _secureStorage.delete(SecureStorageKeys.activeCompanyId);
      return null;
    }
    return CompanyModel.fromSqflite(rows.first);
  }

  @override
  Future<void> setActiveCompany(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.companies,
      columns: <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>[companyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Cannot activate an unknown company: $companyId');
    }

    await _secureStorage.write(
      SecureStorageKeys.activeCompanyId,
      companyId,
    );
  }
}
