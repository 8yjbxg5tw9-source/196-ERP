import '../../domain/entities/chart_of_accounts.dart';

/// Standard National Accounting Standards / IFRS-compatible chart of accounts.
///
/// The hierarchy uses numeric account codes with `parent_code` links so the
/// reporting workspace can render a real parent-child tree.
abstract final class ChartOfAccountsSeeder {
  static List<AccountEntity> defaultAccounts(String companyId) {
    final List<AccountEntity> accounts = <AccountEntity>[];
    for (final _SeedAccount seed in _seedAccounts) {
      accounts.add(
        AccountEntity(
          id: 'account-$companyId-${seed.code}',
          companyId: companyId,
          code: seed.code,
          name: seed.name,
          type: seed.type,
          parentCode: seed.parentCode,
        ),
      );
    }
    return accounts;
  }
}

class _SeedAccount {
  const _SeedAccount({
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
  });

  final String code;
  final String name;
  final AccountType type;
  final String? parentCode;
}

const List<_SeedAccount> _seedAccounts = <_SeedAccount>[
  // Assets.
  _SeedAccount(code: '100', name: 'Assets', type: AccountType.asset),
  _SeedAccount(
    code: '101',
    name: 'Cash & Bank',
    type: AccountType.asset,
    parentCode: '100',
  ),
  _SeedAccount(
    code: '101.1',
    name: 'Bank AZN',
    type: AccountType.asset,
    parentCode: '101',
  ),
  _SeedAccount(
    code: '101.2',
    name: 'Cash on Hand',
    type: AccountType.asset,
    parentCode: '101',
  ),
  _SeedAccount(
    code: '121',
    name: 'Accounts Receivable',
    type: AccountType.asset,
    parentCode: '100',
  ),
  _SeedAccount(
    code: '131',
    name: 'Inventory',
    type: AccountType.asset,
    parentCode: '100',
  ),
  _SeedAccount(
    code: '141',
    name: 'Fixed Assets',
    type: AccountType.asset,
    parentCode: '100',
  ),
  _SeedAccount(
    code: '142',
    name: 'Accumulated Depreciation',
    type: AccountType.asset,
    parentCode: '100',
  ),
  _SeedAccount(
    code: '143',
    name: 'Deferred Tax Asset',
    type: AccountType.asset,
    parentCode: '100',
  ),
  // Liabilities.
  _SeedAccount(code: '200', name: 'Liabilities', type: AccountType.liability),
  _SeedAccount(
    code: '201',
    name: 'Accounts Payable',
    type: AccountType.liability,
    parentCode: '200',
  ),
  _SeedAccount(
    code: '211',
    name: 'Short-term Loans',
    type: AccountType.liability,
    parentCode: '200',
  ),
  _SeedAccount(
    code: '221',
    name: 'Output VAT Payable',
    type: AccountType.liability,
    parentCode: '200',
  ),
  _SeedAccount(
    code: '222',
    name: 'Input VAT Recoverable',
    type: AccountType.liability,
    parentCode: '200',
  ),
  _SeedAccount(
    code: '231',
    name: 'Tax Payable',
    type: AccountType.liability,
    parentCode: '200',
  ),
  _SeedAccount(
    code: '241',
    name: 'Deferred Tax Liability',
    type: AccountType.liability,
    parentCode: '200',
  ),
  // Equity.
  _SeedAccount(code: '300', name: 'Equity', type: AccountType.equity),
  _SeedAccount(
    code: '301',
    name: 'Share Capital',
    type: AccountType.equity,
    parentCode: '300',
  ),
  _SeedAccount(
    code: '302',
    name: 'Retained Earnings',
    type: AccountType.equity,
    parentCode: '300',
  ),
  _SeedAccount(
    code: '303',
    name: 'Current Year Profit / Loss',
    type: AccountType.equity,
    parentCode: '300',
  ),
  // Revenue.
  _SeedAccount(code: '400', name: 'Revenue', type: AccountType.revenue),
  _SeedAccount(
    code: '401',
    name: 'Sales Revenue',
    type: AccountType.revenue,
    parentCode: '400',
  ),
  _SeedAccount(
    code: '402',
    name: 'Service Revenue',
    type: AccountType.revenue,
    parentCode: '400',
  ),
  _SeedAccount(
    code: '403',
    name: 'Other Income',
    type: AccountType.revenue,
    parentCode: '400',
  ),
  _SeedAccount(
    code: '404',
    name: 'Deferred Tax Benefit',
    type: AccountType.revenue,
    parentCode: '400',
  ),
  // Expenses.
  _SeedAccount(code: '500', name: 'Expenses', type: AccountType.expense),
  _SeedAccount(
    code: '501',
    name: 'Cost of Goods Sold',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '511',
    name: 'Salaries & Wages',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '512',
    name: 'Rent Expense',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '513',
    name: 'Utilities',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '514',
    name: 'Marketing & Advertising',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '515',
    name: 'Depreciation',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '516',
    name: 'Other Operating Expenses',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '601',
    name: 'Interest Expense',
    type: AccountType.expense,
    parentCode: '500',
  ),
  _SeedAccount(
    code: '602',
    name: 'Deferred Tax Expense',
    type: AccountType.expense,
    parentCode: '500',
  ),
];
