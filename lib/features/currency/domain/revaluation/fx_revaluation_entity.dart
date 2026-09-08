import 'package:equatable/equatable.dart';

/// A period-end FX revaluation run and its aggregate P&L impact.
class FxRevaluationEntity extends Equatable {
  const FxRevaluationEntity({
    required this.id,
    required this.companyId,
    required this.revaluationDate,
    required this.periodMonth,
    required this.periodYear,
    this.totalUnrealizedGain = 0,
    this.totalUnrealizedLoss = 0,
    this.netFxImpact = 0,
    this.isPosted = false,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final DateTime revaluationDate;
  final int periodMonth;
  final int periodYear;
  final double totalUnrealizedGain;
  final double totalUnrealizedLoss;
  final double netFxImpact;
  final bool isPosted;
  final DateTime? createdAt;

  FxRevaluationEntity copyWith({
    String? id,
    String? companyId,
    DateTime? revaluationDate,
    int? periodMonth,
    int? periodYear,
    double? totalUnrealizedGain,
    double? totalUnrealizedLoss,
    double? netFxImpact,
    bool? isPosted,
    DateTime? createdAt,
  }) {
    return FxRevaluationEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      revaluationDate: revaluationDate ?? this.revaluationDate,
      periodMonth: periodMonth ?? this.periodMonth,
      periodYear: periodYear ?? this.periodYear,
      totalUnrealizedGain: totalUnrealizedGain ?? this.totalUnrealizedGain,
      totalUnrealizedLoss: totalUnrealizedLoss ?? this.totalUnrealizedLoss,
      netFxImpact: netFxImpact ?? this.netFxImpact,
      isPosted: isPosted ?? this.isPosted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        revaluationDate,
        periodMonth,
        periodYear,
        totalUnrealizedGain,
        totalUnrealizedLoss,
        netFxImpact,
        isPosted,
        createdAt,
      ];
}
