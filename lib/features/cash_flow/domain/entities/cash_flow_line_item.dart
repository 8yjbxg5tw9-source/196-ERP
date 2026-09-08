import 'package:equatable/equatable.dart';

/// IAS 7 activity section: operating, investing, or financing.
enum CashFlowCategory { operating, investing, financing }

extension CashFlowCategoryLabel on CashFlowCategory {
  String get label => switch (this) {
        CashFlowCategory.operating => 'Operating',
        CashFlowCategory.investing => 'Investing',
        CashFlowCategory.financing => 'Financing',
      };
}

/// Direction of a cash movement.
enum CashFlowActivity { inflow, outflow }

extension CashFlowActivityLabel on CashFlowActivity {
  String get label => switch (this) {
        CashFlowActivity.inflow => 'Inflow',
        CashFlowActivity.outflow => 'Outflow',
      };
}

/// One classified line of the cash flow statement. [amount] is stored as a
/// positive magnitude and [activityType] carries the direction.
class CashFlowLineItem extends Equatable {
  const CashFlowLineItem({
    required this.id,
    required this.accountCode,
    required this.description,
    required this.amount,
    required this.category,
    required this.activityType,
  });

  final String id;
  final String accountCode;
  final String description;
  final double amount;
  final CashFlowCategory category;
  final CashFlowActivity activityType;

  /// Signed amount (positive for inflow, negative for outflow).
  double get signedAmount => activityType == CashFlowActivity.inflow
      ? amount
      : -amount;

  CashFlowLineItem copyWith({
    String? id,
    String? accountCode,
    String? description,
    double? amount,
    CashFlowCategory? category,
    CashFlowActivity? activityType,
  }) {
    return CashFlowLineItem(
      id: id ?? this.id,
      accountCode: accountCode ?? this.accountCode,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      activityType: activityType ?? this.activityType,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        accountCode,
        description,
        amount,
        category,
        activityType,
      ];
}
