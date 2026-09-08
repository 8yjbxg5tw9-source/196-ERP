import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/payroll_record_entity.dart';
import '../../domain/repositories/payroll_repository.dart';
import 'payroll_event.dart';
import 'payroll_state.dart';

/// Coordinates the employee directory, batch payroll calculation, and the
/// approval/posting flow.
class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  PayrollBloc({required PayrollRepository repository})
      : _repository = repository,
        super(const PayrollInitial()) {
    on<LoadEmployeesEvent>(_onLoadEmployees);
    on<AddEmployeeEvent>(_onAddEmployee);
    on<CalculateBatchPayrollEvent>(_onCalculate);
    on<ApproveAndPostPayrollEvent>(_onApproveAndPost);
  }

  final PayrollRepository _repository;

  Future<void> _onLoadEmployees(
    LoadEmployeesEvent event,
    Emitter<PayrollState> emit,
  ) async {
    emit(const PayrollLoading());
    final result = await _repository.getEmployees(event.companyId);
    result.fold(
      (failure) => emit(PayrollError(failure.message)),
      (employees) => emit(EmployeesLoaded(employees: employees)),
    );
  }

  Future<void> _onAddEmployee(
    AddEmployeeEvent event,
    Emitter<PayrollState> emit,
  ) async {
    final result = await _repository.addEmployee(event.employee);
    await result.fold(
      (failure) async => emit(PayrollError(failure.message)),
      (employee) async {
        final employeesResult = await _repository.getEmployees(
          employee.companyId,
        );
        employeesResult.fold(
          (failure) => emit(PayrollError(failure.message)),
          (employees) => emit(EmployeesLoaded(employees: employees)),
        );
      },
    );
  }

  Future<void> _onCalculate(
    CalculateBatchPayrollEvent event,
    Emitter<PayrollState> emit,
  ) async {
    emit(const PayrollLoading());
    final result = await _repository.calculateBatchPayroll(
      companyId: event.companyId,
      periodMonth: event.periodMonth,
      periodYear: event.periodYear,
    );
    await result.fold(
      (failure) async => emit(PayrollError(failure.message)),
      (records) async {
        final employeesResult = await _repository.getEmployees(event.companyId);
        employeesResult.fold(
          (failure) => emit(PayrollError(failure.message)),
          (employees) => emit(
            PayrollBatchCalculated(
              employees: employees,
              records: records,
              message: 'Calculated ${records.length} payroll record(s) '
                  'for ${event.periodMonth}/${event.periodYear}.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _onApproveAndPost(
    ApproveAndPostPayrollEvent event,
    Emitter<PayrollState> emit,
  ) async {
    emit(const PayrollLoading());
    final result = await _repository.approveAndPostPayroll(
      companyId: event.companyId,
      periodMonth: event.periodMonth,
      periodYear: event.periodYear,
    );
    await result.fold(
      (failure) async => emit(PayrollError(failure.message)),
      (records) async {
        final employeesResult = await _repository.getEmployees(event.companyId);
        employeesResult.fold(
          (failure) => emit(PayrollError(failure.message)),
          (employees) => emit(
            PayrollPostedSuccess(
              employees: employees,
              records: records,
              message: 'Approved and posted ${records.length} payroll '
                  'record(s).',
            ),
          ),
        );
      },
    );
  }
}
