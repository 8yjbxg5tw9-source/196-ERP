import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import 'cash_flow_line_item.dart';

/// IAS 7 presentation basis for the statement.
enum CashFlowMethod { direct, indirect }

extension CashFlowMethodLabel on CashFlowMethod {
  String get label => switch (this) {
        CashFlowMethod.direct => 'Direct method',
        CashFlowMethod.indirect => 'Indirect method',
      };

  String get shortLabel => switch (this) {
        CashFlowMethod.direct => 'Direct',
        CashFlowMethod.indirect => 'Indirect',
      };
}

/// A compiled statement of cash flows for one company and date range.
class CashFlowStatementEntity extends Equatable {
  const CashFlowStatementEntity({
    required this.id,
    required this.companyId,
    required this.dateRange,
    required this.method,
    required this.operatingCashFlow,
    required this.investingCashFlow,
    required this.financingCashFlow,
    required this.beginningCashBalance,
    required this.netCashChange,
    required this.endingCashBalance,
    this.lineItems = const <CashFlowLineItem>[],
  });

  final String id;
  final String companyId;
  final DateTimeRange dateRange;
  final CashFlowMethod method;
  final double operatingCashFlow;
  final double investingCashFlow;
  final double financingCashFlow;
  final double beginningCashBalance;
  final double netCashChange;
  final double endingCashBalance;
  final List<CashFlowLineItem> lineItems;

  List<CashFlowLineItem> itemsFor(CashFlowCategory category) {
    return lineItems
        .where((CashFlowLineItem item) => item.category == category)
        .toList(growable: false);
  }

  CashFlowStatementEntity copyWith({
    String? id,
    String? companyId,
    DateTimeRange? dateRange,
    CashFlowMethod? method,
    double? operatingCashFlow,
    double? investingCashFlow,
    double? financingCashFlow,
    double? beginningCashBalance,
    double? netCashChange,
    double? endingCashBalance,
    List<CashFlowLineItem>? lineItems,
  }) {
    return CashFlowStatementEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      dateRange: dateRange ?? this.dateRange,
      method: method ?? this.method,
      operatingCashFlow: operatingCashFlow ?? this.operatingCashFlow,
      investingCashFlow: investingCashFlow ?? this.investingCashFlow,
      financingCashFlow: financingCashFlow ?? this.financingCashFlow,
      beginningCashBalance: beginningCashBalance ?? this.beginningCashBalance,
      netCashChange: netCashChange ?? this.netCashChange,
      endingCashBalance: endingCashBalance ?? this.endingCashBalance,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        dateRange,
        method,
        operatingCashFlow,
        investingCashFlow,
        financingCashFlow,
        beginningCashBalance,
        netCashChange,
        endingCashBalance,
        lineItems,
      ];
}
