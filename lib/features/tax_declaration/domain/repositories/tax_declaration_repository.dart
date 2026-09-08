import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/tax_declaration_entity.dart';
import '../entities/xml_validation_issue.dart';

/// Boundary for the statutory tax declaration export engine.
abstract interface class TaxDeclarationRepository {
  /// Assembles a declaration from the ledger for [type], [year], and [period].
  Future<Either<Failure, TaxDeclarationEntity>> compileDeclarationData(
    String companyId,
    TaxDeclarationType type,
    int year,
    int period,
  );

  /// Validates the declaration fields and serializes them to XML.
  Future<Either<Failure, String>> generateTaxXml(
    TaxDeclarationEntity declaration,
  );

  /// Pre-submission validation of the mandatory statutory fields.
  Future<Either<Failure, List<XmlValidationIssue>>> validateDeclaration(
    TaxDeclarationEntity declaration,
  );

  /// Structural validation of a serialized declaration document.
  Future<Either<Failure, List<XmlValidationIssue>>> validateXmlSchema(
    String xmlContent,
  );
}
