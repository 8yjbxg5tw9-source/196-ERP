import 'package:equatable/equatable.dart';

/// One parsed line on an invoice or receipt.
class InvoiceItemEntity extends Equatable {
  const InvoiceItemEntity({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.vatRate,
    this.id = '',
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double vatRate;

  InvoiceItemEntity copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    double? vatRate,
  }) {
    return InvoiceItemEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      vatRate: vatRate ?? this.vatRate,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        description,
        quantity,
        unitPrice,
        lineTotal,
        vatRate,
      ];
}
