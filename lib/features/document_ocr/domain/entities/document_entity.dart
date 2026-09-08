import 'package:equatable/equatable.dart';

import 'invoice_item_entity.dart';

enum DocumentStatus {
  pending,
  processing,
  completed,
  failed,
}

/// A locally stored source document and its normalized accounting fields.
class DocumentEntity extends Equatable {
  const DocumentEntity({
    required this.id,
    required this.companyId,
    required this.filePath,
    required this.fileName,
    this.vendorName,
    this.vendorVoen,
    this.invoiceNumber,
    this.issueDate,
    this.dueDate,
    this.subtotal,
    this.vatAmount,
    this.totalAmount,
    this.createdAt,
    this.currency = 'AZN',
    this.status = DocumentStatus.pending,
    this.lineItems = const <InvoiceItemEntity>[],
    this.extractedData,
  });

  final String id;
  final String companyId;
  final String filePath;
  final String fileName;
  final String? vendorName;
  final String? vendorVoen;
  final String? invoiceNumber;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double? subtotal;
  final double? vatAmount;
  final double? totalAmount;
  final DateTime? createdAt;
  final String currency;
  final DocumentStatus status;
  final List<InvoiceItemEntity> lineItems;
  final Map<String, dynamic>? extractedData;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        filePath,
        fileName,
        vendorName,
        vendorVoen,
        invoiceNumber,
        issueDate,
        dueDate,
        subtotal,
        vatAmount,
        totalAmount,
        createdAt,
        currency,
        status,
        lineItems,
        extractedData,
      ];
}
