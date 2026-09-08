import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../data/tax_xml_file_exporter.dart';
import '../../domain/entities/tax_declaration_entity.dart';
import '../../domain/entities/xml_validation_issue.dart';
import '../../domain/repositories/tax_declaration_repository.dart';
import 'tax_declaration_event.dart';
import 'tax_declaration_state.dart';

/// Coordinates statutory declaration compilation, validation, and XML export.
class TaxDeclarationBloc
    extends Bloc<TaxDeclarationEvent, TaxDeclarationState> {
  TaxDeclarationBloc({
    required TaxDeclarationRepository repository,
    TaxXmlFileExporter exporter = const TaxXmlFileExporter(),
  })  : _repository = repository,
        _exporter = exporter,
        super(const DeclarationInitial()) {
    on<CompileDeclarationEvent>(_onCompile);
    on<ExportXmlFileEvent>(_onExport);
  }

  final TaxDeclarationRepository _repository;
  final TaxXmlFileExporter _exporter;

  Future<void> _onCompile(
    CompileDeclarationEvent event,
    Emitter<TaxDeclarationState> emit,
  ) async {
    emit(const DeclarationLoading());
    final Either<Failure, TaxDeclarationEntity> compiled =
        await _repository.compileDeclarationData(
      event.companyId,
      event.type,
      event.year,
      event.period,
    );

    if (compiled.isLeft()) {
      final Failure failure =
          (compiled as Left<Failure, TaxDeclarationEntity>).value;
      emit(DeclarationError(failure.message));
      return;
    }

    final TaxDeclarationEntity declaration =
        (compiled as Right<Failure, TaxDeclarationEntity>).value;

    final Either<Failure, List<XmlValidationIssue>> validationResult =
        await _repository.validateDeclaration(declaration);
    final List<XmlValidationIssue> issues = validationResult.fold(
      (Failure _) => const <XmlValidationIssue>[],
      (List<XmlValidationIssue> value) => value,
    );

    final Either<Failure, String> xmlResult =
        await _repository.generateTaxXml(declaration);
    final bool hasErrors =
        issues.any((XmlValidationIssue issue) => issue.isError);
    final TaxDeclarationEntity finalized = xmlResult.fold(
      (Failure _) => declaration.copyWith(isValidated: false),
      (String xml) => declaration.copyWith(
            rawXmlOutput: xml,
            isValidated: !hasErrors,
          ),
    );

    emit(DeclarationCompiled(declaration: finalized, issues: issues));
  }

  Future<void> _onExport(
    ExportXmlFileEvent event,
    Emitter<TaxDeclarationState> emit,
  ) async {
    final TaxDeclarationState current = state;
    if (current is! DeclarationCompiled) {
      emit(const DeclarationError('Compile a declaration before exporting.'));
      return;
    }

    final String? xml = current.declaration.rawXmlOutput;
    if (xml == null || xml.trim().isEmpty) {
      emit(const DeclarationError('No XML has been generated yet.'));
      return;
    }

    try {
      final String path = await _exporter.writeXml(
        current.declaration,
        xml,
        targetFilePath: event.targetFilePath.trim().isEmpty
            ? null
            : event.targetFilePath,
      );
      emit(XmlExportSuccess(path));
    } on Object catch (error) {
      emit(DeclarationError('The XML file could not be written: $error'));
    }
  }
}
