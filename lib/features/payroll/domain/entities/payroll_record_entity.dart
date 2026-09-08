import 'package:equatable/equatable.dart';

/// One computed monthly payroll record, itemized by statutory deduction.
class PayrollRecordEntity extends Equatable {
  const PayrollRecordEntity({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.periodMonth,
    required this.periodYear,
    required this.grossSalary,
    required this.taxableIncome,
    required this.incomeTax,
    required this.employeeDsmf,
    required this.employerDsmf,
    required this.employeeUnemployment,
    required this.employerUnemployment,
    required this.employeeHealthInsurance,
    required this.employerHealthInsurance,
    required this.netSalary,
    required this.totalEmployerCost,
    this.isApproved = false,
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String companyId;
  final int periodMonth;
  final int periodYear;
  final double grossSalary;
  final double taxableIncome;
  final double incomeTax;
  final double employeeDsmf;
  final double employerDsmf;
  final double employeeUnemployment;
  final double employerUnemployment;
  final double employeeHealthInsurance;
  final double employerHealthInsurance;
  final double netSalary;
  final double totalEmployerCost;
  final bool isApproved;
  final DateTime? createdAt;

  double get totalEmployeeWithholdings =>
      incomeTax + employeeDsmf + employeeUnemployment + employeeHealthInsurance;

  double get totalEmployerContributions =>
      employerDsmf + employerUnemployment + employerHealthInsurance;

  PayrollRecordEntity copyWith({
    String? id,
    String? employeeId,
    String? companyId,
    int? periodMonth,
    int? periodYear,
    double? grossSalary,
    double? taxableIncome,
    double? incomeTax,
    double? employeeDsmf,
    double? employerDsmf,
    double? employeeUnemployment,
    double? employerUnemployment,
    double? employeeHealthInsurance,
    double? employerHealthInsurance,
    double? netSalary,
    double? totalEmployerCost,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return PayrollRecordEntity(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      companyId: companyId ?? this.companyId,
      periodMonth: periodMonth ?? this.periodMonth,
      periodYear: periodYear ?? this.periodYear,
      grossSalary: grossSalary ?? this.grossSalary,
      taxableIncome: taxableIncome ?? this.taxableIncome,
      incomeTax: incomeTax ?? this.incomeTax,
      employeeDsmf: employeeDsmf ?? this.employeeDsmf,
      employerDsmf: employerDsmf ?? this.employerDsmf,
      employeeUnemployment: employeeUnemployment ?? this.employeeUnemployment,
      employerUnemployment:
          employerUnemployment ?? this.employerUnemployment,
      employeeHealthInsurance:
          employeeHealthInsurance ?? this.employeeHealthInsurance,
      employerHealthInsurance:
          employerHealthInsurance ?? this.employerHealthInsurance,
      netSalary: netSalary ?? this.netSalary,
      totalEmployerCost: totalEmployerCost ?? this.totalEmployerCost,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        employeeId,
        companyId,
        periodMonth,
        periodYear,
        grossSalary,
        taxableIncome,
        incomeTax,
        employeeDsmf,
        employerDsmf,
        employeeUnemployment,
        employerUnemployment,
        employeeHealthInsurance,
        employerHealthInsurance,
        netSalary,
        totalEmployerCost,
        isApproved,
        createdAt,
      ];
}
