import '../../domain/revaluation/fx_balance_entity.dart';

/// SQLite mapping for the `fx_balances` table.
class FxBalanceModel extends FxBalanceEntity {
  const FxBalanceModel({
    required super.id,
    required super.companyId,
    required super.accountId,
    required super.foreignCurrency,
    required super.foreignAmount,
    required super.bookValueBaseCurrency,
    super.balanceType,
    super.currentExchangeRate,
    super.revaluedValueBaseCurrency,
    super.unrealizedGainLoss,
    super.createdAt,
  });

  factory FxBalanceModel.fromMap(Map<String, Object?> map) {
    return FxBalanceModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      accountId: map['account_id']?.toString() ?? '',
      foreignCurrency: map['foreign_currency']?.toString() ?? 'USD',
      foreignAmount: _double(map['foreign_amount']),
      bookValueBaseCurrency: _double(map['book_value_base_currency']),
      balanceType: _type(map['balance_type']),
      currentExchangeRate: _double(map['current_exchange_rate']),
      revaluedValueBaseCurrency: _double(map['revalued_value_base_currency']),
      unrealizedGainLoss: _double(map['unrealized_gain_loss']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'account_id': accountId,
      'foreign_currency': foreignCurrency,
      'foreign_amount': foreignAmount,
      'book_value_base_currency': bookValueBaseCurrency,
      'balance_type': balanceType.name,
      'current_exchange_rate': currentExchangeRate,
      'revalued_value_base_currency': revaluedValueBaseCurrency,
      'unrealized_gain_loss': unrealizedGainLoss,
      'created_at': (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static FxBalanceType _type(Object? value) {
    return value?.toString() == FxBalanceType.liability.name
        ? FxBalanceType.liability
        : FxBalanceType.asset;
  }
}
