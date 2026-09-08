import 'package:equatable/equatable.dart';

/// A declared profit distribution with dividend withholding tax applied.
class DividendDistributionEntity extends Equatable {
  const DividendDistributionEntity({
    required this.id,
    required this.distributingCompanyId,
    required this.recipientEntityId,
    required this.declaredAmount,
    this.dividendTaxRate = 0,
    this.netDividendPaid = 0,
    required this.declarationDate,
    this.createdAt,
  });

  final String id;
  final String distributingCompanyId;
  final String recipientEntityId;
  final double declaredAmount;

  /// Dividend withholding tax percentage (e.g. 5 = 5%).
  final double dividendTaxRate;
  final double netDividendPaid;
  final DateTime declarationDate;
  final DateTime? createdAt;

  double get withholdingTax =>
      declaredAmount * dividendTaxRate / 100;

  DividendDistributionEntity copyWith({
    String? id,
    String? distributingCompanyId,
    String? recipientEntityId,
    double? declaredAmount,
    double? dividendTaxRate,
    double? netDividendPaid,
    DateTime? declarationDate,
    DateTime? createdAt,
  }) {
    return DividendDistributionEntity(
      id: id ?? this.id,
      distributingCompanyId: distributingCompanyId ?? this.distributingCompanyId,
      recipientEntityId: recipientEntityId ?? this.recipientEntityId,
      declaredAmount: declaredAmount ?? this.declaredAmount,
      dividendTaxRate: dividendTaxRate ?? this.dividendTaxRate,
      netDividendPaid: netDividendPaid ?? this.netDividendPaid,
      declarationDate: declarationDate ?? this.declarationDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        distributingCompanyId,
        recipientEntityId,
        declaredAmount,
        dividendTaxRate,
        netDividendPaid,
        declarationDate,
        createdAt,
      ];
}
