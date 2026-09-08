import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/analytics/domain/entities/profit_and_loss_entity.dart';
import '../../features/audit/domain/entities/audit_log_entity.dart';
import '../../features/company/domain/entities/company_entity.dart';
import 'app_directory_service.dart';
import 'audit_logger_service.dart';
import 'excel_export_service.dart';
import 'export_models.dart';
import 'pdf_generator_service.dart';
import 'tax_xml_serializer.dart';

/// Unified export boundary for PDF, Excel, and tax-declaration XML output.
abstract interface class ExportService {
  Future<File> generatePdfReport(ReportData data, String templateType);

  Future<File> generateExcelWorkbook(
    List<TransactionEntity> transactions,
    String fileName, {
    ExportSummary? summary,
    TaxBreakdown? tax,
  });

  Future<String> generateTaxDeclarationXml(
    CompanyEntity company,
    ProfitAndLossEntity report, {
    TaxDeclarationType type = TaxDeclarationType.vat,
  });

  /// Opens the platform print-preview dialog for [data].
  Future<bool> printReport(ReportData data, String templateType);
}

class ExportServiceImpl implements ExportService {
  ExportServiceImpl({
    PdfGeneratorService pdfGenerator = const PdfGeneratorService(),
    ExcelExportService excelService = const ExcelExportService(),
    TaxXmlSerializer xmlSerializer = const TaxXmlSerializer(),
    AppDirectoryService? directoryService,
    AuditLoggerService? auditLogger,
  })  : _pdfGenerator = pdfGenerator,
        _excelService = excelService,
        _xmlSerializer = xmlSerializer,
        _directoryService = directoryService,
        _auditLogger = auditLogger;

  final PdfGeneratorService _pdfGenerator;
  final ExcelExportService _excelService;
  final TaxXmlSerializer _xmlSerializer;
  final AppDirectoryService? _directoryService;
  final AuditLoggerService? _auditLogger;

  @override
  Future<File> generatePdfReport(ReportData data, String templateType) async {
    final Uint8List bytes = await _pdfGenerator.build(data, templateType);
    final File file = await _writeFile(
      '${_safeName(templateType)}_${_timestamp()}.pdf',
      bytes,
    );
    await _auditLogger?.logAction(
      action: AuditAction.export,
      entityName: 'Report',
      entityId: file.path,
      after: <String, dynamic>{'type': 'pdf', 'title': data.title},
    );
    return file;
  }

  @override
  Future<File> generateExcelWorkbook(
    List<TransactionEntity> transactions,
    String fileName, {
    ExportSummary? summary,
    TaxBreakdown? tax,
  }) async {
    final List<int> bytes = _excelService.build(
      transactions,
      summary: summary,
      tax: tax,
    );
    final File file = await _writeFile(
      '${_safeName(fileName)}.xlsx',
      Uint8List.fromList(bytes),
    );
    await _auditLogger?.logAction(
      action: AuditAction.export,
      entityName: 'Workbook',
      entityId: file.path,
      after: <String, dynamic>{
        'type': 'xlsx',
        'rows': transactions.length,
      },
    );
    return file;
  }

  @override
  Future<String> generateTaxDeclarationXml(
    CompanyEntity company,
    ProfitAndLossEntity report, {
    TaxDeclarationType type = TaxDeclarationType.vat,
  }) async {
    final String xml = _xmlSerializer.serialize(company, report, type: type);
    await _auditLogger?.logAction(
      action: AuditAction.export,
      entityName: 'TaxXml',
      entityId: company.id,
      after: <String, dynamic>{'declaration': type.name},
    );
    return xml;
  }

  @override
  Future<bool> printReport(ReportData data, String templateType) {
    return _pdfGenerator.printReport(data, templateType);
  }

  Future<File> _writeFile(String fileName, Uint8List bytes) async {
    final Directory exportsDirectory;
    final AppDirectoryService? directoryService = _directoryService;
    if (directoryService != null) {
      exportsDirectory = await directoryService.exports();
    } else {
      final Directory supportDirectory = await getApplicationSupportDirectory();
      exportsDirectory = Directory(p.join(supportDirectory.path, 'exports'));
      await exportsDirectory.create(recursive: true);
    }
    final File file = File(p.join(exportsDirectory.path, fileName));
    await file.writeAsBytes(bytes);
    return file;
  }

  static String _safeName(String value) {
    final String normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'report' : normalized;
  }

  static String _timestamp() {
    return DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  }
}
