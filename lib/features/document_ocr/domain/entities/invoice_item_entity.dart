import 'package:equatable/equatable.dart';

/// One parsed line on an invoice or receipt.
class InvoiceItemEntity extends Equatable {
  const InvoiceItemEntity({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.vatRate,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double vatRate;

  @override
  List<Object?> get props => <Object?>[
        description,
        quantity,
        unitPrice,
        lineTotal,
        vatRate,
      ];
}
