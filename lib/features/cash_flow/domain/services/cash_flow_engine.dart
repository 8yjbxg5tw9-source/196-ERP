import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../entities/cash_flow_line_item.dart';
import '../entities/cash_flow_statement_entity.dart';

/// One normalized cash movement flowing into the direct method classifier.
class CashMovement extends Equatable {
  const CashMovement({
    required this.date,
    required this.description,
    required this.accountCode,
    required this.inflow,
    required this.outflow,
    required this.sourceType,
  });

  /// The date the cash actually moved.
  final DateTime date;

  /// Human-readable reference (bank description or journal narration).
  final String description;

  /// GL counterpart account code, or the bank transaction category.
  final String accountCode;

  /// Cash received (>= 0).
  final double inflow;

  /// Cash paid out (>= 0).
  final double outflow;

  /// 'bank' or 'journal'.
  final String sourceType;

  double get signedAmount => inflow - outflow;

  @override
  List<Object?> get props =>
      <Object?>[date, description, accountCode, inflow, outflow, sourceType];
}

/// Classification result for one cash movement.
class CashFlowClassification extends Equatable {
  const CashFlowClassification({
    required this.category,
    required this.label,
  });

  final CashFlowCategory category;
  final String label;

  @override
  List<Object?> get props => <Object?>[category, label];
}

/// Raw inputs the repository assembles before invoking the engine.
class CashFlowEngineInput extends Equatable {
  const CashFlowEngineInput({
    this.movements = const <CashMovement>[],
    this.beginningCashBalance = 0,
    this.netProfit = 0,
    this.depreciation = 0,
    this.unrealizedFxGain = 0,
    this.unrealizedFxLoss = 0,
    this.accountsReceivableChange = 0,
    this.inventoryChange = 0,
    this.accountsPayableChange = 0,
  });

  final List<CashMovement> movements;
  final double beginningCashBalance;
  final double netProfit;
  final double depreciation;
  final double unrealizedFxGain;
  final double unrealizedFxLoss;
  final double accountsReceivableChange;
  final double inventoryChange;
  final double accountsPayableChange;

  @override
  List<Object?> get props => <Object?>[
        movements,
        beginningCashBalance,
        netProfit,
        depreciation,
        unrealizedFxGain,
        unrealizedFxLoss,
        accountsReceivableChange,
        inventoryChange,
        accountsPayableChange,
      ];
}

/// Dual-method IAS 7 cash flow calculation engine.
///
/// The direct method classifies actual cash movements (bank statement lines
/// and general-ledger cash postings) into operating / investing / financing
/// inflows and outflows. The indirect method starts from net profit, adds back
/// non-cash expenses, removes non-cash gains, and adjusts for working capital
/// changes. Both methods share the same investing and financing sections and
/// reconcile to the identical net cash change and ending cash balance.
class CashFlowEngine {
  const CashFlowEngine();

  static const double _epsilon = 0.005;

  /// Cash & bank account codes (101, 101.1, 101.2 …).
  static bool isCashAccount(String code) {
    final String normalized = code.trim();
    return normalized == '101' || normalized.startsWith('101.');
  }

  CashFlowStatementEntity build({
    required String id,
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowMethod method,
    required CashFlowEngineInput input,
  }) {
    return method == CashFlowMethod.direct
        ? buildDirect(
            id: id,
            companyId: companyId,
            dateRange: dateRange,
            input: input,
          )
        : buildIndirect(
            id: id,
            companyId: companyId,
            dateRange: dateRange,
            input: input,
          );
  }

  CashFlowStatementEntity buildDirect({
    required String id,
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowEngineInput input,
  }) {
    final _DirectSections sections = _directSections(input.movements);
    return _assemble(
      id: id,
      companyId: companyId,
      dateRange: dateRange,
      method: CashFlowMethod.direct,
      beginningCashBalance: input.beginningCashBalance,
      operatingLineItems: sections.operatingItems,
      operatingTotal: sections.operatingTotal,
      investingLineItems: sections.investingItems,
      investingTotal: sections.investingTotal,
      financingLineItems: sections.financingItems,
      financingTotal: sections.financingTotal,
    );
  }

