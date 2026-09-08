import 'package:sqflite/sqflite.dart';

import 'tables.dart';

/// A `_FtsSource` describes how one relational table is projected into the
/// global FTS5 index. Expressions use a `{alias}` placeholder that is bound to
/// `new.`, `old.`, or an empty string (for backfills) when the triggers and
/// `INSERT ... SELECT` statements are generated.
class _FtsSource {
  const _FtsSource({
    required this.tableName,
    required this.entityType,
    required this.title,
    required this.content,
    required this.voen,
    required this.amount,
    required this.tokens,
  });

  final String tableName;
  final String entityType;
  final String title;
  final String content;
  final String voen;
  final String amount;
  final String tokens;
}

/// SQLite FTS5 multi-index full-text search over every core financial entity.
///
/// A single virtual table `fts_global_index` mirrors `transactions`,
/// `documents` (invoices), `companies` (counterparties), `accounts`, `assets`,
/// and `payroll_records`. Triggers keep the index synchronized on every
/// mutation so the command palette can answer sub-10ms keyword/VÖEN/amount
/// queries across all six dimensions simultaneously.
abstract final class GlobalFtsSetup {
  static const String table = 'fts_global_index';

  /// FTS5 virtual table schema (see the Step 39 specification). `entity_id`
  /// and `entity_type` are UNINDEXED because they are matched with equality,
  /// not with the MATCH operator.
  static const String createTable = '''
CREATE VIRTUAL TABLE IF NOT EXISTS fts_global_index USING fts5(
  entity_id UNINDEXED,
  entity_type UNINDEXED,
  title,
  content,
  voen,
  amount,
  search_tokens,
  tokenize = 'unicode61 remove_diacritics 2'
)
''';

  static const String _transactionTokens =
      "COALESCE({alias}description, '') || ' ' || "
      "COALESCE({alias}counterparty_name, '') || ' ' || "
      "COALESCE({alias}counterparty_voen, '') || ' ' || "
      "COALESCE({alias}reference_code, '') || ' ' || "
      "COALESCE({alias}category, '') || ' ' || "
      "COALESCE({alias}transaction_type, '') || ' ' || "
      "COALESCE(CAST({alias}amount AS TEXT), '')";

  static const String _documentTokens =
      "COALESCE({alias}invoice_number, '') || ' ' || "
      "COALESCE({alias}vendor_name, '') || ' ' || "
      "COALESCE({alias}vendor_voen, '') || ' ' || "
      "COALESCE({alias}document_type, '') || ' ' || "
      "COALESCE({alias}extracted_json, '') || ' ' || "
      "COALESCE(CAST({alias}total_amount AS TEXT), '')";

  static const String _companyTokens =
      "COALESCE({alias}name, '') || ' ' || "
      "COALESCE({alias}voen_tin, '') || ' ' || "
      "COALESCE({alias}tax_type, '')";

  static const String _accountTokens =
      "COALESCE({alias}code, '') || ' ' || "
      "COALESCE({alias}name, '') || ' ' || "
      "COALESCE({alias}type, '')";

  static const String _assetTokens =
      "COALESCE({alias}asset_code, '') || ' ' || "
      "COALESCE({alias}name, '') || ' ' || "
      "COALESCE({alias}category, '') || ' ' || "
      "COALESCE({alias}status, '') || ' ' || "
      "COALESCE(CAST({alias}book_value AS TEXT), '')";

  static const String _payrollTokens =
      "'Payroll' || ' ' || "
      "COALESCE(CAST({alias}period_month AS TEXT), '') || '/' || "
      "COALESCE(CAST({alias}period_year AS TEXT), '') || ' ' || "
      "COALESCE(CAST({alias}gross_salary AS TEXT), '') || ' ' || "
      "COALESCE(CAST({alias}net_salary AS TEXT), '')";

