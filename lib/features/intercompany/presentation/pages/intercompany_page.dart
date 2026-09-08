import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../company/presentation/bloc/company_bloc.dart';
import '../../../company/presentation/bloc/company_state.dart';
import '../../domain/entities/dividend_distribution_entity.dart';
import '../../domain/entities/intercompany_loan_entity.dart';
import '../bloc/intercompany_bloc.dart';
import '../bloc/intercompany_event.dart';
import '../bloc/intercompany_state.dart';

/// Multi-entity intercompany workspace: loan agreements, interest accruals,
/// and dividend declarations with reciprocal journal posting.
class IntercompanyPage extends StatelessWidget {
  const IntercompanyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IntercompanyBloc>(
      create: (_) => sl<IntercompanyBloc>(),
      child: const _IntercompanyWorkspace(),
    );
  }
}

class _IntercompanyWorkspace extends StatefulWidget {
  const _IntercompanyWorkspace();

  @override
  State<_IntercompanyWorkspace> createState() => _IntercompanyWorkspaceState();
}

class _IntercompanyWorkspaceState extends State<_IntercompanyWorkspace> {
  @override
  void initState() {
    super.initState();
    context.read<IntercompanyBloc>().add(const LoadIntercompanyAgreementsEvent());
  }

  List<CompanyEntity> get _companies {
    final CompanyState state = context.read<CompanyBloc>().state;
    return state is CompaniesLoaded
        ? state.companies
        : const <CompanyEntity>[];
  }

