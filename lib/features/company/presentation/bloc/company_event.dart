import 'package:equatable/equatable.dart';

import '../../domain/entities/company_entity.dart';

abstract class CompanyEvent extends Equatable {
  const CompanyEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadCompaniesEvent extends CompanyEvent {
  const LoadCompaniesEvent();
}

class CreateCompanyEvent extends CompanyEvent {
  const CreateCompanyEvent(this.company);

  final CompanyEntity company;

  @override
  List<Object?> get props => <Object?>[company];
}

class SelectActiveCompanyEvent extends CompanyEvent {
  const SelectActiveCompanyEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class DeleteCompanyEvent extends CompanyEvent {
  const DeleteCompanyEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}
