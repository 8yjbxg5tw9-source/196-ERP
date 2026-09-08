import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../data/tax_xml_file_exporter.dart';
import '../../domain/entities/tax_declaration_entity.dart';
import '../../domain/entities/xml_validation_issue.dart';
import '../bloc/tax_declaration_bloc.dart';
import '../bloc/tax_declaration_event.dart';
import '../bloc/tax_declaration_state.dart';

/// Statutory e-filing exporter workspace: compile ledger data into an
/// e-Bəyannamə XML declaration, validate it, preview it, and save the `.xml`.
class TaxDeclarationPage extends StatelessWidget {
  const TaxDeclarationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<TaxDeclarationBloc>(
          create: (_) => sl<TaxDeclarationBloc>(),
          child: _TaxDeclarationWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _TaxDeclarationWorkspace extends StatefulWidget {
  const _TaxDeclarationWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_TaxDeclarationWorkspace> createState() =>
      _TaxDeclarationWorkspaceState();
}

class _TaxDeclarationWorkspaceState extends State<_TaxDeclarationWorkspace> {
  TaxDeclarationType _type = TaxDeclarationType.vat2026;
  late int _year = DateTime.now().year;
  late int _period = _defaultPeriodFor(_type.defaultPeriod);
  String? _fetchedCompanyId;

  TaxDeclarationEntity? _declaration;
  List<XmlValidationIssue> _issues = const <XmlValidationIssue>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? companyId = widget.companyId;
    if (_fetchedCompanyId != companyId) {
      _fetchedCompanyId = companyId;
      _declaration = null;
      _issues = const <XmlValidationIssue>[];
      _compile();
    }
  }

  static int _defaultPeriodFor(TaxPeriod period) {
    final DateTime now = DateTime.now();
    switch (period) {
      case TaxPeriod.monthly:
        return now.month;
      case TaxPeriod.quarterly:
        return (now.month - 1) ~/ 3 + 1;
      case TaxPeriod.annual:
        return 1;
    }
  }

  void _compile() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<TaxDeclarationBloc>().add(
          CompileDeclarationEvent(
            companyId: companyId,
            type: _type,
            year: _year,
            period: _period,
          ),
        );
  }

  void _save() {
    context.read<TaxDeclarationBloc>().add(const ExportXmlFileEvent());
  }

