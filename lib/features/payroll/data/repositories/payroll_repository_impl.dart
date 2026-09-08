import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/payroll_record_entity.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../../domain/services/payroll_engine.dart';
import '../datasources/payroll_local_data_source.dart';
import '../models/employee_model.dart';
import '../models/payroll_record_model.dart';

/// Enterprise payroll implementation: gross-to-net calculation, batch
/// generation, and journal posting on approval.
class PayrollRepositoryImpl implements PayrollRepository {
  PayrollRepositoryImpl(
    this._localDataSource, {
    PayrollEngine engine = const PayrollEngine(),
  }) : _engine = engine;

  final PayrollLocalDataSource _localDataSource;
  final PayrollEngine _engine;

  @override
  Future<Either<Failure, List<EmployeeEntity>>> getEmployees(
    String companyId,
  ) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<EmployeeEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }

    try {
      final List<EmployeeModel> employees =
          await _localDataSource.getEmployees(normalizedCompanyId);
      return Right<Failure, List<EmployeeEntity>>(employees);
    } on DatabaseException catch (error) {
      return Left<Failure, List<EmployeeEntity>>(
        DatabaseFailure(
          message: 'Employees could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<EmployeeEntity>>(
        CacheFailure(
          message: 'Employees could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, EmployeeEntity>> addEmployee(
    EmployeeEntity employee,
  ) async {
    final String normalizedCompanyId = employee.companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, EmployeeEntity>(
        const ValidationFailure(message: 'Select a company before adding.'),
      );
    }
    if (employee.fullName.trim().isEmpty || employee.pin.trim().isEmpty) {
      return Left<Failure, EmployeeEntity>(
        const ValidationFailure(
          message: 'Employee name and PIN are required.',
        ),
      );
    }
    if (employee.baseSalary < 0) {
      return Left<Failure, EmployeeEntity>(
        const ValidationFailure(message: 'Base salary cannot be negative.'),
      );
    }

    try {
      await _localDataSource.createEmployee(
        EmployeeModel.fromEntity(employee),
      );
      return Right<Failure, EmployeeEntity>(employee);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return Left<Failure, EmployeeEntity>(
          const ValidationFailure(
            message: 'An employee with this PIN already exists.',
          ),
        );
      }
      return Left<Failure, EmployeeEntity>(
        DatabaseFailure(
          message: 'The employee could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, EmployeeEntity>(
        CacheFailure(
          message: 'The employee could not be saved.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<PayrollRecordEntity>>> calculateBatchPayroll({
    required String companyId,
    required int periodMonth,
    required int periodYear,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<PayrollRecordEntity>>(
        const ValidationFailure(message: 'Select a company before running.'),
      );
    }
    if (periodMonth < 1 || periodMonth > 12) {
      return Left<Failure, List<PayrollRecordEntity>>(
        const ValidationFailure(message: 'Period month must be between 1 and 12.'),
      );
    }

    try {
      final List<EmployeeModel> employees =
          await _localDataSource.getEmployees(normalizedCompanyId);
      final List<PayrollRecordEntity> records = <PayrollRecordEntity>[];
      for (final EmployeeModel employee in employees) {
        final PayrollResult result = _engine.grossToNet(
          grossSalary: employee.baseSalary,
          sector: employee.sectorType,
        );
        final PayrollRecordModel record = PayrollRecordModel(
          id: _recordId(employee.id, periodMonth, periodYear),
          employeeId: employee.id,
          companyId: normalizedCompanyId,
          periodMonth: periodMonth,
          periodYear: periodYear,
          grossSalary: result.grossSalary,
          taxableIncome: result.taxableIncome,
          incomeTax: result.incomeTax,
          employeeDsmf: result.employeeDsmf,
          employerDsmf: result.employerDsmf,
          employeeUnemployment: result.employeeUnemployment,
          employerUnemployment: result.employerUnemployment,
          employeeHealthInsurance: result.employeeHealthInsurance,
          employerHealthInsurance: result.employerHealthInsurance,
          netSalary: result.netSalary,
          totalEmployerCost: result.totalEmployerCost,
        );
        await _localDataSource.upsertPayrollRecord(record);
        records.add(record);
      }
      return Right<Failure, List<PayrollRecordEntity>>(records);
    } on DatabaseException catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        DatabaseFailure(
          message: 'The payroll batch could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        CacheFailure(
          message: 'The payroll batch could not be calculated.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<PayrollRecordEntity>>> approveAndPostPayroll({
    required String companyId,
    required int periodMonth,
    required int periodYear,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<PayrollRecordEntity>>(
        const ValidationFailure(message: 'Select a company before posting.'),
      );
    }

    try {
      // Ensure the batch reflects the current roster before approval.
      final Either<Failure, List<PayrollRecordEntity>> calculated =
          await calculateBatchPayroll(
        companyId: normalizedCompanyId,
        periodMonth: periodMonth,
        periodYear: periodYear,
      );
      if (calculated.isLeft()) {
        final Failure failure =
            calculated.fold((Failure value) => value, (_) => const DatabaseFailure());
        return Left<Failure, List<PayrollRecordEntity>>(failure);
      }
      final List<PayrollRecordModel> records =
          await _localDataSource.getPayrollRecords(
        companyId: normalizedCompanyId,
        periodMonth: periodMonth,
        periodYear: periodYear,
      );
      final List<EmployeeModel> employees =
          await _localDataSource.getEmployees(normalizedCompanyId);
      final Map<String, EmployeeEntity> employeesById = <String, EmployeeEntity>{
        for (final EmployeeModel employee in employees) employee.id: employee,
      };
      final DateTime entryDate = DateTime.utc(periodYear, periodMonth);
      final List<PayrollRecordEntity> posted = <PayrollRecordEntity>[];
      for (final PayrollRecordModel record in records) {
        final EmployeeEntity? employee = employeesById[record.employeeId];
        if (employee == null) {
          continue;
        }
        final List<PayrollJournalEntry> plan = _engine.buildPostingPlan(
          employee: employee,
          record: record,
          entryDate: entryDate,
        );
        for (final PayrollJournalEntry entry in plan) {
          await _localDataSource.writeJournalEntry(entry);
        }
        final PayrollRecordModel approved =
            PayrollRecordModel.fromEntity(record.copyWith(isApproved: true));
        await _localDataSource.upsertPayrollRecord(approved);
        posted.add(approved);
      }
      return Right<Failure, List<PayrollRecordEntity>>(posted);
    } on DatabaseException catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        DatabaseFailure(
          message: 'The payroll approval could not be posted.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        CacheFailure(
          message: 'The payroll approval could not be completed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<PayrollRecordEntity>>> getPayrollRecords({
    required String companyId,
    int? periodMonth,
    int? periodYear,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<PayrollRecordEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }

    try {
      final List<PayrollRecordModel> records =
          await _localDataSource.getPayrollRecords(
        companyId: normalizedCompanyId,
        periodMonth: periodMonth,
        periodYear: periodYear,
      );
      return Right<Failure, List<PayrollRecordEntity>>(records);
    } on DatabaseException catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        DatabaseFailure(
          message: 'Payroll records could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<PayrollRecordEntity>>(
        CacheFailure(
          message: 'Payroll records could not be read.',
          cause: error,
        ),
      );
    }
  }

  String _recordId(String employeeId, int month, int year) {
    return 'payroll-$employeeId-$year-$month';
  }
}