  static const List<_FtsSource> _sources = <_FtsSource>[
    _FtsSource(
      tableName: DatabaseTables.transactions,
      entityType: 'transaction',
      title: "COALESCE({alias}description, '')",
      content:
          "COALESCE({alias}counterparty_name, '') || ' ' || "
          "COALESCE({alias}reference_code, '') || ' ' || "
          "COALESCE({alias}category, '') || ' ' || "
          "COALESCE({alias}transaction_type, '')",
      voen: '{alias}counterparty_voen',
      amount: '{alias}amount',
      tokens: _transactionTokens,
    ),
    _FtsSource(
      tableName: DatabaseTables.documents,
      entityType: 'invoice',
      title:
          "COALESCE({alias}invoice_number, '') || ' ' || "
          "COALESCE({alias}vendor_name, '')",
      content:
          "COALESCE({alias}document_type, '') || ' ' || "
          "COALESCE({alias}extracted_json, '')",
      voen: '{alias}vendor_voen',
      amount: '{alias}total_amount',
      tokens: _documentTokens,
    ),
    _FtsSource(
      tableName: DatabaseTables.companies,
      entityType: 'counterparty',
      title: "COALESCE({alias}name, '')",
      content: "COALESCE({alias}tax_type, '')",
      voen: '{alias}voen_tin',
      amount: 'NULL',
      tokens: _companyTokens,
    ),
    _FtsSource(
      tableName: DatabaseTables.accounts,
      entityType: 'account',
      title: "COALESCE({alias}code, '') || ' ' || COALESCE({alias}name, '')",
      content: "COALESCE({alias}type, '')",
      voen: 'NULL',
      amount: 'NULL',
      tokens: _accountTokens,
    ),
    _FtsSource(
      tableName: DatabaseTables.assets,
      entityType: 'asset',
      title:
          "COALESCE({alias}asset_code, '') || ' ' || COALESCE({alias}name, '')",
      content:
          "COALESCE({alias}category, '') || ' ' || COALESCE({alias}status, '')",
      voen: 'NULL',
      amount: '{alias}book_value',
      tokens: _assetTokens,
    ),
    _FtsSource(
      tableName: DatabaseTables.payrollRecords,
      entityType: 'payroll',
      title:
          "'Payroll ' || COALESCE(CAST({alias}period_month AS TEXT), '') || "
          "'/' || COALESCE(CAST({alias}period_year AS TEXT), '')",
      content:
          "'gross ' || COALESCE(CAST({alias}gross_salary AS TEXT), '') || "
          "' net ' || COALESCE(CAST({alias}net_salary AS TEXT), '')",
      voen: 'NULL',
      amount: '{alias}net_salary',
      tokens: _payrollTokens,
    ),
  ];

  static List<String> get _triggerStatements {
    final List<String> statements = <String>[];
    for (final _FtsSource source in _sources) {
      statements
        ..add(_insertTrigger(source))
        ..add(_deleteTrigger(source))
        ..add(_updateTrigger(source));
    }
    return statements;
  }

  static String _bind(String expression, String alias) =>
      expression.replaceAll('{alias}', alias);

  static const String _columns =
      'entity_id, entity_type, title, content, voen, amount, search_tokens';

  static String _values(String alias, _FtsSource source) {
    final String id = _bind('{alias}id', alias);
    final String title = _bind(source.title, alias);
    final String content = _bind(source.content, alias);
    final String voen = _bind(source.voen, alias);
    final String amount = _bind(source.amount, alias);
    final String tokens = _bind(source.tokens, alias);
    return "$id, '${source.entityType}', $title, $content, $voen, "
        '$amount, $tokens';
  }

  static String _insertTrigger(_FtsSource source) {
    return 'CREATE TRIGGER IF NOT EXISTS fts_${source.tableName}_after_insert\n'
        'AFTER INSERT ON ${source.tableName}\n'
        'BEGIN\n'
        '  INSERT INTO $table (${_columns})\n'
        '  VALUES (${_values('new', source)});\n'
        'END';
  }

  static String _deleteTrigger(_FtsSource source) {
    return 'CREATE TRIGGER IF NOT EXISTS fts_${source.tableName}_after_delete\n'
        'AFTER DELETE ON ${source.tableName}\n'
        'BEGIN\n'
        '  INSERT INTO $table ($table, ${_columns})\n'
        "  VALUES ('delete', ${_values('old', source)});\n"
        'END';
  }

  static String _updateTrigger(_FtsSource source) {
    return 'CREATE TRIGGER IF NOT EXISTS fts_${source.tableName}_after_update\n'
        'AFTER UPDATE ON ${source.tableName}\n'
        'BEGIN\n'
        '  INSERT INTO $table ($table, ${_columns})\n'
        "  VALUES ('delete', ${_values('old', source)});\n"
        '  INSERT INTO $table (${_columns})\n'
        '  VALUES (${_values('new', source)});\n'
        'END';
  }

  /// Creates the virtual table and its synchronization triggers (idempotent).
  static Future<void> install(Database db) async {
    await db.execute(createTable);
    for (final String statement in _triggerStatements) {
      await db.execute(statement);
    }
  }

  /// Rebuilds the index from the current source rows (idempotent).
  static Future<void> rebuild(Database db) async {
    await db.execute('DELETE FROM $table');
    await backfill(db);
  }

  /// Inserts every source row into the index. Call once after `install` on an
  /// upgraded database so pre-existing rows become searchable.
  static Future<void> backfill(Database db) async {
    for (final _FtsSource source in _sources) {
      await db.execute(
        'INSERT INTO $table (${_columns})\n'
        'SELECT ${_values('', source)} FROM ${source.tableName}',
      );
    }
  }
}
