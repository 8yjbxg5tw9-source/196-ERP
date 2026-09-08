import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../../../../core/services/app_directory_service.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../audit/domain/entities/audit_log_entity.dart';
import '../models/document_model.dart';

/// SQLite and local-filesystem boundary for source documents.
abstract interface class DocumentLocalDataSource {
  Future<List<DocumentModel>> getDocuments(String companyId);

  Future<DocumentModel?> getDocument(String documentId);

  Future<DocumentModel> createDocument(DocumentModel document);

  Future<void> updateDocument(DocumentModel document);

  Future<void> saveApprovedDocument(DocumentModel document);

  Future<void> deleteDocument(String documentId);

  Future<String> saveFile(File sourceFile, String companyId);
}

class DocumentLocalDataSourceImpl implements DocumentLocalDataSource {
  DocumentLocalDataSourceImpl(
    this._databaseService, {
    AuditLoggerService? auditLogger,
    AppDirectoryService? directoryService,
  })  : _auditLogger = auditLogger,
        _directoryService = directoryService;

  final DatabaseService _databaseService;
  final AuditLoggerService? _auditLogger;
  final AppDirectoryService? _directoryService;

  @override
  Future<List<DocumentModel>> getDocuments(String companyId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.documents,
      where: 'company_id = ?',
      whereArgs: <Object?>[companyId],
      orderBy: 'created_at DESC',
    );
    return rows.map(DocumentModel.fromSqflite).toList(growable: false);
  }

  @override
  Future<DocumentModel?> getDocument(String documentId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.documents,
      where: 'id = ?',
      whereArgs: <Object?>[documentId],
      limit: 1,
    );
    return rows.isEmpty ? null : DocumentModel.fromSqflite(rows.first);
  }

  @override
  Future<DocumentModel> createDocument(DocumentModel document) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.documents,
      document.toSqflite(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return document;
  }

  @override
  Future<void> updateDocument(DocumentModel document) async {
    final Database database = await _databaseService.database;
    final int updatedRows = await database.update(
      DatabaseTables.documents,
      document.toSqflite(),
      where: 'id = ?',
      whereArgs: <Object?>[document.id],
    );
    if (updatedRows == 0) {
      throw StateError('Cannot update an unknown document: ${document.id}');
    }
  }

  @override
  Future<void> saveApprovedDocument(DocumentModel document) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> beforeRows = await transaction.query(
        DatabaseTables.documents,
        where: 'id = ?',
        whereArgs: <Object?>[document.id],
        limit: 1,
      );

      final int updatedRows = await transaction.update(
        DatabaseTables.documents,
        document.toSqflite(),
        where: 'id = ?',
        whereArgs: <Object?>[document.id],
      );
      if (updatedRows == 0) {
        throw StateError('Cannot approve an unknown document: ${document.id}');
      }

      await _insertAuditRow(
        transaction,
        action: AuditAction.update,
        entityName: 'Document',
        entityId: document.id,
        companyId: document.companyId,
        beforeState: beforeRows.isEmpty ? null : beforeRows.first,
        afterState: document.toSqflite(),
      );
    });
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.documents,
      where: 'id = ?',
      whereArgs: <Object?>[documentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final Map<String, Object?> before = rows.first;
    final Object? rawFilePath = before['file_path'];
    final String companyId = before['company_id']?.toString() ?? '';

    await database.transaction((Transaction transaction) async {
      await transaction.delete(
        DatabaseTables.documents,
        where: 'id = ?',
        whereArgs: <Object?>[documentId],
      );
      await _insertAuditRow(
        transaction,
        action: AuditAction.delete,
        entityName: 'Document',
        entityId: documentId,
        companyId: companyId,
        beforeState: before,
      );
    });

    if (rawFilePath is String && rawFilePath.isNotEmpty) {
      await _deleteStoredFileIfSafe(rawFilePath);
    }
  }

  @override
  Future<String> saveFile(File sourceFile, String companyId) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'The selected document does not exist.',
        sourceFile.path,
      );
    }

    final Directory companyDirectory = await _attachmentsDirectory(companyId);
    await companyDirectory.create(recursive: true);

    final String sourceName = p.basename(sourceFile.path);
    final String safeName = _safeFileName(sourceName);
    final String uniqueName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}_$safeName';
    final String destinationPath = p.join(companyDirectory.path, uniqueName);
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  /// `Storage/{company_id}/{year}/{month}` so scans are archived by period.
  Future<Directory> _attachmentsDirectory(String companyId) async {
    final AppDirectoryService? directoryService = _directoryService;
    if (directoryService != null) {
      final DateTime now = DateTime.now();
      return directoryService.storage(
        companyId,
        year: now.year,
        month: now.month,
      );
    }
    return Directory(p.join(await _documentsRoot(), _safeSegment(companyId)));
  }

  Future<String> _documentsRoot() async {
    final AppDirectoryService? directoryService = _directoryService;
    if (directoryService != null) {
      return (await directoryService.storageRoot()).path;
    }
    final Directory supportDirectory = await getApplicationSupportDirectory();
    return p.join(supportDirectory.path, 'documents');
  }

  Future<void> _deleteStoredFileIfSafe(String filePath) async {
    final String root = p.normalize(await _documentsRoot());
    final String candidate = p.normalize(filePath);
    final String relative = p.relative(candidate, from: root);
    if (relative == '..' ||
        relative.startsWith('..${p.separator}') ||
        p.isAbsolute(relative)) {
      return;
    }

    final File file = File(candidate);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _insertAuditRow(
    Transaction transaction, {
    required AuditAction action,
    required String entityName,
    required String entityId,
    required String companyId,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
  }) async {
    final AuditLogEntity log;
    final AuditLoggerService? logger = _auditLogger;
    if (logger != null) {
      log = await logger.buildLog(
        action: action,
        entityName: entityName,
        entityId: entityId,
        before: beforeState,
        after: afterState,
        companyId: companyId,
      );
    } else {
      log = AuditLogEntity(
        id: _newAuditId(),
        companyId: companyId,
        userId: '',
        userName: 'System',
        userRole: 'system',
        action: action,
        entityName: entityName,
        entityId: entityId,
        beforeState: beforeState,
        afterState: afterState,
        timestamp: DateTime.now().toUtc(),
      );
    }

    await transaction.insert(
      DatabaseTables.auditLogs,
      _auditMap(log),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  static Map<String, Object?> _auditMap(AuditLogEntity log) {
    return <String, Object?>{
      'id': log.id,
      'company_id': log.companyId,
      'user_id': log.userId,
      'user_name': log.userName,
      'user_role': log.userRole,
      'action': log.action.name,
      'entity_name': log.entityName,
      'entity_id': log.entityId,
      'before_state':
          log.beforeState == null ? null : jsonEncode(log.beforeState),
      'after_state': log.afterState == null ? null : jsonEncode(log.afterState),
      'ip_address': log.ipAddress,
      'timestamp': log.timestamp.toUtc().toIso8601String(),
    };
  }

  String _newAuditId() {
    return 'audit-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  String _safeSegment(String value) {
    final String sanitized = value.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'unknown-company';
    }
    return sanitized;
  }

  String _safeFileName(String value) {
    final String sanitized = value.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'document' : sanitized;
  }
}
