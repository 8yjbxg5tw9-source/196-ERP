import 'package:equatable/equatable.dart';

import '../../domain/entities/invoice_item_entity.dart';

enum DocumentField {
  invoiceNumber,
  vendorName,
  vendorVoen,
  issueDate,
  dueDate,
  currency,
}

/// User intents handled by [DocumentOcrBloc].
abstract class DocumentOcrEvent extends Equatable {
  const DocumentOcrEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadDocumentDetails extends DocumentOcrEvent {
  const LoadDocumentDetails(this.documentId);

  final String documentId;

  @override
  List<Object?> get props => <Object?>[documentId];
}

class UpdateDocumentField extends DocumentOcrEvent {
  const UpdateDocumentField({
    required this.field,
    required this.value,
  });

  final DocumentField field;
  final Object? value;

  @override
  List<Object?> get props => <Object?>[field, value];
}

class AddLineItem extends DocumentOcrEvent {
  const AddLineItem({this.item});

  final InvoiceItemEntity? item;

  @override
  List<Object?> get props => <Object?>[item];
}

class UpdateLineItem extends DocumentOcrEvent {
  const UpdateLineItem({
    required this.index,
    required this.item,
  });

  final int index;
  final InvoiceItemEntity item;

  @override
  List<Object?> get props => <Object?>[index, item];
}

class RemoveLineItem extends DocumentOcrEvent {
  const RemoveLineItem(this.index);

  final int index;

  @override
  List<Object?> get props => <Object?>[index];
}

class SaveAndApproveDocument extends DocumentOcrEvent {
  const SaveAndApproveDocument();
}
