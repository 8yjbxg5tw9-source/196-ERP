import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../entities/intercompany_loan_entity.dart';

/// A reciprocal double-entry plan to be persisted as one journal line.
class JournalEntryPlan extends Equatable {
  const JournalEntryPlan({
    required this.companyId,
    required this.entryDate,
    required this.description,
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.sourceType,
    required this.sourceId,
  });

  final String companyId;
  final DateTime entryDate;
  final String description;
  final String debitAccount;
  final String creditAccount;
  final double amount;
  final String sourceType;
  final String sourceId;

  @override
  List<Object?> get props => <Object?>[
        companyId,
        entryDate,
        description,
        debitAccount,
        creditAccount,
        amount,
        sourceType,
        sourceId,
      ];
}

/// The gross / WHT / net breakdown for one accrual period.
class InterestAccrualResult extends Equatable {
  const InterestAccrualResult({
    required this.grossInterest,
    required this.withholdingTax,
    required this.netInterest,
  });

  final double grossInterest;
  final double withholdingTax;
  final double netInterest;

  @override
  List<Object?> get props =>
      <Object?>[grossInterest, withholdingTax, netInterest];
}

/// One generated line of an interest amortization schedule.
class InterestScheduleLine extends Equatable {
  const InterestScheduleLine({
    required this.periodDate,
    required this.grossInterest,
    required this.withholdingTax,
    required this.netInterest,
  });

  final DateTime periodDate;
  final double grossInterest;
  final double withholdingTax;
  final double netInterest;

  @override
  List<Object?> get props =>
      <Object?>[periodDate, grossInterest, withholdingTax, netInterest];
}

/// Pure interest accrual, WHT, and reciprocal journal-entry planning.
class IntercompanyEngine {
  const IntercompanyEngine();

  /// Simple interest: principal × rate × (days / 365).
  double simpleInterest({
    required double principal,
    required double annualRate,
    required int days,
  }) {
    return _round(principal * (annualRate / 100) * (days / 365));
  }

  /// Compound interest under the loan's compounding convention.
  double compoundInterest({
    required double principal,
    required double annualRate,
    required int days,
    required CompoundingFrequency frequency,
  }) {
    final double rate = annualRate / 100;
    switch (frequency) {
      case CompoundingFrequency.simple:
        return simpleInterest(
          principal: principal,
          annualRate: annualRate,
          days: days,
        );
      case CompoundingFrequency.monthly:
        final double periods = days / 30;
        return _round(principal * (math.pow(1 + rate / 12, periods) - 1));
      case CompoundingFrequency.annually:
        final double periods = days / 365;
        return _round(principal * (math.pow(1 + rate, periods) - 1));
    }
  }

  /// Computes gross interest, withholding tax, and net interest for one period.
  InterestAccrualResult accrualFor({
    required double principal,
    required double annualRate,
    required int days,
    required CompoundingFrequency frequency,
    required double withholdingTaxRate,
  }) {
    final double gross = compoundInterest(
      principal: principal,
      annualRate: annualRate,
      days: days,
      frequency: frequency,
    );
    final double tax = _round(gross * withholdingTaxRate / 100);
    final double net = _round(gross - tax);
    return InterestAccrualResult(
      grossInterest: gross,
      withholdingTax: tax,
      netInterest: net,
    );
  }

