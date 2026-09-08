import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../entities/asset_entity.dart';

/// Outcome of running depreciation for one asset over one period.
class DepreciationResult extends Equatable {
  const DepreciationResult({
    required this.depreciationAmount,
    required this.accumulatedDepreciation,
    required this.endingBookValue,
    required this.isFullyDepreciated,
  });

  final double depreciationAmount;
  final double accumulatedDepreciation;
  final double endingBookValue;
  final bool isFullyDepreciated;

  @override
  List<Object?> get props => <Object?>[
        depreciationAmount,
        accumulatedDepreciation,
        endingBookValue,
        isFullyDepreciated,
      ];
}

/// One balancing ledger line posted for a depreciation or disposal event.
class AssetJournalEntry extends Equatable {
  const AssetJournalEntry({
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

/// Computes straight-line, declining-balance, and tax-normative depreciation.
///
/// Straight-line: `(purchasePrice - salvageValue) / usefulLifeMonths`.
/// Declining balance: rate `1 - (salvageValue / purchasePrice)^(1/n)` applied
/// to the carrying amount each period.
/// Tax normative: cost × annual normative rate ÷ 12, capped by remaining
/// depreciable base (building 7%, machinery 20%, vehicles 25%,
/// computers/software 25%).
class AssetDepreciationEngine {
  const AssetDepreciationEngine();

  static const double _epsilon = 0.000001;

  /// Ledger account for accumulated depreciation (contra-asset).
  static const String accumulatedDepreciationAccount = '142';

  /// Ledger account for the depreciation expense.
  static const String depreciationExpenseAccount = '515';

  /// Ledger account for a disposal write-off of remaining book value.
  static const String disposalLossAccount = '516';

  /// Ledger account for the gross fixed asset cost.
  static const String fixedAssetAccount = '141';

  /// Monthly depreciation amount for [asset] without mutating state.
  double monthlyDepreciation(AssetEntity asset) {
    if (asset.bookValue <= asset.salvageValue + _epsilon ||
        asset.bookValue <= _epsilon) {
      return 0;
    }
    final double amount = _grossMonthlyAmount(asset);
    return math.min(amount, asset.bookValue - asset.salvageValue);
  }

  /// Runs one more period of depreciation for [asset].
  DepreciationResult depreciate(AssetEntity asset) {
    final double amount = monthlyDepreciation(asset);
    final double accumulated = asset.accumulatedDepreciation + amount;
    final double endingBookValue = asset.bookValue - amount;
    final bool fullyDepreciated = endingBookValue <= asset.salvageValue + _epsilon;
    return DepreciationResult(
      depreciationAmount: amount,
      accumulatedDepreciation: accumulated,
      endingBookValue: fullyDepreciated
          ? asset.salvageValue
          : endingBookValue,
      isFullyDepreciated: fullyDepreciated,
    );
  }

  /// Annual normative tax rate for [category], expressed as a fraction.
  double normativeAnnualRate(AssetCategory category) {
    return switch (category) {
      AssetCategory.buildings => 0.07,
      AssetCategory.machinery => 0.20,
      AssetCategory.vehicles => 0.25,
      AssetCategory.computers => 0.25,
      AssetCategory.intangible => 0.20,
    };
  }

  double _grossMonthlyAmount(AssetEntity asset) {
    switch (asset.depreciationMethod) {
      case DepreciationMethod.straightLine:
        return _straightLineMonthly(asset);
      case DepreciationMethod.decliningBalance:
        return _decliningBalanceMonthly(asset);
      case DepreciationMethod.taxNormative:
        return _taxNormativeMonthly(asset);
    }
  }

  double _straightLineMonthly(AssetEntity asset) {
    if (asset.usefulLifeMonths <= 0) {
      return 0;
    }
    return asset.depreciableBase / asset.usefulLifeMonths;
  }

  double _decliningBalanceMonthly(AssetEntity asset) {
    if (asset.usefulLifeMonths <= 0 || asset.bookValue <= _epsilon) {
      return 0;
    }
    // The textbook rate requires a positive salvage value; fall back to the
    // straight-line amount when no residual value is declared.
    if (asset.salvageValue <= _epsilon) {
      return _straightLineMonthly(asset);
    }
    final double ratio = asset.salvageValue / asset.purchasePrice;
    final double rate = 1 - math.pow(ratio, 1 / asset.usefulLifeMonths);
    return asset.bookValue * rate;
  }

  double _taxNormativeMonthly(AssetEntity asset) {
    final double annual = asset.purchasePrice * normativeAnnualRate(asset.category);
    return annual / 12;
  }
}
