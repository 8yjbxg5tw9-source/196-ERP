/// SQL schema for the local FinAI Studio relational store.
///
/// SQLite does not have a native UUID type, so UUIDs are stored as `TEXT`.
/// Timestamps use SQLite's `TIMESTAMP` affinity and are written as UTC ISO-8601
/// strings by data sources. Keeping all schema SQL in one place makes migration
/// reviews and future version bumps explicit.
abstract final class DatabaseTables {
  static const String companies = 'companies';
  static const String documents = 'documents';
  static const String transactions = 'transactions';
  static const String taxRules = 'tax_rules';
  static const String auditLogs = 'audit_logs';
  static const String taxQueries = 'tax_queries';
  static const String accounts = 'accounts';
  static const String users = 'users';
  static const String currencies = 'currencies';
  static const String exchangeRates = 'exchange_rates';
  static const String companyGroups = 'company_groups';
  static const String reconciliationRules = 'reconciliation_rules';
  static const String journalEntries = 'journal_entries';
  static const String assets = 'assets';
  static const String depreciationSchedules = 'depreciation_schedules';
  static const String employees = 'employees';
  static const String payrollRecords = 'payroll_records';
  static const String warehouses = 'warehouses';
  static const String products = 'products';
  static const String stockMovements = 'stock_movements';
  static const String inventoryBatches = 'inventory_batches';
  static const String intercompanyLoans = 'intercompany_loans';
  static const String interestSchedules = 'interest_schedules';
  static const String dividendDistributions = 'dividend_distributions';
  static const String fxBalances = 'fx_balances';
  static const String fxRevaluations = 'fx_revaluations';
  static const String deferredTaxCalculations = 'deferred_tax_calculations';
  static const String temporaryDifferences = 'temporary_differences';

  static const String createCompanies = '''
CREATE TABLE companies (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  voen_tin TEXT NOT NULL UNIQUE,
  tax_type TEXT NOT NULL DEFAULT 'VAT',
  created_at TIMESTAMP NOT NULL
)
''';

  static const String createDocuments = '''
CREATE TABLE documents (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  document_type TEXT NOT NULL,
  extracted_json TEXT,
  vendor_name TEXT,
  vendor_voen TEXT,
  invoice_number TEXT,
  issue_date TIMESTAMP,
  due_date TIMESTAMP,
  subtotal REAL,
  total_amount REAL,
  vat_amount REAL,
  currency TEXT NOT NULL DEFAULT 'AZN',
  line_items_json TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  static const String createTransactions = '''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  document_id TEXT,
  date TEXT NOT NULL,
  description TEXT NOT NULL,
  amount REAL NOT NULL,
  category TEXT NOT NULL,
  counterparty_name TEXT,
  counterparty_voen TEXT,
  reference_code TEXT,
  transaction_type TEXT NOT NULL DEFAULT 'debit' CHECK (transaction_type IN ('credit', 'debit')),
  match_confidence REAL NOT NULL DEFAULT 0 CHECK (match_confidence >= 0 AND match_confidence <= 1),
  match_status TEXT NOT NULL DEFAULT 'unmatched' CHECK (match_status IN ('unmatched', 'suggested', 'reconciled')),
  reconciled INTEGER NOT NULL DEFAULT 0 CHECK (reconciled IN (0, 1)),
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
)
''';

  static const String createTaxRules = '''
CREATE TABLE tax_rules (
  id TEXT PRIMARY KEY NOT NULL,
  article_code TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'tax',
  embedding_vector BLOB
)
''';

  static const String createTaxQueries = '''
