import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../company/domain/entities/company_entity.dart';
import '../../company/presentation/bloc/company_bloc.dart';
import '../../company/presentation/bloc/company_state.dart';

/// Small bridge that lets document widgets react to the active company BLoC.
class CompanyContextBuilder extends StatelessWidget {
  const CompanyContextBuilder({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext context, CompanyEntity? activeCompany)
      builder;

  static CompanyEntity? activeCompanyOf(BuildContext context) {
    final CompanyState state = context.read<CompanyBloc>().state;
    return state is CompaniesLoaded ? state.activeCompany : null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompanyBloc, CompanyState>(
      builder: (BuildContext context, CompanyState state) {
        final CompanyEntity? activeCompany =
            state is CompaniesLoaded ? state.activeCompany : null;
        return builder(context, activeCompany);
      },
    );
  }
}