  String _nameOf(String companyId) {
    for (final CompanyEntity company in _companies) {
      if (company.id == companyId) {
        return company.name;
      }
    }
    return companyId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intercompany & Dividends'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openNewLoan,
            icon: const Icon(Icons.handshake_outlined, size: 17),
            label: const Text('New Loan'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openDividendWizard,
            icon: const Icon(Icons.payments_outlined, size: 17),
            label: const Text('Declare Dividend'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _runAccrual,
            icon: const Icon(Icons.event_repeat_rounded, size: 17),
            label: const Text('Run Interest Accrual'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<IntercompanyBloc, IntercompanyState>(
        listener: (BuildContext context, IntercompanyState state) {
          if (state is AccrualExecutionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Interest accrual complete — ${state.journalLineCount} '
                  'journal lines posted across entities.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is IntercompanyError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, IntercompanyState state) {
          if (state is IntercompanyLoading || state is IntercompanyInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is IntercompanyError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Intercompany workspace unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: () => context
                    .read<IntercompanyBloc>()
                    .add(const LoadIntercompanyAgreementsEvent()),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }

          final List<IntercompanyLoanEntity> loans = state is AgreementsLoaded
              ? state.loans
              : state is AccrualExecutionSuccess
                    ? state.loans
                    : const <IntercompanyLoanEntity>[];
          final List<DividendDistributionEntity> dividends =
              state is AgreementsLoaded
                  ? state.dividends
                  : state is AccrualExecutionSuccess
                        ? state.dividends
                        : const <DividendDistributionEntity>[];

          return _buildContent(context, loans, dividends);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<IntercompanyLoanEntity> loans,
    List<DividendDistributionEntity> dividends,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LoanMatrix(loans: loans, nameOf: _nameOf),
          const SizedBox(height: 16),
          _DividendList(dividends: dividends, nameOf: _nameOf),
        ],
      ),
    );
  }

  void _openNewLoan() {
    final List<CompanyEntity> companies = _companies;
    if (companies.length < 2) {
      _showSnack('Create at least two companies first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _NewLoanDialog(companies: companies),
    ).then((_) {
      if (mounted) {
        context
            .read<IntercompanyBloc>()
            .add(const LoadIntercompanyAgreementsEvent());
      }
    });
  }

  void _openDividendWizard() {
    final List<CompanyEntity> companies = _companies;
    if (companies.length < 2) {
      _showSnack('Create at least two companies first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _DividendWizard(companies: companies),
    ).then((_) {
      if (mounted) {
        context
            .read<IntercompanyBloc>()
            .add(const LoadIntercompanyAgreementsEvent());
      }
    });
  }

  void _runAccrual() {
    context
        .read<IntercompanyBloc>()
        .add(const RunMonthlyInterestAccrualEvent(days: 30));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _LoanMatrix extends StatelessWidget {
  const _LoanMatrix({required this.loans, required this.nameOf});

  final List<IntercompanyLoanEntity> loans;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Agreement Overview',
      icon: Icons.account_balance_outlined,
      child: loans.isEmpty
          ? Text(
              'No intercompany loans yet. Create a loan agreement to begin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Lender')),
                  DataColumn(label: Text('Borrower')),
                  DataColumn(label: Text('Principal'), numeric: true),
                  DataColumn(label: Text('Rate'), numeric: true),
                  DataColumn(label: Text('WHT'), numeric: true),
                  DataColumn(label: Text('Accrued Interest'), numeric: true),
                  DataColumn(label: Text('Net Balance'), numeric: true),
                  DataColumn(label: Text('Status')),
                ],
                rows: <DataRow>[
                  for (final IntercompanyLoanEntity loan in loans)
                    _loanRow(context, loan),
                ],
              ),
            ),
    );
  }

  DataRow _loanRow(BuildContext context, IntercompanyLoanEntity loan) {
    final ThemeData theme = Theme.of(context);
    final double accumulatedInterest =
        loan.outstandingBalance - loan.principalAmount;
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(nameOf(loan.lenderCompanyId))),
        DataCell(Text(nameOf(loan.borrowerCompanyId))),
        DataCell(Text(AppFormatters.decimal(loan.principalAmount))),
        DataCell(Text('${loan.interestRate.toStringAsFixed(2)}%')),
        DataCell(Text('${loan.withholdingTaxRate.toStringAsFixed(2)}%')),
        DataCell(Text(AppFormatters.decimal(accumulatedInterest))),
        DataCell(
          Text(
            AppFormatters.decimal(loan.outstandingBalance),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: loan.status == LoanStatus.active
                  ? AppColors.success.withAlpha(22)
                  : loan.status == LoanStatus.settled
                        ? AppColors.primary.withAlpha(22)
                        : AppColors.error.withAlpha(22),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              loan.status.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: loan.status == LoanStatus.active
                    ? AppColors.success
                    : loan.status == LoanStatus.settled
                          ? AppColors.primary
                          : AppColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DividendList extends StatelessWidget {
  const _DividendList({required this.dividends, required this.nameOf});

  final List<DividendDistributionEntity> dividends;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Dividend Distributions',
      icon: Icons.payments_outlined,
      child: dividends.isEmpty
          ? Text(
              'No dividends declared yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Distributor')),
                  DataColumn(label: Text('Recipient')),
                  DataColumn(label: Text('Declared'), numeric: true),
                  DataColumn(label: Text('WHT'), numeric: true),
                  DataColumn(label: Text('Net Paid'), numeric: true),
                  DataColumn(label: Text('Date')),
                ],
                rows: <DataRow>[
                  for (final DividendDistributionEntity dividend in dividends)
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text(nameOf(dividend.distributingCompanyId))),
                        DataCell(Text(nameOf(dividend.recipientEntityId))),
                        DataCell(Text(AppFormatters.decimal(dividend.declaredAmount))),
                        DataCell(Text(AppFormatters.decimal(dividend.withholdingTax))),
                        DataCell(Text(AppFormatters.decimal(dividend.netDividendPaid))),
                        DataCell(Text(AppFormatters.date(dividend.declarationDate))),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NewLoanDialog extends StatefulWidget {
  const _NewLoanDialog({required this.companies});

  final List<CompanyEntity> companies;

  @override
  State<_NewLoanDialog> createState() => _NewLoanDialogState();
}

class _NewLoanDialogState extends State<_NewLoanDialog> {
  String? _lenderId;
  String? _borrowerId;
  final TextEditingController _principal = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _wht = TextEditingController(text: '10');
  CompoundingFrequency _frequency = CompoundingFrequency.simple;
  DateTime _agreementDate = DateTime.now();
  DateTime _maturityDate = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _wht.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _lenderId != null &&
      _borrowerId != null &&
      _lenderId != _borrowerId &&
      (double.tryParse(_principal.text.trim()) ?? 0) > 0 &&
      (double.tryParse(_rate.text.trim()) ?? 0) >= 0;

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New intercompany loan'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _lenderId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Lender',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final CompanyEntity company in widget.companies)
                    DropdownMenuItem<String>(
                      value: company.id,
                      child: Text(company.name),
                    ),
                ],
                onChanged: (String? value) => setState(() => _lenderId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _borrowerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Borrower',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final CompanyEntity company in widget.companies)
                    DropdownMenuItem<String>(
                      value: company.id,
                      child: Text(company.name),
                    ),
                ],
                onChanged: (String? value) => setState(() => _borrowerId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _principal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Principal amount',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Annual interest rate (%)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _wht,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Withholding tax rate (%)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CompoundingFrequency>(
                value: _frequency,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Compounding',
                ),
                items: <DropdownMenuItem<CompoundingFrequency>>[
                  for (final CompoundingFrequency frequency
                      in CompoundingFrequency.values)
                    DropdownMenuItem<CompoundingFrequency>(
                      value: frequency,
                      child: Text(frequency.label),
                    ),
                ],
                onChanged: (CompoundingFrequency? value) {
                  if (value != null) {
                    setState(() => _frequency = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _agreementDate,
                        onPicked: (DateTime value) =>
                            setState(() => _agreementDate = value),
                      ),
                      child: Text(
                        'From ${AppFormatters.date(_agreementDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _maturityDate,
                        onPicked: (DateTime value) =>
                            setState(() => _maturityDate = value),
                      ),
                      child: Text(
                        'To ${AppFormatters.date(_maturityDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  context.read<IntercompanyBloc>().add(
                        CreateLoanAgreementEvent(
                          IntercompanyLoanEntity(
                            id: '',
                            lenderCompanyId: _lenderId!,
                            borrowerCompanyId: _borrowerId!,
                            principalAmount:
                                double.tryParse(_principal.text.trim()) ?? 0,
                            interestRate:
                                double.tryParse(_rate.text.trim()) ?? 0,
                            agreementDate: _agreementDate,
                            maturityDate: _maturityDate,
                            compoundingFrequency: _frequency,
                            withholdingTaxRate:
                                double.tryParse(_wht.text.trim()) ?? 0,
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

class _DividendWizard extends StatefulWidget {
  const _DividendWizard({required this.companies});

  final List<CompanyEntity> companies;

  @override
  State<_DividendWizard> createState() => _DividendWizardState();
}

class _DividendWizardState extends State<_DividendWizard> {
  String? _distributorId;
  String? _recipientId;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _taxRate = TextEditingController(text: '5');
  DateTime _declarationDate = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _distributorId != null &&
      _recipientId != null &&
      _distributorId != _recipientId &&
      (double.tryParse(_amount.text.trim()) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final double declared = double.tryParse(_amount.text.trim()) ?? 0;
    final double taxRate = double.tryParse(_taxRate.text.trim()) ?? 0;
    final double tax = declared * taxRate / 100;
    final double net = declared - tax;
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Declare dividend'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _distributorId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Distributing entity',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final CompanyEntity company in widget.companies)
                    DropdownMenuItem<String>(
                      value: company.id,
                      child: Text(company.name),
                    ),
                ],
                onChanged: (String? value) =>
                    setState(() => _distributorId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _recipientId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Recipient entity',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final CompanyEntity company in widget.companies)
                    DropdownMenuItem<String>(
                      value: company.id,
                      child: Text(company.name),
                    ),
                ],
                onChanged: (String? value) => setState(() => _recipientId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Declared amount',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _taxRate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Dividend tax rate (%)',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _summaryLine('Gross declared', declared),
                    _summaryLine('Withholding tax', tax),
                    _summaryLine('Net dividend paid', net),
                  ],
                ),
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
                  context.read<IntercompanyBloc>().add(
                        DeclareDividendEvent(
                          DividendDistributionEntity(
                            id: '',
                            distributingCompanyId: _distributorId!,
                            recipientEntityId: _recipientId!,
                            declaredAmount: declared,
                            dividendTaxRate: taxRate,
                            declarationDate: _declarationDate,
                          ),
                        ),
                      );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Declare & Post'),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, double value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            AppFormatters.decimal(value),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
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