CREATE TABLE tax_queries (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  cited_articles_json TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  static const String createAuditLogs = '''
CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT,
  user_id TEXT NOT NULL DEFAULT '',
  user_name TEXT NOT NULL DEFAULT '',
  user_role TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,
  entity_name TEXT NOT NULL DEFAULT '',
  entity_id TEXT,
  before_state TEXT,
  after_state TEXT,
  ip_address TEXT,
  previous_hash TEXT,
  current_hash TEXT,
  system_device_info TEXT,
  timestamp TIMESTAMP NOT NULL
)
''';

  /// SQLite trigger enforcing that audit records can only be inserted, never
  /// deleted or updated, so the trail cannot be silently altered after the
  /// fact by application code or an administrator.
  static const String createAuditLogsNoDeleteTrigger = '''
CREATE TRIGGER audit_logs_no_delete
BEFORE DELETE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs is append-only: deletes are prohibited');
END
''';

  static const String createAuditLogsNoUpdateTrigger = '''
CREATE TRIGGER audit_logs_no_update
BEFORE UPDATE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs is append-only: updates are prohibited');
END
''';

  /// Supported ledger currencies. `is_base` marks the single accounting base
  /// currency (AZN) that all conversions are reported against.
  static const String createCurrencies = '''
CREATE TABLE currencies (
  code TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  symbol TEXT NOT NULL DEFAULT '',
  is_base INTEGER NOT NULL DEFAULT 0 CHECK (is_base IN (0, 1))
)
''';

  /// Daily foreign-exchange rates, stored as `base_currency` units per one
  /// unit of `target_currency` (e.g. 1.7000 AZN per 1 USD).
  static const String createExchangeRates = '''
CREATE TABLE exchange_rates (
  id TEXT PRIMARY KEY NOT NULL,
  base_currency TEXT NOT NULL,
  target_currency TEXT NOT NULL,
  rate REAL NOT NULL,
  rate_date TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'CentralBank'
)
''';

  /// Holding-structure groups for multi-company consolidation.
  ///
  /// `subsidiary_company_ids` is a JSON array of child company UUIDs; the
  /// parent company id is also included in every consolidation calculation.
  static const String createCompanyGroups = '''
CREATE TABLE company_groups (
  id TEXT PRIMARY KEY NOT NULL,
  group_name TEXT NOT NULL,
  parent_company_id TEXT NOT NULL,
  subsidiary_company_ids TEXT NOT NULL DEFAULT '[]',
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (parent_company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// Custom reconciliation rules ("IF condition THEN action") evaluated by the
  /// rule engine before the default fuzzy matcher runs. Conditions and the
  /// action payload are stored as JSON strings.
  static const String createReconciliationRules = '''
CREATE TABLE reconciliation_rules (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  rule_name TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  conditions_json TEXT NOT NULL DEFAULT '[]',
  action_type TEXT NOT NULL DEFAULT 'categorize',
  action_value TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// General ledger journal lines. Each row is a self-balancing debit/credit
  /// pair (one debit account, one credit account, one amount) produced by
  /// automated modules such as depreciation runs and payroll posting.
  static const String createJournalEntries = '''
CREATE TABLE journal_entries (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  entry_date TEXT NOT NULL,
  description TEXT NOT NULL,
  debit_account TEXT NOT NULL,
  credit_account TEXT NOT NULL,
  amount REAL NOT NULL,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// Fixed asset register (Əsas Vəsaitlər). `book_value` is maintained by the
  /// depreciation engine and updated after every amortization run.
  static const String createAssets = '''
CREATE TABLE assets (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  asset_code TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('buildings', 'machinery', 'vehicles', 'computers', 'intangible')),
  purchase_date TEXT NOT NULL,
  purchase_price REAL NOT NULL,
  salvage_value REAL NOT NULL DEFAULT 0,
  useful_life_months INTEGER NOT NULL,
  depreciation_method TEXT NOT NULL CHECK (depreciation_method IN ('straightLine', 'decliningBalance', 'taxNormative')),
  accumulated_depreciation REAL NOT NULL DEFAULT 0,
  book_value REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'fullyDepreciated', 'disposed')),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// One period line of an asset's amortization schedule.
  static const String createDepreciationSchedules = '''
CREATE TABLE depreciation_schedules (
  id TEXT PRIMARY KEY NOT NULL,
  asset_id TEXT NOT NULL,
  company_id TEXT NOT NULL,
  period_date TEXT NOT NULL,
  depreciation_amount REAL NOT NULL,
  accumulated_amount REAL NOT NULL,
  ending_book_value REAL NOT NULL,
  is_posted INTEGER NOT NULL DEFAULT 0 CHECK (is_posted IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// Employee master data for the payroll engine.
  static const String createEmployees = '''
