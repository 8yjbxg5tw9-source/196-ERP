import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/ocr_service.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_local_data_source.dart';
import '../models/document_model.dart';

/// Coordinates safe file storage, SQLite status transitions, and OCR parsing.
class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl(this._localDataSource, this._ocrService);

  final DocumentLocalDataSource _localDataSource;
  final OcrService _ocrService;

  @override
  Future<Either<Failure, List<DocumentEntity>>> getDocuments(
    String companyId,
  ) async {
    try {
      final List<DocumentModel> documents =
          await _localDataSource.getDocuments(companyId);
      return Right<Failure, List<DocumentEntity>>(documents);
    } on DatabaseException catch (error) {
      return Left<Failure, List<DocumentEntity>>(
        DatabaseFailure(
          message: 'Documents could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<DocumentEntity>>(
        CacheFailure(
          message: 'Saved documents could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, DocumentEntity>> processDocument(
    File file,
    String companyId,
  ) async {
    DocumentModel? currentDocument;
    try {
      _validateInput(file, companyId);
      final String storedFilePath = await _localDataSource.saveFile(
        file,
        companyId,
      );
      final DateTime createdAt = DateTime.now().toUtc();
      final DocumentModel pending = DocumentModel(
        id: _newDocumentId(),
        companyId: companyId,
        filePath: storedFilePath,
        fileName: p.basename(file.path),
        currency: 'AZN',
        status: DocumentStatus.pending,
        createdAt: createdAt,
      );

      final DocumentModel storedDocument =
          await _localDataSource.createDocument(pending);
      currentDocument = storedDocument;
      final DocumentModel processingDocument =
          storedDocument.withStatus(DocumentStatus.processing);
      currentDocument = processingDocument;
      await _localDataSource.updateDocument(processingDocument);

      final Map<String, dynamic> ocrPayload = await _ocrService
          .extractTextAndStructure(File(storedFilePath));
      final DocumentModel completed = DocumentModel.fromOcrResult(
        base: processingDocument,
        ocrPayload: ocrPayload,
      );
      await _localDataSource.updateDocument(completed);
      debugPrint(
        '[DocumentRepository] OCR completed for ${completed.fileName}: '
        '${jsonEncode(ocrPayload['structured'] ?? <String, dynamic>{})}',
      );
      return Right<Failure, DocumentEntity>(completed);
    } on DatabaseException catch (error) {
      await _markFailed(currentDocument);
      return Left<Failure, DocumentEntity>(
        DatabaseFailure(
          message: 'The document could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on FileSystemException catch (error) {
      await _markFailed(currentDocument);
      return Left<Failure, DocumentEntity>(
        CacheFailure(
          message: 'The document could not be stored locally.',
          cause: error,
        ),
      );
    } on ArgumentError catch (error) {
      await _markFailed(currentDocument);
      return Left<Failure, DocumentEntity>(
        ValidationFailure(
          message: error.message?.toString() ??
              'The document input is not valid.',
          cause: error,
        ),
      );
    } on FormatException catch (error) {
      await _markFailed(currentDocument);
      return Left<Failure, DocumentEntity>(
        ParsingFailure(
          message: 'The OCR response could not be parsed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      await _markFailed(currentDocument);
      return Left<Failure, DocumentEntity>(
        ParsingFailure(
          message: 'Document OCR processing failed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteDocument(String documentId) async {
    try {
      await _localDataSource.deleteDocument(documentId);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The document could not be deleted from SQLite.',
          cause: error,
        ),
      );
    } on FileSystemException catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'The document file could not be deleted.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'The document could not be deleted locally.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _markFailed(DocumentModel? document) async {
    if (document == null) {
      return;
    }
    try {
      await _localDataSource.updateDocument(
        document.withStatus(DocumentStatus.failed),
      );
    } on Object catch (error) {
      debugPrint(
        '[DocumentRepository] Could not persist failed status for '
        '${document.id}: $error',
      );
    }
  }

  void _validateInput(File file, String companyId) {
    if (companyId.trim().isEmpty) {
      throw ArgumentError.value(companyId, 'companyId', 'must not be empty');
    }
    final String extension = p.extension(file.path).toLowerCase();
    const Set<String> allowedExtensions = <String>{
      '.pdf',
      '.png',
      '.jpg',
      '.jpeg',
    };
    if (!allowedExtensions.contains(extension)) {
      throw ArgumentError.value(
        extension,
        'file',
        'unsupported document type; use PDF, PNG, JPG, or JPEG',
      );
    }
  }

  String _newDocumentId() {
    return 'document-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}
