import 'package:equatable/equatable.dart';

import '../../domain/entities/employee_entity.dart';

abstract class PayrollEvent extends Equatable {
  const PayrollEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadEmployeesEvent extends PayrollEvent {
  const LoadEmployeesEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class AddEmployeeEvent extends PayrollEvent {
  const AddEmployeeEvent(this.employee);

  final EmployeeEntity employee;

  @override
  List<Object?> get props => <Object?>[employee];
}

class CalculateBatchPayrollEvent extends PayrollEvent {
  const CalculateBatchPayrollEvent({
    required this.companyId,
    required this.periodMonth,
    required this.periodYear,
  });

  final String companyId;
  final int periodMonth;
  final int periodYear;

  @override
  List<Object?> get props => <Object?>[companyId, periodMonth, periodYear];
}

class ApproveAndPostPayrollEvent extends PayrollEvent {
  const ApproveAndPostPayrollEvent({
    required this.companyId,
    required this.periodMonth,
    required this.periodYear,
  });

  final String companyId;
  final int periodMonth;
  final int periodYear;

  @override
  List<Object?> get props => <Object?>[companyId, periodMonth, periodYear];
}
