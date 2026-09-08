import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/payroll_record_entity.dart';
import '../bloc/payroll_bloc.dart';
import '../bloc/payroll_event.dart';
import '../bloc/payroll_state.dart';

/// Enterprise payroll workspace: employee directory, batch calculation, and
/// approval/posting with a payslip preview grid.
class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<PayrollBloc>(
          create: (_) => sl<PayrollBloc>(),
          child: _PayrollWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _PayrollWorkspace extends StatefulWidget {
  const _PayrollWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_PayrollWorkspace> createState() => _PayrollWorkspaceState();
}

class _PayrollWorkspaceState extends State<_PayrollWorkspace> {
  int _periodMonth = DateTime.now().month;
  int _periodYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _dispatchLoadIfReady();
  }

  @override
  void didUpdateWidget(covariant _PayrollWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _dispatchLoadIfReady();
    }
  }

  void _dispatchLoadIfReady() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<PayrollBloc>().add(LoadEmployeesEvent(companyId));
  }

  String get _companyId => widget.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openNewEmployee,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
            label: const Text('Add Employee'),
          ),
          const SizedBox(width: 8),
          _buildPeriodDropdown(),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _calculateBatch,
            icon: const Icon(Icons.calculate_outlined, size: 17),
            label: const Text('Calculate Batch'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _approveAndPost,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
            label: const Text('Approve & Post'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<PayrollBloc, PayrollState>(
        listener: (BuildContext context, PayrollState state) {
          if (state is PayrollBatchCalculated ||
              state is PayrollPostedSuccess) {
            final String message = state is PayrollBatchCalculated
                ? state.message
                : (state as PayrollPostedSuccess).message;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is PayrollError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, PayrollState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.groups_outlined,
              title: 'Select an active company',
              message: 'Payroll is scoped to the active company.',
            );
          }
          if (state is PayrollLoading || state is PayrollInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PayrollError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Payroll unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchLoadIfReady,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }

          final List<EmployeeEntity> employees = state is EmployeesLoaded
              ? state.employees
              : state is PayrollBatchCalculated
                    ? state.employees
                    : state is PayrollPostedSuccess
                          ? state.employees
                          : const <EmployeeEntity>[];
          final List<PayrollRecordEntity> records = state is PayrollBatchCalculated
              ? state.records
              : state is PayrollPostedSuccess
                    ? state.records
                    : const <PayrollRecordEntity>[];

          return _PayrollWorkspaceBody(
            employees: employees,
            records: records,
            onNewEmployee: _openNewEmployee,
            onRecordSelected: _openPayslip,
          );
        },
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _periodMonth,
        icon: const Icon(Icons.arrow_drop_down_rounded),
        style: Theme.of(context).textTheme.bodyMedium,
        items: <DropdownMenuItem<int>>[
          for (int month = 1; month <= 12; month++)
            DropdownMenuItem<int>(
              value: month,
              child: Text(_monthName(month)),
            ),
        ],
        onChanged: (int? value) {
          if (value != null) {
            setState(() => _periodMonth = value);
          }
        },
      ),
    );
  }

  void _openNewEmployee() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    final PayrollBloc bloc = context.read<PayrollBloc>();
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _NewEmployeeDialog(
        companyId: _companyId,
        bloc: bloc,
      ),
    ).then((_) {
      if (mounted) {
        _dispatchLoadIfReady();
      }
    });
  }

  void _calculateBatch() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    context.read<PayrollBloc>().add(
          CalculateBatchPayrollEvent(
            companyId: _companyId,
            periodMonth: _periodMonth,
            periodYear: _periodYear,
          ),
        );
  }

  void _approveAndPost() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    context.read<PayrollBloc>().add(
          ApproveAndPostPayrollEvent(
            companyId: _companyId,
            periodMonth: _periodMonth,
            periodYear: _periodYear,
          ),
        );
  }

  void _openPayslip(PayrollRecordEntity record) {
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _PayslipDialog(record: record),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static String _monthName(int month) {
    const List<String> names = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

class _PayrollWorkspaceBody extends StatelessWidget {
  const _PayrollWorkspaceBody({
    required this.employees,
    required this.records,
    required this.onNewEmployee,
    required this.onRecordSelected,
  });

  final List<EmployeeEntity> employees;
  final List<PayrollRecordEntity> records;
  final VoidCallback onNewEmployee;
  final void Function(PayrollRecordEntity record) onRecordSelected;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return _WorkspaceMessage(
        icon: Icons.groups_outlined,
        title: 'No employees yet',
        message: 'Add your first employee to begin payroll processing.',
        action: FilledButton.icon(
          onPressed: onNewEmployee,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
          label: const Text('Add Employee'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildDirectory(context),
          if (records.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            _buildBatchGrid(context),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectory(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll<Color>(
            theme.colorScheme.surfaceContainerHighest.withAlpha(70),
          ),
          columns: const <DataColumn>[
            DataColumn(label: Text('PIN')),
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Position')),
            DataColumn(label: Text('Sector')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Base Salary'), numeric: true),
          ],
          rows: <DataRow>[
            for (final EmployeeEntity employee in employees)
              _buildEmployeeRow(context, employee),
          ],
        ),
      ),
    );
  }

  DataRow _buildEmployeeRow(BuildContext context, EmployeeEntity employee) {
    final ThemeData theme = Theme.of(context);
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(employee.pin)),
        DataCell(
          Tooltip(
            message: employee.fullName,
            child: Text(
              employee.fullName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Text(
            employee.position.isEmpty ? '—' : employee.position,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DataCell(Text(employee.sectorType.label)),
        DataCell(Text(employee.employmentType.label)),
        DataCell(
          Text(
            AppFormatters.decimal(employee.baseSalary),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchGrid(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              'Payroll Batch · ${records.first.periodMonth}/${records.first.periodYear}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll<Color>(
                theme.colorScheme.surfaceContainerHighest.withAlpha(70),
              ),
              columns: const <DataColumn>[
                DataColumn(label: Text('Employee')),
                DataColumn(label: Text('Gross'), numeric: true),
                DataColumn(label: Text('Income Tax'), numeric: true),
                DataColumn(label: Text('DSMF (Emp.)'), numeric: true),
                DataColumn(label: Text('DSMF (Er.)'), numeric: true),
                DataColumn(label: Text('Health'), numeric: true),
                DataColumn(label: Text('Net Salary'), numeric: true),
                DataColumn(label: Text('Employer Cost'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: <DataRow>[
                for (final PayrollRecordEntity record in records)
                  DataRow(
                    onSelectChanged: (_) => onRecordSelected(record),
                    cells: <DataCell>[
                      DataCell(Text(record.employeeId)),
                      DataCell(Text(AppFormatters.decimal(record.grossSalary))),
                      DataCell(Text(AppFormatters.decimal(record.incomeTax))),
                      DataCell(Text(AppFormatters.decimal(record.employeeDsmf))),
                      DataCell(Text(AppFormatters.decimal(record.employerDsmf))),
                      DataCell(
                        Text(
                          AppFormatters.decimal(record.employeeHealthInsurance),
                        ),
                      ),
                      DataCell(
                        Text(
                          AppFormatters.decimal(record.netSalary),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(AppFormatters.decimal(record.totalEmployerCost)),
                      ),
                      DataCell(
                        Text(
                          record.isApproved ? 'Posted' : 'Draft',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: record.isApproved
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewEmployeeDialog extends StatefulWidget {
  const _NewEmployeeDialog({required this.companyId, required this.bloc});

  final String companyId;
  final PayrollBloc bloc;

  @override
  State<_NewEmployeeDialog> createState() => _NewEmployeeDialogState();
}

class _NewEmployeeDialogState extends State<_NewEmployeeDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _position = TextEditingController();
  final TextEditingController _salary = TextEditingController();
  final TextEditingController _iban = TextEditingController();
  final TextEditingController _startDate = TextEditingController(
    text: _defaultDate(),
  );
  EmploymentType _employmentType = EmploymentType.fullTime;
  SectorType _sectorType = SectorType.nonOilGasPrivate;

  static String _defaultDate() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _position.dispose();
    _salary.dispose();
    _iban.dispose();
    _startDate.dispose();
    super.dispose();
  }

  bool get _canSave {
    final double salary = double.tryParse(_salary.text.trim()) ?? -1;
    final DateTime? date = DateTime.tryParse(_startDate.text.trim());
    return _name.text.trim().isNotEmpty &&
        _pin.text.trim().isNotEmpty &&
        salary >= 0 &&
        date != null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New employee'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Full name',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _pin,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'PIN',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _position,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Position',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _salary,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Base salary (AZN)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _startDate,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Start date (yyyy-mm-dd)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _iban,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Bank IBAN (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<SectorType>(
                      value: _sectorType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Sector',
                      ),
                      items: <DropdownMenuItem<SectorType>>[
                        for (final SectorType sector in SectorType.values)
                          DropdownMenuItem<SectorType>(
                            value: sector,
                            child: Text(sector.label),
                          ),
                      ],
                      onChanged: (SectorType? value) {
                        if (value != null) {
                          setState(() => _sectorType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<EmploymentType>(
                      value: _employmentType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Type',
                      ),
                      items: <DropdownMenuItem<EmploymentType>>[
                        for (final EmploymentType type in EmploymentType.values)
                          DropdownMenuItem<EmploymentType>(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: (EmploymentType? value) {
                        if (value != null) {
                          setState(() => _employmentType = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () {
                  widget.bloc.add(
                    AddEmployeeEvent(
                      EmployeeEntity(
                        id: '',
                        companyId: widget.companyId,
                        fullName: _name.text.trim(),
                        pin: _pin.text.trim(),
                        position: _position.text.trim(),
                        baseSalary:
                            double.tryParse(_salary.text.trim()) ?? 0,
                        employmentType: _employmentType,
                        sectorType: _sectorType,
                        bankAccountIban: _iban.text.trim().isEmpty
                            ? null
                            : _iban.text.trim(),
                        startDate: DateTime.parse(_startDate.text.trim()),
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PayslipDialog extends StatelessWidget {
  const _PayslipDialog({required this.record});

  final PayrollRecordEntity record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Payslip preview'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _line(context, 'Gross salary', record.grossSalary),
            _line(context, 'Taxable income', record.taxableIncome),
            const Divider(height: 18),
            _line(context, 'Income tax', record.incomeTax, deduct: true),
            _line(context, 'Employee DSMF', record.employeeDsmf, deduct: true),
            _line(
              context,
              'Unemployment (employee)',
              record.employeeUnemployment,
              deduct: true,
            ),
            _line(
              context,
              'Health insurance (employee)',
              record.employeeHealthInsurance,
              deduct: true,
            ),
            const Divider(height: 18),
            _line(
              context,
              'Net salary',
              record.netSalary,
              emphasis: true,
            ),
            const SizedBox(height: 8),
            _line(context, 'Employer DSMF', record.employerDsmf),
            _line(
              context,
              'Unemployment (employer)',
              record.employerUnemployment,
            ),
            _line(
              context,
              'Health insurance (employer)',
              record.employerHealthInsurance,
            ),
            const Divider(height: 18),
            _line(
              context,
              'Total employer cost',
              record.totalEmployerCost,
              emphasis: true,
            ),
            const SizedBox(height: 12),
            Text(
              record.isApproved ? 'Status: Posted' : 'Status: Draft',
              style: theme.textTheme.labelSmall?.copyWith(
                color: record.isApproved ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    double value, {
    bool deduct = false,
    bool emphasis = false,
  }) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            '${deduct ? '−' : ''}${AppFormatters.decimal(value)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: emphasis ? FontWeight.w900 : FontWeight.w600,
              color: emphasis ? theme.colorScheme.onSurface : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
