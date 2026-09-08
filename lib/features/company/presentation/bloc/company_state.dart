import 'package:equatable/equatable.dart';

import '../../domain/entities/company_entity.dart';

abstract class CompanyState extends Equatable {
  const CompanyState();

  @override
  List<Object?> get props => const <Object?>[];
}

class CompanyInitial extends CompanyState {
  const CompanyInitial();
}

class CompanyLoading extends CompanyState {
  const CompanyLoading();
}

class CompaniesLoaded extends CompanyState {
  CompaniesLoaded({
    required List<CompanyEntity> companies,
    required this.activeCompany,
  }) : companies = List<CompanyEntity>.unmodifiable(companies);

  final List<CompanyEntity> companies;
  final CompanyEntity? activeCompany;

  @override
  List<Object?> get props => <Object?>[companies, activeCompany];
}

class CompanyOperationFailure extends CompanyState {
  const CompanyOperationFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
