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
  action TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  details TEXT NOT NULL
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
    'CREATE INDEX idx_tax_queries_company_timestamp ON tax_queries (company_id, timestamp)',
  ];

  static const List<String> createTables = <String>[
    createCompanies,
    createDocuments,
    createTransactions,
    createTaxRules,
    createAuditLogs,
    createTaxQueries,
  ];
}
