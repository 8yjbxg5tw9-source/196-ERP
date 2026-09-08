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

  static const String createCompanies = '''
CREATE TABLE companies (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  voen_tin TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL
)
''';

  static const String createDocuments = '''
CREATE TABLE documents (
  id TEXT PRIMARY KEY NOT NULL,
  company_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  document_type TEXT NOT NULL,
  extracted_json TEXT,
  total_amount REAL NOT NULL DEFAULT 0,
  vat_amount REAL NOT NULL DEFAULT 0,
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
  description TEXT NOT NULL,
  embedding_vector BLOB
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
    'CREATE INDEX idx_tax_rules_article_code ON tax_rules (article_code)',
    'CREATE INDEX idx_audit_logs_timestamp ON audit_logs (timestamp)',
    'CREATE INDEX idx_audit_logs_action ON audit_logs (action)',
  ];

  static const List<String> createTables = <String>[
    createCompanies,
    createDocuments,
    createTransactions,
    createTaxRules,
    createAuditLogs,
  ];
}