CREATE TABLE employees (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  full_name TEXT NOT NULL,
  pin TEXT NOT NULL,
  position TEXT NOT NULL DEFAULT '',
  base_salary REAL NOT NULL,
  employment_type TEXT NOT NULL CHECK (employment_type IN ('fullTime', 'partTime', 'contractor')),
  sector_type TEXT NOT NULL CHECK (sector_type IN ('oilGasPrivate', 'nonOilGasPrivate', 'stateBudget')),
  bank_account_iban TEXT,
  start_date TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// One computed monthly payroll record, itemized by statutory deduction.
  static const String createPayrollRecords = '''
CREATE TABLE payroll_records (
  id TEXT PRIMARY KEY NOT NULL,
  employee_id TEXT NOT NULL,
  company_id TEXT NOT NULL,
  period_month INTEGER NOT NULL,
  period_year INTEGER NOT NULL,
  gross_salary REAL NOT NULL,
  taxable_income REAL NOT NULL,
  income_tax REAL NOT NULL,
  employee_dsmf REAL NOT NULL,
  employer_dsmf REAL NOT NULL,
  employee_unemployment REAL NOT NULL,
  employer_unemployment REAL NOT NULL,
  employee_health_insurance REAL NOT NULL,
  employer_health_insurance REAL NOT NULL,
  net_salary REAL NOT NULL,
  total_employer_cost REAL NOT NULL,
  is_approved INTEGER NOT NULL DEFAULT 0 CHECK (is_approved IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// A physical or logical stock location. `is_primary` marks the default
  /// receiving warehouse for a company.
  static const String createWarehouses = '''
CREATE TABLE warehouses (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  location TEXT,
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  UNIQUE (company_id, code)
)
''';

  /// Stock directory master record. Aggregated quantity/value fields are
  /// maintained transactionally by the inventory repository.
  static const String createProducts = '''
CREATE TABLE products (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  sku TEXT NOT NULL,
  barcode TEXT,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit_of_measure TEXT NOT NULL CHECK (unit_of_measure IN ('pcs', 'kg', 'meter', 'liter', 'box')),
  valuation_method TEXT NOT NULL CHECK (valuation_method IN ('fifo', 'movingAverage')),
  reorder_level REAL NOT NULL DEFAULT 0,
  total_quantity REAL NOT NULL DEFAULT 0,
  total_value REAL NOT NULL DEFAULT 0,
  average_unit_cost REAL NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  UNIQUE (company_id, sku)
)
''';

  /// Append-only stock ledger. Every receipt, dispatch, transfer, count
  /// adjustment, and return is recorded as a signed movement line.
  static const String createStockMovements = '''
CREATE TABLE stock_movements (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  target_warehouse_id TEXT,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('purchaseIn', 'saleOut', 'transfer', 'adjustment', 'return')),
  quantity REAL NOT NULL,
  unit_cost REAL NOT NULL,
  total_cost REAL NOT NULL,
  reference_doc_id TEXT,
  timestamp TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE CASCADE,
  FOREIGN KEY (target_warehouse_id) REFERENCES warehouses (id) ON DELETE SET NULL
)
''';

  /// FIFO valuation layers. Batches are consumed oldest-first on dispatch.
  static const String createInventoryBatches = '''
