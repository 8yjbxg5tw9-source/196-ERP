import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../models/document_model.dart';

/// SQLite and local-filesystem boundary for source documents.
abstract interface class DocumentLocalDataSource {
  Future<List<DocumentModel>> getDocuments(String companyId);

  Future<DocumentModel?> getDocument(String documentId);

  Future<DocumentModel> createDocument(DocumentModel document);

  Future<void> updateDocument(DocumentModel document);

  Future<void> saveApprovedDocument(
    DocumentModel document, {
    required Map<String, dynamic> auditDetails,
  });

  Future<void> deleteDocument(String documentId);

  Future<String> saveFile(File sourceFile, String companyId);
}

class DocumentLocalDataSourceImpl implements DocumentLocalDataSource {
  DocumentLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

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
  Future<void> saveApprovedDocument(
    DocumentModel document, {
    required Map<String, dynamic> auditDetails,
  }) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      final int updatedRows = await transaction.update(
        DatabaseTables.documents,
        document.toSqflite(),
        where: 'id = ?',
        whereArgs: <Object?>[document.id],
      );
      if (updatedRows == 0) {
        throw StateError('Cannot approve an unknown document: ${document.id}');
      }

      await transaction.insert(
        DatabaseTables.auditLogs,
        <String, Object?>{
          'id': _newAuditId(),
          'action': 'document_approved',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'details': jsonEncode(auditDetails),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.documents,
      columns: <String>['file_path'],
      where: 'id = ?',
      whereArgs: <Object?>[documentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final Object? rawFilePath = rows.first['file_path'];
    await database.delete(
      DatabaseTables.documents,
      where: 'id = ?',
      whereArgs: <Object?>[documentId],
    );

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

    final Directory companyDirectory = Directory(
      p.join(await _documentsRoot(), _safeSegment(companyId)),
    );
    await companyDirectory.create(recursive: true);

    final String sourceName = p.basename(sourceFile.path);
    final String safeName = _safeFileName(sourceName);
    final String uniqueName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}_$safeName';
    final String destinationPath = p.join(companyDirectory.path, uniqueName);
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  Future<String> _documentsRoot() async {
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
