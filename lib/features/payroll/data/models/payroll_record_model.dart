import '../../domain/entities/payroll_record_entity.dart';

/// SQLite mapping for the `payroll_records` table.
class PayrollRecordModel extends PayrollRecordEntity {
  const PayrollRecordModel({
    required super.id,
    required super.employeeId,
    required super.companyId,
    required super.periodMonth,
    required super.periodYear,
    required super.grossSalary,
    required super.taxableIncome,
    required super.incomeTax,
    required super.employeeDsmf,
    required super.employerDsmf,
    required super.employeeUnemployment,
    required super.employerUnemployment,
    required super.employeeHealthInsurance,
    required super.employerHealthInsurance,
    required super.netSalary,
    required super.totalEmployerCost,
    super.isApproved = false,
    super.createdAt,
  });

  factory PayrollRecordModel.fromMap(Map<String, Object?> map) {
    return PayrollRecordModel(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      periodMonth: int.tryParse(map['period_month']?.toString() ?? '') ?? 0,
      periodYear: int.tryParse(map['period_year']?.toString() ?? '') ?? 0,
      grossSalary: _doubleValue(map['gross_salary']),
      taxableIncome: _doubleValue(map['taxable_income']),
      incomeTax: _doubleValue(map['income_tax']),
      employeeDsmf: _doubleValue(map['employee_dsmf']),
      employerDsmf: _doubleValue(map['employer_dsmf']),
      employeeUnemployment: _doubleValue(map['employee_unemployment']),
      employerUnemployment: _doubleValue(map['employer_unemployment']),
      employeeHealthInsurance: _doubleValue(map['employee_health_insurance']),
      employerHealthInsurance: _doubleValue(map['employer_health_insurance']),
      netSalary: _doubleValue(map['net_salary']),
      totalEmployerCost: _doubleValue(map['total_employer_cost']),
      isApproved: (map['is_approved'] ?? 0) == 1 ||
          map['is_approved']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory PayrollRecordModel.fromEntity(PayrollRecordEntity entity) {
    return PayrollRecordModel(
      id: entity.id,
      employeeId: entity.employeeId,
      companyId: entity.companyId,
      periodMonth: entity.periodMonth,
      periodYear: entity.periodYear,
      grossSalary: entity.grossSalary,
      taxableIncome: entity.taxableIncome,
      incomeTax: entity.incomeTax,
      employeeDsmf: entity.employeeDsmf,
      employerDsmf: entity.employerDsmf,
      employeeUnemployment: entity.employeeUnemployment,
      employerUnemployment: entity.employerUnemployment,
      employeeHealthInsurance: entity.employeeHealthInsurance,
      employerHealthInsurance: entity.employerHealthInsurance,
      netSalary: entity.netSalary,
      totalEmployerCost: entity.totalEmployerCost,
      isApproved: entity.isApproved,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'employee_id': employeeId,
      'company_id': companyId,
      'period_month': periodMonth,
      'period_year': periodYear,
      'gross_salary': grossSalary,
      'taxable_income': taxableIncome,
      'income_tax': incomeTax,
      'employee_dsmf': employeeDsmf,
      'employer_dsmf': employerDsmf,
      'employee_unemployment': employeeUnemployment,
      'employer_unemployment': employerUnemployment,
      'employee_health_insurance': employeeHealthInsurance,
      'employer_health_insurance': employerHealthInsurance,
      'net_salary': netSalary,
      'total_employer_cost': totalEmployerCost,
      'is_approved': isApproved ? 1 : 0,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
