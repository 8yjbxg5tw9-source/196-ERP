import 'package:equatable/equatable.dart';

import '../revaluation/fx_balance_entity.dart';

/// The computed mark-to-market adjustment for one foreign balance.
class FxRevaluationResult extends Equatable {
  const FxRevaluationResult({
    required this.balance,
    required this.currentExchangeRate,
    required this.revaluedValueBaseCurrency,
    required this.unrealizedGainLoss,
    required this.type,
  });

  final FxBalanceEntity balance;
  final double currentExchangeRate;
  final double revaluedValueBaseCurrency;
  final double unrealizedGainLoss;
  final FxGainLossType type;

  @override
  List<Object?> get props => <Object?>[
        balance,
        currentExchangeRate,
        revaluedValueBaseCurrency,
        unrealizedGainLoss,
        type,
      ];
}

/// Pure foreign-exchange revaluation formulas.
class FxRevaluationEngine {
  const FxRevaluationEngine();

  /// Mark-to-market base value: foreign amount × closing rate.
  double revalue({
    required double foreignAmount,
    required double closingRate,
  }) {
    return _round(foreignAmount * closingRate);
  }

  /// Unrealized gain/loss with the correct sign for the balance type.
  ///
  /// Assets appreciate when the base-currency value rises; liabilities
  /// appreciate (a gain) when the base-currency value falls.
  double unrealized({
    required FxBalanceEntity balance,
    required double closingRate,
  }) {
    final double revalued = revalue(
      foreignAmount: balance.foreignAmount,
      closingRate: closingRate,
    );
    final double difference = balance.balanceType == FxBalanceType.asset
        ? revalued - balance.bookValueBaseCurrency
        : balance.bookValueBaseCurrency - revalued;
    return _round(difference);
  }

  /// Realized difference when a foreign payment settles at a different rate
  /// than the invoice was originally booked at.
  double realizedDifference({
    required double paymentBaseAtSettlement,
    required double invoiceBaseAtBooking,
  }) {
    return _round(paymentBaseAtSettlement - invoiceBaseAtBooking);
  }

  FxGainLossType classify(double difference) {
    if (difference > 0) {
      return FxGainLossType.gain;
    }
    if (difference < 0) {
      return FxGainLossType.loss;
    }
    return FxGainLossType.neutral;
  }

  /// Computes the mark-to-market result for a single balance.
  FxRevaluationResult evaluate(FxBalanceEntity balance, double closingRate) {
    final double revalued = revalue(
      foreignAmount: balance.foreignAmount,
      closingRate: closingRate,
    );
    final double difference = unrealized(
      balance: balance,
      closingRate: closingRate,
    );
    return FxRevaluationResult(
      balance: balance,
      currentExchangeRate: closingRate,
      revaluedValueBaseCurrency: revalued,
      unrealizedGainLoss: difference,
      type: classify(difference),
    );
  }

  static double _round(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 100).roundToDouble() / 100;
  }
}
