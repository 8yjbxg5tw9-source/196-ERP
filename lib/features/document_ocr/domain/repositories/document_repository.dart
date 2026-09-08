import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/document_entity.dart';

/// Persistence and OCR processing contract for source documents.
abstract interface class DocumentRepository {
  Future<Either<Failure, List<DocumentEntity>>> getDocuments(
    String companyId,
  );

  Future<Either<Failure, DocumentEntity>> getDocument(String documentId);

  Future<Either<Failure, DocumentEntity>> processDocument(
    File file,
    String companyId,
  );

  Future<Either<Failure, DocumentEntity>> saveAndApproveDocument(
    DocumentEntity document,
  );

  Future<Either<Failure, void>> deleteDocument(String documentId);
}
