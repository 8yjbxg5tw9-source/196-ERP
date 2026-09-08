import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_entity.dart';
import '../bloc/company_bloc.dart';
import '../bloc/company_event.dart';
import '../bloc/company_state.dart';

const String _addCompanyAction = '__add_company__';

/// Desktop company context selector shown in the application action bar.
class CompanySelectorDropdown extends StatelessWidget {
  const CompanySelectorDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompanyBloc, CompanyState>(
      listenWhen: (CompanyState _previous, CompanyState current) =>
          current is CompanyOperationFailure,
      listener: (BuildContext context, CompanyState state) {
        if (state is CompanyOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (BuildContext context, CompanyState state) {
        final List<CompanyEntity> companies = state is CompaniesLoaded
            ? state.companies
            : const <CompanyEntity>[];
        final CompanyEntity? activeCompany = state is CompaniesLoaded
            ? state.activeCompany
            : null;

        return PopupMenuButton<String>(
          tooltip: 'Switch company',
          onSelected: (String value) {
            if (value == _addCompanyAction) {
              _showCreateCompanyDialog(context);
              return;
            }
            context.read<CompanyBloc>().add(
                  SelectActiveCompanyEvent(value),
                );
          },
          itemBuilder: (BuildContext context) =>
              _buildMenuEntries(companies, activeCompany),
          child: _SelectorSurface(
            activeCompany: activeCompany,
            isLoading: state is CompanyLoading,
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _buildMenuEntries(
    List<CompanyEntity> companies,
    CompanyEntity? activeCompany,
  ) {
    final List<PopupMenuEntry<String>> entries = <PopupMenuEntry<String>>[];
    for (final CompanyEntity company in companies) {
      entries.add(
        PopupMenuItem<String>(
          value: company.id,
          child: SizedBox(
            width: 260,
            child: Row(
              children: <Widget>[
                Icon(
                  company.id == activeCompany?.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        company.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'VÖEN/TIN: ${company.voenTin}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (companies.isNotEmpty) {
      entries.add(const PopupMenuDivider());
    }
    entries.add(
      const PopupMenuItem<String>(
        value: _addCompanyAction,
        child: Row(
          children: <Widget>[
            Icon(Icons.add_business_rounded, size: 18),
            SizedBox(width: 10),
            Text('Add New Company'),
          ],
        ),
      ),
    );
    return entries;
  }

  Future<void> _showCreateCompanyDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _CreateCompanyDialog(
          onSubmit: (CompanyEntity company) {
            Navigator.of(dialogContext).pop();
            context.read<CompanyBloc>().add(
                  CreateCompanyEvent(company),
                );
          },
        );
      },
    );
  }
}

class _SelectorSurface extends StatelessWidget {
  const _SelectorSurface({
    required this.activeCompany,
    required this.isLoading,
  });

  final CompanyEntity? activeCompany;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = activeCompany?.name ??
        (isLoading ? 'Loading companies…' : 'Select company');
    final String voenTin = activeCompany == null
        ? 'No active company'
        : 'VÖEN/TIN ${activeCompany!.voenTin}';
    final String trimmedName = activeCompany?.name.trim() ?? '';
    final String initial = trimmedName.isEmpty
        ? '•'
        : trimmedName.substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(100)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.secondary.withAlpha(30),
            child: Text(
              initial,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  voenTin,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more_rounded, size: 16),
        ],
      ),
    );
  }
}

class _CreateCompanyDialog extends StatefulWidget {
  const _CreateCompanyDialog({required this.onSubmit});

  final ValueChanged<CompanyEntity> onSubmit;

  @override
  State<_CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<_CreateCompanyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _voenTinController = TextEditingController();
  String _taxType = 'VAT';

  @override
  void dispose() {
    _nameController.dispose();
    _voenTinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Company'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  hintText: 'Example: Caspian Trade LLC',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _voenTinController,
                decoration: const InputDecoration(
                  labelText: 'VÖEN / TIN',
                  hintText: 'Tax registration number',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _taxType,
                decoration: const InputDecoration(labelText: 'Tax type'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'Simplified',
                    child: Text('Simplified'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'VAT',
                    child: Text('VAT'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Income',
                    child: Text('Income'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _taxType = value);
                  }
                },
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
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Create company'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String companyId =
        'company-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    widget.onSubmit(
      CompanyEntity(
        id: companyId,
        name: _nameController.text.trim(),
        voenTin: _voenTinController.text.trim(),
        taxType: _taxType,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }
}