  /// Generates a monthly amortization schedule from [start] to [end].
  List<InterestScheduleLine> buildSchedule({
    required double principal,
    required double annualRate,
    required DateTime start,
    required DateTime end,
    required CompoundingFrequency frequency,
    required double withholdingTaxRate,
  }) {
    final List<InterestScheduleLine> lines = <InterestScheduleLine>[];
    if (!end.isAfter(start)) {
      return lines;
    }

    DateTime cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(end)) {
      final DateTime next = DateTime(cursor.year, cursor.month + 1, cursor.day);
      final DateTime periodEnd = next.isAfter(end) ? end : next;
      final int days = periodEnd.difference(cursor).inDays;
      if (days > 0) {
        final InterestAccrualResult result = accrualFor(
          principal: principal,
          annualRate: annualRate,
          days: days,
          frequency: frequency,
          withholdingTaxRate: withholdingTaxRate,
        );
        lines.add(
          InterestScheduleLine(
            periodDate: periodEnd,
            grossInterest: result.grossInterest,
            withholdingTax: result.withholdingTax,
            netInterest: result.netInterest,
          ),
        );
      }
      cursor = next;
    }
    return lines;
  }

  /// Reciprocal entries recorded when the loan is first disbursed.
  List<JournalEntryPlan> loanDisbursementPlans({
    required String lenderCompanyId,
    required String borrowerCompanyId,
    required double principal,
    required DateTime date,
    required String sourceId,
  }) {
    return <JournalEntryPlan>[
      JournalEntryPlan(
        companyId: lenderCompanyId,
        entryDate: date,
        description: 'Intercompany loan disbursement to $borrowerCompanyId',
        debitAccount: _loanReceivableAccount,
        creditAccount: _cashAccount,
        amount: principal,
        sourceType: 'intercompany_loan',
        sourceId: sourceId,
      ),
      JournalEntryPlan(
        companyId: borrowerCompanyId,
        entryDate: date,
        description: 'Intercompany loan received from $lenderCompanyId',
        debitAccount: _cashAccount,
        creditAccount: _loanPayableAccount,
        amount: principal,
        sourceType: 'intercompany_loan',
        sourceId: sourceId,
      ),
    ];
  }

  /// Reciprocal entries for a single interest accrual period.
  List<JournalEntryPlan> interestAccrualPlans({
    required String lenderCompanyId,
    required String borrowerCompanyId,
    required DateTime date,
    required InterestAccrualResult accrual,
    required String sourceId,
  }) {
    return <JournalEntryPlan>[
      // Borrower: recognise the expense and the two liabilities.
      JournalEntryPlan(
        companyId: borrowerCompanyId,
        entryDate: date,
        description: 'Interest expense on loan from $lenderCompanyId',
        debitAccount: _interestExpenseAccount,
        creditAccount: _taxPayableAccount,
        amount: accrual.withholdingTax,
        sourceType: 'interest_accrual',
        sourceId: sourceId,
      ),
      JournalEntryPlan(
        companyId: borrowerCompanyId,
        entryDate: date,
        description: 'Net interest payable on loan from $lenderCompanyId',
        debitAccount: _interestExpenseAccount,
        creditAccount: _loanPayableAccount,
        amount: accrual.netInterest,
        sourceType: 'interest_accrual',
        sourceId: sourceId,
      ),
      // Lender: recognise net interest income as a receivable.
      JournalEntryPlan(
        companyId: lenderCompanyId,
        entryDate: date,
        description: 'Interest income on loan to $borrowerCompanyId',
        debitAccount: _loanReceivableAccount,
        creditAccount: _interestIncomeAccount,
        amount: accrual.netInterest,
        sourceType: 'interest_accrual',
        sourceId: sourceId,
      ),
    ];
  }

  /// Entries recorded for a declared dividend distribution.
  List<JournalEntryPlan> dividendPlans({
    required String distributingCompanyId,
    required String recipientEntityId,
    required double declaredAmount,
    required double withholdingTax,
    required double netPaid,
    required DateTime date,
    required String sourceId,
  }) {
    return <JournalEntryPlan>[
      JournalEntryPlan(
        companyId: distributingCompanyId,
        entryDate: date,
        description: 'Dividend declared to $recipientEntityId',
        debitAccount: _retainedEarningsAccount,
        creditAccount: _taxPayableAccount,
        amount: withholdingTax,
        sourceType: 'dividend',
        sourceId: sourceId,
      ),
      JournalEntryPlan(
        companyId: distributingCompanyId,
        entryDate: date,
        description: 'Net dividend payable to $recipientEntityId',
        debitAccount: _retainedEarningsAccount,
        creditAccount: _loanPayableAccount,
        amount: netPaid,
        sourceType: 'dividend',
        sourceId: sourceId,
      ),
      JournalEntryPlan(
        companyId: recipientEntityId,
        entryDate: date,
        description: 'Dividend income from $distributingCompanyId',
        debitAccount: _receivableAccount,
        creditAccount: _interestIncomeAccount,
        amount: netPaid,
        sourceType: 'dividend',
        sourceId: sourceId,
      ),
    ];
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 100).roundToDouble() / 100;
  }

  // Chart-of-accounts posting codes (free-text in journal entries).
  static const String _cashAccount = '101';
  static const String _loanReceivableAccount = '211';
  static const String _loanPayableAccount = '511';
  static const String _interestExpenseAccount = '601';
  static const String _interestIncomeAccount = '403';
  static const String _taxPayableAccount = '231';
  static const String _retainedEarningsAccount = '302';
  static const String _receivableAccount = '121';
}