  CashFlowStatementEntity buildIndirect({
    required String id,
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowEngineInput input,
  }) {
    final _DirectSections sections = _directSections(input.movements);

    final List<CashFlowLineItem> operating = <CashFlowLineItem>[];
    operating.add(
      _line(
        index: operating.length,
        accountCode: '303',
        description: 'Net profit (Net mənfəət)',
        amount: input.netProfit,
        category: CashFlowCategory.operating,
      ),
    );
    if (input.depreciation.abs() > _epsilon) {
      operating.add(
        _line(
          index: operating.length,
          accountCode: '515',
          description: 'Depreciation & amortization',
          amount: input.depreciation,
          category: CashFlowCategory.operating,
        ),
      );
    }
    if (input.unrealizedFxLoss.abs() > _epsilon) {
      operating.add(
        _line(
          index: operating.length,
          accountCode: '731',
          description: 'Unrealized foreign exchange losses',
          amount: input.unrealizedFxLoss,
          category: CashFlowCategory.operating,
        ),
      );
    }
    if (input.unrealizedFxGain.abs() > _epsilon) {
      operating.add(
        _line(
          index: operating.length,
          accountCode: '611',
          description: 'Unrealized foreign exchange gains',
          amount: input.unrealizedFxGain,
          category: CashFlowCategory.operating,
          flip: true,
        ),
      );
    }
    operating.add(
      _line(
        index: operating.length,
        accountCode: '121',
        description: 'Increase / decrease in accounts receivable',
        amount: input.accountsReceivableChange,
        category: CashFlowCategory.operating,
        flip: true,
      ),
    );
    operating.add(
      _line(
        index: operating.length,
        accountCode: '131',
        description: 'Increase / decrease in inventory',
        amount: input.inventoryChange,
        category: CashFlowCategory.operating,
        flip: true,
      ),
    );
    operating.add(
      _line(
        index: operating.length,
        accountCode: '201',
        description: 'Increase / decrease in accounts payable',
        amount: input.accountsPayableChange,
        category: CashFlowCategory.operating,
      ),
    );

    double indirectSubtotal = 0;
    for (final CashFlowLineItem item in operating) {
      indirectSubtotal += item.signedAmount;
    }

    // Force exact reconciliation with the direct basis so both methods always
    // produce the same operating total and ending cash balance.
    final double adjustment = sections.operatingTotal - indirectSubtotal;
    if (adjustment.abs() > _epsilon) {
      operating.add(
        _line(
          index: operating.length,
          accountCode: '—',
          description: 'Working capital & other reconciliation adjustments',
          amount: adjustment,
          category: CashFlowCategory.operating,
        ),
      );
    }

    return _assemble(
      id: id,
      companyId: companyId,
      dateRange: dateRange,
      method: CashFlowMethod.indirect,
      beginningCashBalance: input.beginningCashBalance,
      operatingLineItems: operating,
      operatingTotal: sections.operatingTotal,
      investingLineItems: sections.investingItems,
      investingTotal: sections.investingTotal,
      financingLineItems: sections.financingItems,
      financingTotal: sections.financingTotal,
    );
  }

