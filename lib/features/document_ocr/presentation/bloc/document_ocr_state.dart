import 'package:equatable/equatable.dart';

import '../../domain/entities/document_entity.dart';

abstract class DocumentOcrState extends Equatable {
  const DocumentOcrState();

  @override
  List<Object?> get props => const <Object?>[];
}

class DocumentInitial extends DocumentOcrState {
  const DocumentInitial();
}

class DocumentLoading extends DocumentOcrState {
  const DocumentLoading();
}

class DocumentLoaded extends DocumentOcrState {
  const DocumentLoaded(this.document);

  final DocumentEntity document;

  @override
  List<Object?> get props => <Object?>[document];
}

class DocumentSaving extends DocumentOcrState {
  const DocumentSaving(this.document);

  final DocumentEntity document;

  @override
  List<Object?> get props => <Object?>[document];
}

class DocumentSavedSuccess extends DocumentOcrState {
  const DocumentSavedSuccess(this.document);

  final DocumentEntity document;

  @override
  List<Object?> get props => <Object?>[document];
}

class DocumentError extends DocumentOcrState {
  const DocumentError({
    required this.message,
    this.document,
  });

  final String message;
  final DocumentEntity? document;

  @override
  List<Object?> get props => <Object?>[message, document];
}
