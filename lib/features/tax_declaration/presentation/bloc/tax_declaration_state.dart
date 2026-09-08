import 'package:equatable/equatable.dart';

import '../../domain/entities/tax_declaration_entity.dart';
import '../../domain/entities/xml_validation_issue.dart';

abstract class TaxDeclarationState extends Equatable {
  const TaxDeclarationState();

  @override
  List<Object?> get props => const <Object?>[];
}

class DeclarationInitial extends TaxDeclarationState {
  const DeclarationInitial();
}

class DeclarationLoading extends TaxDeclarationState {
  const DeclarationLoading();
}

class DeclarationCompiled extends TaxDeclarationState {
  const DeclarationCompiled({
    required this.declaration,
    required this.issues,
  });

  final TaxDeclarationEntity declaration;
  final List<XmlValidationIssue> issues;

  @override
  List<Object?> get props => <Object?>[declaration, issues];
}

class XmlExportSuccess extends TaxDeclarationState {
  const XmlExportSuccess(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => <Object?>[filePath];
}

class DeclarationError extends TaxDeclarationState {
  const DeclarationError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
