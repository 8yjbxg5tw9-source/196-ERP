import 'package:equatable/equatable.dart';

/// One parsed line on an invoice or receipt.
class InvoiceItemEntity extends Equatable {
  const InvoiceItemEntity({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.vatRate,
    this.currency = 'AZN',
    this.id = '',
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double vatRate;

  /// The line's own currency, defaulting to the accounting base `AZN`.
  final String currency;

  InvoiceItemEntity copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    double? vatRate,
    String? currency,
  }) {
    return InvoiceItemEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      vatRate: vatRate ?? this.vatRate,
      currency: currency ?? this.currency,
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
        currency,
      ];
}