  Future<void> _saveAs() async {
    final TaxDeclarationEntity? declaration = _declaration;
    if (declaration == null) {
      return;
    }
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save XML declaration',
      fileName: TaxXmlFileExporter.fileNameFor(declaration),
      type: FileType.custom,
      allowedExtensions: const <String>['xml'],
    );
    if (path == null || !mounted) {
      return;
    }
    context.read<TaxDeclarationBloc>().add(ExportXmlFileEvent(path));
  }

  Future<void> _copyXml() async {
    final String? xml = _declaration?.rawXmlOutput;
    if (xml == null || xml.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: xml));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('XML copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onTypeChanged(TaxDeclarationType type) {
    setState(() {
      _type = type;
      _period = _defaultPeriodFor(type.defaultPeriod);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Filing Exporter'),
        actions: <Widget>[
          FilledButton.icon(
            onPressed: widget.companyId == null ? null : _compile,
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: const Text('Compile Declaration'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<TaxDeclarationBloc, TaxDeclarationState>(
        listener: (BuildContext context, TaxDeclarationState state) {
          if (state is DeclarationCompiled) {
            _declaration = state.declaration;
            _issues = state.issues;
          } else if (state is XmlExportSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Declaration saved: ${state.filePath}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is DeclarationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, TaxDeclarationState state) {
          return Column(
            children: <Widget>[
              _SelectorCard(
                type: _type,
                year: _year,
                period: _period,
                onTypeChanged: _onTypeChanged,
                onYearChanged: (int value) => setState(() => _year = value),
                onPeriodChanged: (int value) =>
                    setState(() => _period = value),
              ),
              if (state is DeclarationLoading)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, TaxDeclarationState state) {
    if (widget.companyId == null) {
      return const _WorkspaceMessage(
        icon: Icons.business_outlined,
        title: 'Select an active company',
        message: 'Tax filing is scoped to the active company.',
      );
    }

    if (state is DeclarationLoading && _declaration == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final TaxDeclarationEntity? declaration = _declaration;
    if (declaration == null) {
      return _WorkspaceMessage(
        icon: state is DeclarationError
            ? Icons.error_outline_rounded
            : Icons.description_outlined,
        title: state is DeclarationError
            ? 'Compilation failed'
            : 'No declaration compiled',
        message: state is DeclarationError
            ? state.message
            : 'Choose a form, year, and period, then click '
                '"Compile Declaration".',
        action: FilledButton.icon(
          onPressed: _compile,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Compile'),
        ),
      );
    }

    return _DeclarationView(
      declaration: declaration,
      issues: _issues,
      onCopy: _copyXml,
      onSave: _save,
      onSaveAs: _saveAs,
    );
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.type,
    required this.year,
    required this.period,
    required this.onTypeChanged,
    required this.onYearChanged,
    required this.onPeriodChanged,
  });

  final TaxDeclarationType type;
  final int year;
  final int period;
  final ValueChanged<TaxDeclarationType> onTypeChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int currentYear = DateTime.now().year;
    final List<int> years = <int>[
      for (int y = currentYear - 2; y <= currentYear + 1; y++) y,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          DropdownButton<TaxDeclarationType>(
            value: type,
            items: <DropdownMenuItem<TaxDeclarationType>>[
              for (final TaxDeclarationType value in TaxDeclarationType.values)
                DropdownMenuItem<TaxDeclarationType>(
                  value: value,
                  child: Text(value.label),
                ),
            ],
            onChanged: (TaxDeclarationType? value) {
              if (value != null) {
                onTypeChanged(value);
              }
            },
          ),
          DropdownButton<int>(
            value: years.contains(year) ? year : currentYear,
            items: <DropdownMenuItem<int>>[
              for (final int y in years)
                DropdownMenuItem<int>(value: y, child: Text('$y')),
            ],
            onChanged: (int? value) {
              if (value != null) {
                onYearChanged(value);
              }
            },
          ),
          _PeriodDropdown(
            period: type.defaultPeriod,
            value: period,
            onChanged: onPeriodChanged,
          ),
          const SizedBox(width: 4),
          Text(
            type.defaultPeriod.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.period,
    required this.value,
    required this.onChanged,
  });

  final TaxPeriod period;
  final int value;
  final ValueChanged<int> onChanged;

  static const List<String> _months = <String>[
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

  @override
  Widget build(BuildContext context) {
    final List<(int, String)> options = _options();
    final bool containsValue = options.any(
      ((int, String) option) => option.$1 == value,
    );
    return DropdownButton<int>(
      value: containsValue ? value : options.first.$1,
      items: <DropdownMenuItem<int>>[
        for (final (int, String) option in options)
          DropdownMenuItem<int>(value: option.$1, child: Text(option.$2)),
      ],
      onChanged: (int? selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  List<(int, String)> _options() {
    switch (period) {
      case TaxPeriod.monthly:
        return <(int, String)>[
          for (int month = 1; month <= 12; month++)
            (month, _months[month - 1]),
        ];
      case TaxPeriod.quarterly:
        return const <(int, String)>[
          (1, 'Q1'),
          (2, 'Q2'),
          (3, 'Q3'),
          (4, 'Q4'),
        ];
      case TaxPeriod.annual:
        return const <(int, String)>[(1, 'Full year')];
    }
  }
}

class _DeclarationView extends StatelessWidget {
  const _DeclarationView({
    required this.declaration,
    required this.issues,
    required this.onCopy,
    required this.onSave,
    required this.onSaveAs,
  });

  final TaxDeclarationEntity declaration;
  final List<XmlValidationIssue> issues;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SummaryCard(declaration: declaration),
          const SizedBox(height: 12),
          _ValidationCard(issues: issues),
          const SizedBox(height: 12),
          _XmlPreviewCard(
            xml: declaration.rawXmlOutput,
            onCopy: onCopy,
            onSave: onSave,
            onSaveAs: onSaveAs,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.declaration});

  final TaxDeclarationEntity declaration;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_SummaryRow> rows = _rows(declaration);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${declaration.declarationType.label} — '
                    '${declaration.periodYear}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'VÖEN ${declaration.voen}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tax authority ${declaration.taxAuthorityCode} · '
              '${declaration.taxPeriod.label}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 20),
            for (final _SummaryRow row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: row.emphasized
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: row.emphasized
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: row.emphasized
                            ? theme.colorScheme.secondary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static List<_SummaryRow> _rows(TaxDeclarationEntity d) {
    switch (d.declarationType) {
      case TaxDeclarationType.vat2026:
        return <_SummaryRow>[
          _SummaryRow(
            'Taxable turnover (18%)',
            AppFormatters.currency(d.taxableTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'Zero-rated turnover',
            AppFormatters.currency(d.zeroRatedTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'Exempt turnover',
            AppFormatters.currency(d.exemptTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'Output VAT (calculated)',
            AppFormatters.currency(d.vatCalculated, symbol: '₼'),
          ),
          _SummaryRow(
            'Input VAT (deductible)',
            AppFormatters.currency(d.vatDeductible, symbol: '₼'),
          ),
          _SummaryRow(
            'Net VAT payable',
            AppFormatters.currency(d.netVatPayable, symbol: '₼'),
            emphasized: true,
          ),
        ];
      case TaxDeclarationType.profitTax:
        return <_SummaryRow>[
          _SummaryRow(
            'Taxable profit',
            AppFormatters.currency(d.taxableTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'Calculated profit tax (20%)',
            AppFormatters.currency(d.vatCalculated, symbol: '₼'),
          ),
          _SummaryRow(
            'Credits',
            AppFormatters.currency(d.vatDeductible, symbol: '₼'),
          ),
          _SummaryRow(
            'Net payable tax',
            AppFormatters.currency(d.netVatPayable, symbol: '₼'),
            emphasized: true,
          ),
        ];
      case TaxDeclarationType.simplifiedTax:
        return <_SummaryRow>[
          _SummaryRow(
            'Taxable turnover',
            AppFormatters.currency(d.taxableTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'Calculated simplified tax (2%)',
            AppFormatters.currency(d.vatCalculated, symbol: '₼'),
          ),
          _SummaryRow(
            'Net payable tax',
            AppFormatters.currency(d.netVatPayable, symbol: '₼'),
            emphasized: true,
          ),
        ];
      case TaxDeclarationType.payrollDsmf:
        return <_SummaryRow>[
          _SummaryRow(
            'Gross payroll',
            AppFormatters.currency(d.taxableTurnover, symbol: '₼'),
          ),
          _SummaryRow(
            'DSMF contributions',
            AppFormatters.currency(d.vatCalculated, symbol: '₼'),
            emphasized: true,
          ),
        ];
    }
  }
}

class _FieldCheck {
  const _FieldCheck(this.label, this.status);

  final String label;
  final XmlValidationSeverity? status;
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.issues});

  final List<XmlValidationIssue> issues;

  static const List<(String, String)> _fields = <(String, String)>[
    ('VOEN', 'VÖEN (10 digits)'),
    ('TaxAuthorityCode', 'Tax authority code'),
    ('PeriodYear', 'Period year'),
    ('PeriodMonth', 'Period'),
    ('CalculatedVat18', 'VAT balance'),
    ('NetPayableVat', 'Net payable'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<XmlValidationIssue>> byField =
        <String, List<XmlValidationIssue>>{};
    for (final XmlValidationIssue issue in issues) {
      byField.putIfAbsent(issue.field, () => <XmlValidationIssue>[]).add(issue);
    }

    final List<_FieldCheck> checks = <_FieldCheck>[
      for (final (String, String) field in _fields)
        _FieldCheck(field.$2, _worstSeverity(byField[field.$1])),
    ];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Validation Results',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _IssueCount(issues: issues),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _FieldCheck check in checks)
                  _FieldChip(label: check.label, status: check.status),
              ],
            ),
            if (issues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final XmlValidationIssue issue in issues)
                _IssueTile(issue: issue),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'All statutory fields are valid.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static XmlValidationSeverity? _worstSeverity(
    List<XmlValidationIssue>? fieldIssues,
  ) {
    if (fieldIssues == null || fieldIssues.isEmpty) {
      return null;
    }
    if (fieldIssues.any((XmlValidationIssue issue) => issue.isError)) {
      return XmlValidationSeverity.error;
    }
    if (fieldIssues.any((XmlValidationIssue issue) => issue.isWarning)) {
      return XmlValidationSeverity.warning;
    }
    return XmlValidationSeverity.info;
  }
}

class _IssueCount extends StatelessWidget {
  const _IssueCount({required this.issues});

  final List<XmlValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int errors =
        issues.where((XmlValidationIssue issue) => issue.isError).length;
    final int warnings =
        issues.where((XmlValidationIssue issue) => issue.isWarning).length;
    return Text(
      '$errors error${errors == 1 ? '' : 's'} · '
      '$warnings warning${warnings == 1 ? '' : 's'}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: errors > 0 ? AppColors.error : AppColors.warning,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label, required this.status});

  final String label;
  final XmlValidationSeverity? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color;
    final IconData icon;
    if (status == null) {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (status == XmlValidationSeverity.error) {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
    } else {
      color = AppColors.warning;
      icon = Icons.error_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final XmlValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = issue.isError
        ? AppColors.error
        : issue.isWarning
            ? AppColors.warning
            : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            issue.isError
                ? Icons.cancel_rounded
                : issue.isWarning
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${issue.field}: ${issue.message}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _XmlPreviewCard extends StatelessWidget {
  const _XmlPreviewCard({
    required this.xml,
    required this.onCopy,
    required this.onSave,
    required this.onSaveAs,
  });

  final String? xml;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;

  static const Color _background = Color(0xFF0F172A);
  static const Color _tag = Color(0xFF7DD3FC);
  static const Color _closingTag = Color(0xFFFCA5A5);
  static const Color _processingTag = Color(0xFFC4B5FD);
  static const Color _text = Color(0xFFA7F3D0);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String content = xml?.trim() ?? '';
    final bool hasXml = content.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'XML Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy to clipboard',
                  onPressed: hasXml ? onCopy : null,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
                TextButton.icon(
                  onPressed: hasXml ? onSaveAs : null,
                  icon: const Icon(Icons.save_alt_rounded, size: 17),
                  label: const Text('Save as…'),
                ),
                FilledButton.icon(
                  onPressed: hasXml ? onSave : null,
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Save .xml'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasXml
                  ? SingleChildScrollView(
                      child: SelectableText.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                          children: _highlight(content),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        'No XML generated yet — resolve validation errors and '
                        'recompile.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static List<TextSpan> _highlight(String xml) {
    final List<TextSpan> spans = <TextSpan>[];
    final RegExp pattern = RegExp(r'(<[^>]+>|[^<]+)');
    for (final RegExpMatch match in pattern.allMatches(xml)) {
      final String token = match.group(0) ?? '';
      if (token.startsWith('<')) {
        final Color color = token.startsWith('<?')
            ? _processingTag
            : token.startsWith('</')
                ? _closingTag
                : _tag;
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _text)));
      }
    }
    return spans;
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