CREATE TABLE inventory_batches (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  warehouse_id TEXT NOT NULL,
  received_at TIMESTAMP NOT NULL,
  purchase_unit_cost REAL NOT NULL,
  initial_qty REAL NOT NULL,
  remaining_qty REAL NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE CASCADE
)
''';

  /// Intercompany loan agreements between group entities.
  static const String createIntercompanyLoans = '''
CREATE TABLE intercompany_loans (
  id TEXT PRIMARY KEY NOT NULL,
  lender_company_id TEXT NOT NULL,
  borrower_company_id TEXT NOT NULL,
  principal_amount REAL NOT NULL,
  interest_rate REAL NOT NULL,
  agreement_date TEXT NOT NULL,
  maturity_date TEXT NOT NULL,
  compounding_frequency TEXT NOT NULL CHECK (compounding_frequency IN ('simple', 'monthly', 'annually')),
  withholding_tax_rate REAL NOT NULL DEFAULT 0,
  outstanding_balance REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled', 'defaulted')),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (lender_company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (borrower_company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// One period line of an intercompany loan's interest schedule.
  static const String createInterestSchedules = '''
CREATE TABLE interest_schedules (
  id TEXT PRIMARY KEY NOT NULL,
  loan_id TEXT NOT NULL,
  period_date TEXT NOT NULL,
  gross_interest REAL NOT NULL,
  withholding_tax REAL NOT NULL,
  net_interest REAL NOT NULL,
  is_accrued INTEGER NOT NULL DEFAULT 0 CHECK (is_accrued IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (loan_id) REFERENCES intercompany_loans (id) ON DELETE CASCADE
)
''';

  /// Declared profit distributions with dividend withholding tax applied.
  static const String createDividendDistributions = '''
CREATE TABLE dividend_distributions (
  id TEXT PRIMARY KEY NOT NULL,
  distributing_company_id TEXT NOT NULL,
  recipient_entity_id TEXT NOT NULL,
  declared_amount REAL NOT NULL,
  dividend_tax_rate REAL NOT NULL DEFAULT 0,
  net_dividend_paid REAL NOT NULL,
  declaration_date TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (distributing_company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_entity_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// Open foreign-currency balances subject to period-end mark-to-market.
  static const String createFxBalances = '''
CREATE TABLE fx_balances (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  foreign_currency TEXT NOT NULL,
  foreign_amount REAL NOT NULL,
  book_value_base_currency REAL NOT NULL,
  balance_type TEXT NOT NULL DEFAULT 'asset' CHECK (balance_type IN ('asset', 'liability')),
  current_exchange_rate REAL NOT NULL DEFAULT 0,
  revalued_value_base_currency REAL NOT NULL DEFAULT 0,
  unrealized_gain_loss REAL NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// A period-end FX revaluation run and its aggregate P&L impact.
  static const String createFxRevaluations = '''
CREATE TABLE fx_revaluations (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  revaluation_date TEXT NOT NULL,
  period_month INTEGER NOT NULL,
  period_year INTEGER NOT NULL,
  total_unrealized_gain REAL NOT NULL DEFAULT 0,
  total_unrealized_loss REAL NOT NULL DEFAULT 0,
  net_fx_impact REAL NOT NULL DEFAULT 0,
  is_posted INTEGER NOT NULL DEFAULT 0 CHECK (is_posted IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// A period-end IAS 12 deferred tax computation and its net DTA/DTL
  /// position. `period_deferred_tax_expense_benefit` is the net movement to
  /// be journaled (positive = expense, negative = benefit).
  static const String createDeferredTaxCalculations = '''
CREATE TABLE deferred_tax_calculations (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  period_year INTEGER NOT NULL,
  total_dta REAL NOT NULL DEFAULT 0,
  total_dtl REAL NOT NULL DEFAULT 0,
  net_position REAL NOT NULL DEFAULT 0,
  prior_year_net_position REAL NOT NULL DEFAULT 0,
  period_deferred_tax_expense_benefit REAL NOT NULL DEFAULT 0,
  statutory_tax_rate REAL NOT NULL DEFAULT 0,
  accounting_net_profit REAL NOT NULL DEFAULT 0,
  is_posted INTEGER NOT NULL DEFAULT 0 CHECK (is_posted IN (0, 1)),
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// One itemized accounting-vs-tax temporary difference underlying a
  /// deferred tax calculation.
  static const String createTemporaryDifferences = '''
CREATE TABLE temporary_differences (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  calculation_id TEXT NOT NULL,
  asset_liability_name TEXT NOT NULL,
  accounting_book_value REAL NOT NULL DEFAULT 0,
  tax_carrying_base REAL NOT NULL DEFAULT 0,
  difference_type TEXT NOT NULL CHECK (difference_type IN ('taxableTemporary', 'deductibleTemporary')),
  temporary_difference_amount REAL NOT NULL DEFAULT 0,
  statutory_tax_rate REAL NOT NULL DEFAULT 0,
  deferred_tax_type TEXT NOT NULL CHECK (deferred_tax_type IN ('deferredTaxAsset', 'deferredTaxLiability')),
  deferred_amount REAL NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE,
  FOREIGN KEY (calculation_id) REFERENCES deferred_tax_calculations (id) ON DELETE CASCADE
)
''';

  /// Initial currency catalogue seeded with every fresh schema and migration.
  static const List<String> seedCurrencies = <String>[
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('AZN', 'Azerbaijani Manat', '₼', 1)",
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('USD', 'US Dollar', '\$', 0)",
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('EUR', 'Euro', '€', 0)",
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('GBP', 'British Pound', '£', 0)",
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('TRY', 'Turkish Lira', '₺', 0)",
    "INSERT INTO currencies (code, name, symbol, is_base) "
        "VALUES ('RUB', 'Russian Ruble', '₽', 0)",
  ];

  /// Hierarchical chart of accounts (Hesablar Planı). Parent-child links use
  /// `parent_code` so account codes remain the stable business identifier.
  static const String createAccounts = '''
CREATE TABLE accounts (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
  parent_code TEXT,
  FOREIGN KEY (company_id) REFERENCES companies (id) ON DELETE CASCADE
)
''';

  /// Local multi-user accounts for role-based access control.
  ///
  /// Passwords are never stored in plain text: `password_hash` and `salt` are
  /// the PBKDF2-HMAC-SHA256 output and per-user salt, while `company_ids` is a
  /// JSON array listing the companies a user is scoped to.
  static const String createUsers = '''
CREATE TABLE users (
  id TEXT PRIMARY KEY NOT NULL,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL DEFAULT '',
  full_name TEXT NOT NULL DEFAULT '',
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'clientViewer' CHECK (role IN ('admin', 'chiefAccountant', 'juniorAccountant', 'auditor', 'clientViewer')),
  company_ids TEXT NOT NULL DEFAULT '[]',
  created_at TIMESTAMP NOT NULL
)
''';

  /// Explicit indexes keep the common company, status, date, and audit queries
  /// fast without relying only on SQLite's implicit primary-key indexes.
  static const List<String> createIndexes = <String>[
    'CREATE INDEX idx_documents_company_id ON documents (company_id)',
    'CREATE INDEX idx_documents_status ON documents (status)',
    'CREATE INDEX idx_documents_created_at ON documents (created_at)',
    'CREATE INDEX idx_transactions_company_id ON transactions (company_id)',
    'CREATE INDEX idx_transactions_document_id ON transactions (document_id)',
    'CREATE INDEX idx_transactions_date ON transactions (date)',
    'CREATE INDEX idx_transactions_reconciled ON transactions (reconciled)',
    'CREATE INDEX idx_transactions_match_status ON transactions (company_id, match_status)',
    'CREATE INDEX idx_tax_rules_article_code ON tax_rules (article_code)',
    'CREATE INDEX idx_audit_logs_timestamp ON audit_logs (timestamp)',
    'CREATE INDEX idx_audit_logs_action ON audit_logs (action)',
    'CREATE INDEX idx_audit_logs_company_timestamp ON audit_logs (company_id, timestamp)',
    'CREATE INDEX idx_audit_logs_user ON audit_logs (user_id)',
    'CREATE INDEX idx_tax_queries_company_timestamp ON tax_queries (company_id, timestamp)',
    'CREATE INDEX idx_accounts_company_id ON accounts (company_id)',
    'CREATE UNIQUE INDEX idx_accounts_company_code ON accounts (company_id, code)',
    'CREATE INDEX idx_accounts_parent_code ON accounts (parent_code)',
    'CREATE INDEX idx_users_role ON users (role)',
    'CREATE INDEX idx_exchange_rates_lookup '
        'ON exchange_rates (base_currency, target_currency, rate_date)',
    'CREATE INDEX idx_company_groups_parent '
        'ON company_groups (parent_company_id)',
    'CREATE INDEX idx_reconciliation_rules_company '
        'ON reconciliation_rules (company_id, priority)',
    'CREATE INDEX idx_journal_entries_company_date '
        'ON journal_entries (company_id, entry_date)',
    'CREATE INDEX idx_assets_company '
        'ON assets (company_id)',
    'CREATE INDEX idx_depreciation_schedules_asset '
        'ON depreciation_schedules (asset_id, period_date)',
    'CREATE INDEX idx_employees_company '
        'ON employees (company_id)',
    'CREATE INDEX idx_payroll_records_company_period '
        'ON payroll_records (company_id, period_year, period_month)',
    'CREATE INDEX idx_warehouses_company '
        'ON warehouses (company_id)',
    'CREATE INDEX idx_products_company '
        'ON products (company_id)',
    'CREATE INDEX idx_stock_movements_product '
        'ON stock_movements (product_id, timestamp)',
    'CREATE INDEX idx_stock_movements_company_timestamp '
        'ON stock_movements (company_id, timestamp)',
    'CREATE INDEX idx_inventory_batches_product '
        'ON inventory_batches (product_id, received_at)',
    'CREATE INDEX idx_intercompany_loans_lender '
        'ON intercompany_loans (lender_company_id)',
    'CREATE INDEX idx_intercompany_loans_borrower '
        'ON intercompany_loans (borrower_company_id)',
    'CREATE INDEX idx_interest_schedules_loan '
        'ON interest_schedules (loan_id, period_date)',
    'CREATE INDEX idx_dividend_distributions_company '
        'ON dividend_distributions (distributing_company_id, declaration_date)',
    'CREATE INDEX idx_fx_balances_company '
        'ON fx_balances (company_id)',
    'CREATE INDEX idx_fx_revaluations_company_period '
        'ON fx_revaluations (company_id, period_year, period_month)',
    'CREATE INDEX idx_deferred_tax_calculations_company_period '
        'ON deferred_tax_calculations (company_id, period_year)',
    'CREATE INDEX idx_temporary_differences_calculation '
        'ON temporary_differences (calculation_id)',
  ];

  static const List<String> createTables = <String>[
    createCompanies,
    createDocuments,
    createTransactions,
    createTaxRules,
    createAuditLogs,
    createTaxQueries,
    createAccounts,
    createUsers,
    createCurrencies,
    createExchangeRates,
    createCompanyGroups,
    createReconciliationRules,
    createJournalEntries,
    createAssets,
    createDepreciationSchedules,
    createEmployees,
    createPayrollRecords,
    createWarehouses,
    createProducts,
    createStockMovements,
    createInventoryBatches,
    createIntercompanyLoans,
    createInterestSchedules,
    createDividendDistributions,
    createFxBalances,
    createFxRevaluations,
    createDeferredTaxCalculations,
    createTemporaryDifferences,
  ];

  static const List<String> createTriggers = <String>[
    createAuditLogsNoDeleteTrigger,
    createAuditLogsNoUpdateTrigger,
  ];
}
