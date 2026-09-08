import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/tax_declaration_entity.dart';

/// Writes serialized declaration XML to disk under the platform
/// application-support directory (`Exports/`), matching the
/// `AppData/Roaming/FinAIStudio/Exports/` path on Windows.
class TaxXmlFileExporter {
  const TaxXmlFileExporter();

  /// Suggested file name for a declaration, e.g. `edv_1234567891_2026_08.xml`.
  static String fileNameFor(TaxDeclarationEntity declaration) {
    final String type = declaration.declarationType.shortCode.toLowerCase();
    final String period =
        declaration.periodQuarterMonth.toString().padLeft(2, '0');
    return '${type}_${declaration.voen}_${declaration.periodYear}_$period.xml';
  }

  Future<String> writeXml(
    TaxDeclarationEntity declaration,
    String xmlContent, {
    String? targetFilePath,
  }) async {
    if (targetFilePath != null && targetFilePath.trim().isNotEmpty) {
      final File file = File(targetFilePath.trim());
      await file.parent.create(recursive: true);
      await file.writeAsString(xmlContent);
      return file.path;
    }

    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory exportsDirectory = Directory(
      p.join(supportDirectory.path, 'Exports'),
    );
    await exportsDirectory.create(recursive: true);
    final File file = File(
      p.join(exportsDirectory.path, fileNameFor(declaration)),
    );
    await file.writeAsString(xmlContent);
    return file.path;
  }
}
