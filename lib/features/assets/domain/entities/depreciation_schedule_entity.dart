import 'package:equatable/equatable.dart';

/// One period line of an asset's amortization schedule.
class DepreciationScheduleEntity extends Equatable {
  const DepreciationScheduleEntity({
    required this.id,
    required this.assetId,
    required this.companyId,
    required this.periodDate,
    required this.depreciationAmount,
    required this.accumulatedAmount,
    required this.endingBookValue,
    this.isPosted = false,
    this.createdAt,
  });

  final String id;
  final String assetId;
  final String companyId;
  final DateTime periodDate;
  final double depreciationAmount;
  final double accumulatedAmount;
  final double endingBookValue;
  final bool isPosted;
  final DateTime? createdAt;

  DepreciationScheduleEntity copyWith({
    String? id,
    String? assetId,
    String? companyId,
    DateTime? periodDate,
    double? depreciationAmount,
    double? accumulatedAmount,
    double? endingBookValue,
    bool? isPosted,
    DateTime? createdAt,
  }) {
    return DepreciationScheduleEntity(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      companyId: companyId ?? this.companyId,
      periodDate: periodDate ?? this.periodDate,
      depreciationAmount: depreciationAmount ?? this.depreciationAmount,
      accumulatedAmount: accumulatedAmount ?? this.accumulatedAmount,
      endingBookValue: endingBookValue ?? this.endingBookValue,
      isPosted: isPosted ?? this.isPosted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        assetId,
        companyId,
        periodDate,
        depreciationAmount,
        accumulatedAmount,
        endingBookValue,
        isPosted,
        createdAt,
      ];
}
