import 'package:equatable/equatable.dart';

import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/payroll_record_entity.dart';

abstract class PayrollState extends Equatable {
  const PayrollState();

  @override
  List<Object?> get props => const <Object?>[];
}

class PayrollInitial extends PayrollState {
  const PayrollInitial();
}

class PayrollLoading extends PayrollState {
  const PayrollLoading();
}

class EmployeesLoaded extends PayrollState {
  const EmployeesLoaded({required this.employees});

  final List<EmployeeEntity> employees;

  @override
  List<Object?> get props => <Object?>[employees];
}

class PayrollBatchCalculated extends PayrollState {
  const PayrollBatchCalculated({
    required this.employees,
    required this.records,
    required this.message,
  });

  final List<EmployeeEntity> employees;
  final List<PayrollRecordEntity> records;
  final String message;

  @override
  List<Object?> get props => <Object?>[employees, records, message];
}

class PayrollPostedSuccess extends PayrollState {
  const PayrollPostedSuccess({
    required this.employees,
    required this.records,
    required this.message,
  });

  final List<EmployeeEntity> employees;
  final List<PayrollRecordEntity> records;
  final String message;

  @override
  List<Object?> get props => <Object?>[employees, records, message];
}

class PayrollError extends PayrollState {
  const PayrollError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