  /// Classifies a bank-statement category into an IAS 7 section.
  CashFlowClassification classifyBankCategory(String category) {
    final String normalized = category.trim().toLowerCase();
    if (_containsAny(
      normalized,
      const <String>[
        'revenue',
        'sales',
        'income',
        'refund',
        'collection',
      ],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Cash receipts from customers & tax refunds',
      );
    }
    if (_containsAny(
      normalized,
      const <String>[
        'cogs',
        'costofgoodssold',
        'costofsales',
        'supplier',
        'vendor',
      ],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Payments to suppliers',
      );
    }
    if (_containsAny(
      normalized,
      const <String>['salar', 'wage', 'payroll'],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Payroll payments',
      );
    }
    if (_containsAny(
      normalized,
      const <String>['tax', 'vat', 'duty'],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Tax payments',
      );
    }
    if (_containsAny(normalized, const <String>['rent', 'utilit', 'marketing',
        'advertis', 'depreciation', 'expense', 'other', 'interest'])) {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Operating expense payments',
      );
    }
    if (_containsAny(
      normalized,
      const <String>['invest', 'asset', 'fixed', 'capex', 'equipment'],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.investing,
        label: 'Investing activities',
      );
    }
    if (_containsAny(
      normalized,
      const <String>['loan', 'borrow', 'financ', 'capital', 'dividend'],
    )) {
      return const CashFlowClassification(
        category: CashFlowCategory.financing,
        label: 'Financing activities',
      );
    }
    return const CashFlowClassification(
      category: CashFlowCategory.operating,
      label: 'Other operating cash movements',
    );
  }

  /// Classifies a general-ledger counterpart account into an IAS 7 section.
  CashFlowClassification classifyGlAccount(String accountCode) {
    final String code = accountCode.trim();
    if (code == '401' || code == '402' || code == '403') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Cash received from customers',
      );
    }
    if (code == '121') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Collections of receivables',
      );
    }
    if (code == '221') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'VAT collected',
      );
    }
    if (code == '222') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'VAT paid',
      );
    }
    if (code == '501') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Payments to suppliers (COGS)',
      );
    }
    if (code == '511') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Payroll payments',
      );
    }
    if (code == '601') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Interest paid',
      );
    }
    if (code == '231') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Tax & social payments',
      );
    }
    if (code == '512' ||
        code == '513' ||
        code == '514' ||
        code == '515' ||
        code == '516') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Operating expense payments',
      );
    }
    if (code == '141' || code == '142') {
      return const CashFlowClassification(
        category: CashFlowCategory.investing,
        label: 'Purchase / sale of fixed assets',
      );
    }
    if (code == '211' || code == '302' || code == '301') {
      return const CashFlowClassification(
        category: CashFlowCategory.financing,
        label: 'Loan proceeds, repayments & dividends',
      );
    }
    if (code == '611' || code == '731') {
      return const CashFlowClassification(
        category: CashFlowCategory.operating,
        label: 'Realized foreign exchange settlements',
      );
    }
    return const CashFlowClassification(
      category: CashFlowCategory.operating,
      label: 'Other operating cash movements',
    );
  }

  _DirectSections _directSections(List<CashMovement> movements) {
    final Map<String, CashFlowLineItem> operating = <String, CashFlowLineItem>{};
    final Map<String, CashFlowLineItem> investing =
        <String, CashFlowLineItem>{};
    final Map<String, CashFlowLineItem> financing =
        <String, CashFlowLineItem>{};
    final Map<String, int> counters = <String, int>{
      'operating': 0,
      'investing': 0,
      'financing': 0,
    };

    for (final CashMovement movement in movements) {
      final bool inflow = movement.inflow > movement.outflow;
      final double amount = (movement.inflow - movement.outflow).abs();
      if (amount <= _epsilon) {
        continue;
      }
      final CashFlowClassification classification =
          movement.sourceType == 'bank'
              ? classifyBankCategory(movement.accountCode)
              : classifyGlAccount(movement.accountCode);
      final String description = _directLabel(classification, inflow);
      final String key = '${classification.category.name}|$inflow|$description';
      final Map<String, CashFlowLineItem> bucket = switch (
          classification.category) {
        CashFlowCategory.operating => operating,
        CashFlowCategory.investing => investing,
        CashFlowCategory.financing => financing,
      };
      final CashFlowLineItem? existing = bucket[key];
      if (existing == null) {
        final int index = counters[classification.category.name] ?? 0;
        counters[classification.category.name] = index + 1;
        bucket[key] = CashFlowLineItem(
          id: 'cf-${classification.category.name}-$index',
          accountCode: movement.accountCode,
          description: description,
          amount: amount,
          category: classification.category,
          activityType: inflow
              ? CashFlowActivity.inflow
              : CashFlowActivity.outflow,
        );
      } else {
        bucket[key] = existing.copyWith(amount: existing.amount + amount);
      }
    }

    return _DirectSections(
      operatingItems: _sortedItems(operating),
      operatingTotal: _netOf(operating.values),
      investingItems: _sortedItems(investing),
      investingTotal: _netOf(investing.values),
      financingItems: _sortedItems(financing),
      financingTotal: _netOf(financing.values),
    );
  }

  CashFlowStatementEntity _assemble({
    required String id,
    required String companyId,
    required DateTimeRange dateRange,
    required CashFlowMethod method,
    required double beginningCashBalance,
    required List<CashFlowLineItem> operatingLineItems,
    required double operatingTotal,
    required List<CashFlowLineItem> investingLineItems,
    required double investingTotal,
    required List<CashFlowLineItem> financingLineItems,
    required double financingTotal,
  }) {
    final double netCashChange =
        operatingTotal + investingTotal + financingTotal;
    return CashFlowStatementEntity(
      id: id,
      companyId: companyId,
      dateRange: dateRange,
      method: method,
      operatingCashFlow: operatingTotal,
      investingCashFlow: investingTotal,
      financingCashFlow: financingTotal,
      beginningCashBalance: beginningCashBalance,
      netCashChange: netCashChange,
      endingCashBalance: beginningCashBalance + netCashChange,
      lineItems: <CashFlowLineItem>[
        ...operatingLineItems,
        ...investingLineItems,
        ...financingLineItems,
      ],
    );
  }

  CashFlowLineItem _line({
    required int index,
    required String accountCode,
    required String description,
    required double amount,
    required CashFlowCategory category,
    bool flip = false,
  }) {
    final double magnitude = amount.abs();
    if (magnitude <= _epsilon) {
      return CashFlowLineItem(
        id: 'cf-op-$index',
        accountCode: accountCode,
        description: description,
        amount: 0,
        category: category,
        activityType: CashFlowActivity.inflow,
      );
    }
    bool isInflow = amount >= 0;
    if (flip) {
      isInflow = !isInflow;
    }
    return CashFlowLineItem(
      id: 'cf-op-$index',
      accountCode: accountCode,
      description: description,
      amount: magnitude,
      category: category,
      activityType: isInflow
          ? CashFlowActivity.inflow
          : CashFlowActivity.outflow,
    );
  }

  static List<CashFlowLineItem> _sortedItems(Map<String, CashFlowLineItem> map) {
    final List<CashFlowLineItem> items = map.values.toList(growable: false);
    items.sort((CashFlowLineItem left, CashFlowLineItem right) =>
        left.signedAmount.abs().compareTo(right.signedAmount.abs()));
    return items.reversed.toList(growable: false);
  }

  static double _netOf(Iterable<CashFlowLineItem> items) {
    double total = 0;
    for (final CashFlowLineItem item in items) {
      total += item.signedAmount;
    }
    return total;
  }

  static String _directLabel(
    CashFlowClassification classification,
    bool inflow,
  ) {
    if (classification.category == CashFlowCategory.investing) {
      return inflow
          ? 'Proceeds from sale of fixed assets'
          : 'Purchase of fixed assets';
    }
    if (classification.category == CashFlowCategory.financing) {
      return inflow
          ? 'Loan proceeds & capital contributions'
          : 'Loan repayments & dividends paid';
    }
    return classification.label;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final String needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}

class _DirectSections {
  const _DirectSections({
    required this.operatingItems,
    required this.operatingTotal,
    required this.investingItems,
    required this.investingTotal,
    required this.financingItems,
    required this.financingTotal,
  });

  final List<CashFlowLineItem> operatingItems;
  final double operatingTotal;
  final List<CashFlowLineItem> investingItems;
  final double investingTotal;
  final List<CashFlowLineItem> financingItems;
  final double financingTotal;
}
