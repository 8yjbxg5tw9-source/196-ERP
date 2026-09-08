import 'package:equatable/equatable.dart';

import '../entities/deferred_tax_calculation_entity.dart';
import '../entities/deferred_tax_journal_entry.dart';
import '../entities/tax_base_comparison.dart';
import '../entities/temporary_difference_entity.dart';

/// Bundle produced by one engine run: the itemized differences, the aggregate
/// calculation, and (when the net position moved) the period-end journal.
class DeferredTaxComputation extends Equatable {
  const DeferredTaxComputation({
    required this.items,
    required this.calculation,
    this.journal,
  });

  final List<TemporaryDifferenceEntity> items;
  final DeferredTaxCalculationEntity calculation;
  final DeferredTaxJournalEntry? journal;

  @override
  List<Object?> get props => <Object?>[items, calculation, journal];
}

/// IAS 12 deferred tax engine.
///
/// Classifies the signed gap between accounting and tax carrying values into
/// taxable/deductible temporary differences, aggregates DTA/DTL, computes the
/// period net movement, and generates the balancing journal:
///
/// - Expense movement: Dr Deferred Tax Expense / Cr Deferred Tax Liability.
/// - Benefit movement:  Dr Deferred Tax Asset / Cr Deferred Tax Benefit.
class DeferredTaxEngine {
  const DeferredTaxEngine();

  static const double _epsilon = 0.000001;

  static const String deferredTaxAssetAccount = '143';
  static const String deferredTaxLiabilityAccount = '241';
  static const String deferredTaxExpenseAccount = '602';
  static const String deferredTaxBenefitAccount = '404';

  DeferredTaxComputation compute({
    required String id,
    required String companyId,
    required int periodYear,
    required double taxRate,
    required double priorYearNetPosition,
    required double accountingNetProfit,
    required List<TaxBaseComparison> comparisons,
    DateTime? asOfDate,
  }) {
    final List<TemporaryDifferenceEntity> items = <TemporaryDifferenceEntity>[];
    double totalDta = 0;
    double totalDtl = 0;

    for (int index = 0; index < comparisons.length; index++) {
      final TaxBaseComparison comparison = comparisons[index];
      final double signed = comparison.signedDifference;
      if (signed.abs() <= _epsilon) {
        continue;
      }

      final TemporaryDifferenceType differenceType;
      final DeferredTaxType deferredTaxType;
      if (comparison.nature == BalanceSheetNature.asset) {
        if (signed > 0) {
          differenceType = TemporaryDifferenceType.taxableTemporary;
          deferredTaxType = DeferredTaxType.deferredTaxLiability;
        } else {
          differenceType = TemporaryDifferenceType.deductibleTemporary;
          deferredTaxType = DeferredTaxType.deferredTaxAsset;
        }
      } else {
        if (signed > 0) {
          differenceType = TemporaryDifferenceType.deductibleTemporary;
          deferredTaxType = DeferredTaxType.deferredTaxAsset;
        } else {
          differenceType = TemporaryDifferenceType.taxableTemporary;
          deferredTaxType = DeferredTaxType.deferredTaxLiability;
        }
      }

      final double amount = signed.abs();
      final double deferred = amount * taxRate;
      items.add(
        TemporaryDifferenceEntity(
          id: 'td-$companyId-$periodYear-$index',
          companyId: companyId,
          calculationId: id,
          assetLiabilityName: comparison.name,
          accountingBookValue: comparison.accountingValue,
          taxCarryingBase: comparison.taxBase,
          differenceType: differenceType,
          temporaryDifferenceAmount: amount,
          statutoryTaxRate: taxRate,
          deferredTaxType: deferredTaxType,
          deferredAmount: deferred,
          createdAt: asOfDate,
        ),
      );
      if (deferredTaxType == DeferredTaxType.deferredTaxAsset) {
        totalDta += deferred;
      } else {
        totalDtl += deferred;
      }
    }

    final double netPosition = totalDta - totalDtl;
    final double expenseBenefit = priorYearNetPosition - netPosition;
    final DeferredTaxJournalEntry? journal = expenseBenefit.abs() <= _epsilon
        ? null
        : _buildJournal(
            companyId: companyId,
            periodYear: periodYear,
            movement: expenseBenefit,
            sourceId: id,
            asOfDate: asOfDate,
          );

    return DeferredTaxComputation(
      items: items,
      calculation: DeferredTaxCalculationEntity(
        id: id,
        companyId: companyId,
        periodYear: periodYear,
        totalDta: totalDta,
        totalDtl: totalDtl,
        netDeferredTaxPosition: netPosition,
        priorYearNetPosition: priorYearNetPosition,
        periodDeferredTaxExpenseBenefit: expenseBenefit,
        isPosted: false,
        statutoryTaxRate: taxRate,
        accountingNetProfit: accountingNetProfit,
        createdAt: asOfDate,
      ),
      journal: journal,
    );
  }

  /// Generates the self-balancing period-end movement entry. [movement] is
  /// the deferred tax expense (positive) or benefit (negative).
  DeferredTaxJournalEntry _buildJournal({
    required String companyId,
    required int periodYear,
    required double movement,
    required String sourceId,
    DateTime? asOfDate,
  }) {
    if (movement > 0) {
      return DeferredTaxJournalEntry(
        companyId: companyId,
        entryDate: asOfDate ?? DateTime(periodYear, 12, 31),
        description: 'Deferred tax expense — IAS 12 ($periodYear)',
        debitAccount: deferredTaxExpenseAccount,
        creditAccount: deferredTaxLiabilityAccount,
        amount: movement,
        sourceId: sourceId,
      );
    }
    return DeferredTaxJournalEntry(
      companyId: companyId,
      entryDate: asOfDate ?? DateTime(periodYear, 12, 31),
      description: 'Deferred tax benefit — IAS 12 ($periodYear)',
      debitAccount: deferredTaxAssetAccount,
      creditAccount: deferredTaxBenefitAccount,
      amount: -movement,
      sourceId: sourceId,
    );
  }
}
