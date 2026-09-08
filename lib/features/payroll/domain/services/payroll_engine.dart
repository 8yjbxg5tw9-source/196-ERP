import 'package:equatable/equatable.dart';

import '../entities/employee_entity.dart';
import '../entities/payroll_record_entity.dart';

/// Itemized statutory calculation for one employee and one pay period.
class PayrollResult extends Equatable {
  const PayrollResult({
    required this.grossSalary,
    required this.taxableIncome,
    required this.incomeTax,
    required this.employeeDsmf,
    required this.employerDsmf,
    required this.employeeUnemployment,
    required this.employerUnemployment,
    required this.employeeHealthInsurance,
    required this.employerHealthInsurance,
  });

  final double grossSalary;
  final double taxableIncome;
  final double incomeTax;
  final double employeeDsmf;
  final double employerDsmf;
  final double employeeUnemployment;
  final double employerUnemployment;
  final double employeeHealthInsurance;
  final double employerHealthInsurance;

  double get totalEmployeeWithholdings =>
      incomeTax + employeeDsmf + employeeUnemployment + employeeHealthInsurance;

  double get totalEmployerContributions =>
      employerDsmf + employerUnemployment + employerHealthInsurance;

  double get netSalary => grossSalary - totalEmployeeWithholdings;

  double get totalEmployerCost => grossSalary + totalEmployerContributions;

  @override
  List<Object?> get props => <Object?>[
        grossSalary,
        taxableIncome,
        incomeTax,
        employeeDsmf,
        employerDsmf,
        employeeUnemployment,
        employerUnemployment,
        employeeHealthInsurance,
        employerHealthInsurance,
      ];
}

/// One balancing ledger line posted when a payroll batch is approved.
class PayrollJournalEntry extends Equatable {
  const PayrollJournalEntry({
    required this.companyId,
    required this.entryDate,
    required this.description,
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
  });

  final String companyId;
  final DateTime entryDate;
  final String description;
  final String debitAccount;
  final String creditAccount;
  final double amount;
  final String sourceType;
  final String sourceId;

  @override
  List<Object?> get props => <Object?>[
        companyId,
        entryDate,
        description,
        debitAccount,
        creditAccount,
        amount,
        sourceType,
        sourceId,
      ];
}

/// Statutory payroll calculator for Azerbaijani employment regimes.
///
/// Non-oil private sector (the verified regime):
/// - Income tax: exempt up to 200 AZN, then 14% on the excess.
/// - Employee DSMF: 3% up to 200 AZN + 10% over.
/// - Employer DSMF: 22% up to 200 AZN + 15% over.
/// - Unemployment insurance: 0.5% employee / 0.5% employer.
/// - Health insurance: 2% up to 8,000 AZN, 0.5% above (both sides).
class PayrollEngine {
  const PayrollEngine();

  static const double _epsilon = 0.000001;
  static const double _socialCeiling = 200;
  static const double _healthCeiling = 8000;

  /// Ledger account for gross salaries and employer contributions.
  static const String salariesExpenseAccount = '511';

  /// Ledger account for the net salary payable to employees.
  static const String netPayableAccount = '201';

  /// Ledger account for withheld taxes and social contributions.
  static const String taxPayableAccount = '231';

  PayrollResult grossToNet({
    required double grossSalary,
    required SectorType sector,
  }) {
    final double taxableIncome = _taxableIncome(grossSalary, sector);
    final double incomeTax = taxableIncome * _incomeTaxRate(sector);

    final double dsmfBase = grossSalary.clamp(0, _socialCeiling).toDouble();
    final double dsmfExcess =
        (grossSalary - _socialCeiling) < 0 ? 0 : grossSalary - _socialCeiling;
    final double employeeDsmf = dsmfBase * 0.03 + dsmfExcess * 0.10;
    final double employerDsmf = dsmfBase * 0.22 + dsmfExcess * 0.15;

    final double employeeUnemployment = grossSalary * 0.005;
    final double employerUnemployment = grossSalary * 0.005;

    final double healthBase = grossSalary.clamp(0, _healthCeiling).toDouble();
    final double healthExcess =
        (grossSalary - _healthCeiling) < 0 ? 0 : grossSalary - _healthCeiling;
    final double employeeHealth = healthBase * 0.02 + healthExcess * 0.005;
    final double employerHealth = healthBase * 0.02 + healthExcess * 0.005;

    return PayrollResult(
      grossSalary: grossSalary,
      taxableIncome: taxableIncome,
      incomeTax: incomeTax,
      employeeDsmf: employeeDsmf,
      employerDsmf: employerDsmf,
      employeeUnemployment: employeeUnemployment,
      employerUnemployment: employerUnemployment,
      employeeHealthInsurance: employeeHealth,
      employerHealthInsurance: employerHealth,
    );
  }

  /// Inverts the statutory calculation to recover the gross salary that
  /// yields [netSalary] for the given [sector].
  PayrollResult netToGross({
    required double netSalary,
    required SectorType sector,
  }) {
    if (netSalary <= _epsilon) {
      return grossToNet(grossSalary: 0, sector: sector);
    }
    double gross = netSalary;
    for (int iteration = 0; iteration < 200; iteration++) {
      final PayrollResult candidate = grossToNet(
        grossSalary: gross,
        sector: sector,
      );
      final double difference = candidate.netSalary - netSalary;
      if (difference.abs() <= 0.01) {
        return candidate;
      }
      gross -= difference;
      if (gross < 0) {
        gross = 0;
      }
    }
    return grossToNet(grossSalary: gross, sector: sector);
  }

  /// Builds the three balancing journal lines that record an approved
  /// employee payroll record: gross salary expense, employee withholdings,
  /// and employer social contributions.
  List<PayrollJournalEntry> buildPostingPlan({
    required EmployeeEntity employee,
    required PayrollRecordEntity record,
    required DateTime entryDate,
  }) {
    return <PayrollJournalEntry>[
      PayrollJournalEntry(
        companyId: record.companyId,
        entryDate: entryDate,
        description: 'Gross salary for ${employee.fullName} '
            '(${record.periodYear}-${record.periodMonth})',
        debitAccount: salariesExpenseAccount,
        creditAccount: netPayableAccount,
        amount: record.grossSalary,
        sourceType: 'payroll',
        sourceId: record.id,
      ),
      PayrollJournalEntry(
        companyId: record.companyId,
        entryDate: entryDate,
        description: 'Employee withholdings for ${employee.fullName}',
        debitAccount: netPayableAccount,
        creditAccount: taxPayableAccount,
        amount: record.totalEmployeeWithholdings,
        sourceType: 'payroll',
        sourceId: record.id,
      ),
      PayrollJournalEntry(
        companyId: record.companyId,
        entryDate: entryDate,
        description: 'Employer social contributions for ${employee.fullName}',
        debitAccount: salariesExpenseAccount,
        creditAccount: taxPayableAccount,
        amount: record.totalEmployerContributions,
        sourceType: 'payroll',
        sourceId: record.id,
      ),
    ];
  }

  double _taxableIncome(double grossSalary, SectorType sector) {
    switch (sector) {
      case SectorType.nonOilGasPrivate:
        return (grossSalary - _socialCeiling) < 0
            ? 0
            : grossSalary - _socialCeiling;
      case SectorType.oilGasPrivate:
      case SectorType.stateBudget:
        return grossSalary;
    }
  }

  double _incomeTaxRate(SectorType sector) {
    switch (sector) {
      case SectorType.nonOilGasPrivate:
      case SectorType.stateBudget:
        return 0.14;
      case SectorType.oilGasPrivate:
        return 0.25;
    }
  }
}
