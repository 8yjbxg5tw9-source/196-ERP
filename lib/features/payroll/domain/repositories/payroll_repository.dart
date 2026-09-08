import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/employee_entity.dart';
import '../entities/payroll_record_entity.dart';

/// Persistence + calculation boundary for the enterprise payroll engine.
abstract interface class PayrollRepository {
  Future<Either<Failure, List<EmployeeEntity>>> getEmployees(String companyId);

  Future<Either<Failure, EmployeeEntity>> addEmployee(EmployeeEntity employee);

  /// Computes (or recomputes) the payroll records for a period without
  /// posting anything.
  Future<Either<Failure, List<PayrollRecordEntity>>> calculateBatchPayroll({
    required String companyId,
    required int periodMonth,
    required int periodYear,
  });

  /// Approves the records for a period and posts the salary / withholding /
  /// social-contribution journal entries.
  Future<Either<Failure, List<PayrollRecordEntity>>> approveAndPostPayroll({
    required String companyId,
    required int periodMonth,
    required int periodYear,
  });

  Future<Either<Failure, List<PayrollRecordEntity>>> getPayrollRecords({
    required String companyId,
    int? periodMonth,
    int? periodYear,
  });
}
