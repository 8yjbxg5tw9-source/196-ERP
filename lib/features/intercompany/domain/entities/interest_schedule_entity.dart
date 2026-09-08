import 'package:equatable/equatable.dart';

/// One period line of an intercompany loan's interest schedule.
class InterestScheduleEntity extends Equatable {
  const InterestScheduleEntity({
    required this.id,
    required this.loanId,
    required this.periodDate,
    required this.grossInterest,
    required this.withholdingTax,
    required this.netInterest,
    this.isAccrued = false,
    this.createdAt,
  });

  final String id;
  final String loanId;
  final DateTime periodDate;
  final double grossInterest;
  final double withholdingTax;
  final double netInterest;
  final bool isAccrued;
  final DateTime? createdAt;

  InterestScheduleEntity copyWith({
    String? id,
    String? loanId,
    DateTime? periodDate,
    double? grossInterest,
    double? withholdingTax,
    double? netInterest,
    bool? isAccrued,
    DateTime? createdAt,
  }) {
    return InterestScheduleEntity(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      periodDate: periodDate ?? this.periodDate,
      grossInterest: grossInterest ?? this.grossInterest,
      withholdingTax: withholdingTax ?? this.withholdingTax,
      netInterest: netInterest ?? this.netInterest,
      isAccrued: isAccrued ?? this.isAccrued,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        loanId,
        periodDate,
        grossInterest,
        withholdingTax,
        netInterest,
        isAccrued,
        createdAt,
      ];
}
