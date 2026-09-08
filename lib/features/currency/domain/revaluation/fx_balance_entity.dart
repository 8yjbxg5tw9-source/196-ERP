import 'package:equatable/equatable.dart';

/// Whether a foreign balance is an asset (bank / receivable) or a liability
/// (payable). This determines the sign of the FX gain/loss.
enum FxBalanceType { asset, liability }

extension FxBalanceTypeLabel on FxBalanceType {
  String get label => switch (this) {
        FxBalanceType.asset => 'Asset',
        FxBalanceType.liability => 'Liability',
      };
}

/// Classification of a computed FX difference.
enum FxGainLossType { gain, loss, neutral }

extension FxGainLossTypeLabel on FxGainLossType {
  String get label => switch (this) {
        FxGainLossType.gain => 'Gain',
        FxGainLossType.loss => 'Loss',
        FxGainLossType.neutral => '—',
      };
}

/// An open foreign-currency balance subject to mark-to-market revaluation.
class FxBalanceEntity extends Equatable {
  const FxBalanceEntity({
    required this.id,
    required this.companyId,
    required this.accountId,
    required this.foreignCurrency,
    required this.foreignAmount,
    required this.bookValueBaseCurrency,
    this.balanceType = FxBalanceType.asset,
    this.currentExchangeRate = 0,
    this.revaluedValueBaseCurrency = 0,
    this.unrealizedGainLoss = 0,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String accountId;
  final String foreignCurrency;
  final double foreignAmount;
  final double bookValueBaseCurrency;
  final FxBalanceType balanceType;
  final double currentExchangeRate;
  final double revaluedValueBaseCurrency;
  final double unrealizedGainLoss;
  final DateTime? createdAt;

  FxBalanceEntity copyWith({
    String? id,
    String? companyId,
    String? accountId,
    String? foreignCurrency,
    double? foreignAmount,
    double? bookValueBaseCurrency,
    FxBalanceType? balanceType,
    double? currentExchangeRate,
    double? revaluedValueBaseCurrency,
    double? unrealizedGainLoss,
    DateTime? createdAt,
  }) {
    return FxBalanceEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      accountId: accountId ?? this.accountId,
      foreignCurrency: foreignCurrency ?? this.foreignCurrency,
      foreignAmount: foreignAmount ?? this.foreignAmount,
      bookValueBaseCurrency: bookValueBaseCurrency ?? this.bookValueBaseCurrency,
      balanceType: balanceType ?? this.balanceType,
      currentExchangeRate: currentExchangeRate ?? this.currentExchangeRate,
      revaluedValueBaseCurrency:
          revaluedValueBaseCurrency ?? this.revaluedValueBaseCurrency,
      unrealizedGainLoss: unrealizedGainLoss ?? this.unrealizedGainLoss,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        accountId,
        foreignCurrency,
        foreignAmount,
        bookValueBaseCurrency,
        balanceType,
        currentExchangeRate,
        revaluedValueBaseCurrency,
        unrealizedGainLoss,
        createdAt,
      ];
}
