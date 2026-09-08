import 'package:equatable/equatable.dart';

import '../../domain/entities/tax_declaration_entity.dart';

abstract class TaxDeclarationEvent extends Equatable {
  const TaxDeclarationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Compiles the statutory declaration for [companyId], [type], [year], and
/// [period] (month 1–12, quarter 1–4, or 1 for annual).
class CompileDeclarationEvent extends TaxDeclarationEvent {
  const CompileDeclarationEvent({
    required this.companyId,
    required this.type,
    required this.year,
    required this.period,
  });

  final String companyId;
  final TaxDeclarationType type;
  final int year;
  final int period;

  @override
  List<Object?> get props => <Object?>[companyId, type, year, period];
}

/// Writes the generated XML to [targetFilePath]; an empty path uses the
/// platform application-support `Exports/` directory.
class ExportXmlFileEvent extends TaxDeclarationEvent {
  const ExportXmlFileEvent([this.targetFilePath = '']);

  final String targetFilePath;

  @override
  List<Object?> get props => <Object?>[targetFilePath];
}
