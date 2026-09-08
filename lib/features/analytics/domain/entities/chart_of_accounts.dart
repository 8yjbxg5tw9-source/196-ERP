import 'package:equatable/equatable.dart';

/// The five primary account classes of the standard chart of accounts.
enum AccountType { asset, liability, equity, revenue, expense }

/// One node in the hierarchical chart of accounts (Hesablar Planı).
class AccountEntity extends Equatable {
  const AccountEntity({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
  });

  final String id;
  final String companyId;
  final String code;
  final String name;
  final AccountType type;
  final String? parentCode;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        code,
        name,
        type,
        parentCode,
      ];
}

/// A computed balance for one chart-of-accounts node.
///
/// [balance] is expressed in the account's natural sign (positive for asset
/// and expense accounts, positive for liability, equity, and revenue
/// accounts). [debit] and [credit] expose the raw movement totals where a
/// movement source exists for the account.
class AccountBalanceEntity extends Equatable {
  const AccountBalanceEntity({
    required this.account,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final AccountEntity account;
  final double debit;
  final double credit;
  final double balance;

  @override
  List<Object?> get props => <Object?>[account, debit, credit, balance];
}
