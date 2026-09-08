import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tables.dart';

/// Owns the local SQLite connection and schema lifecycle.
///
/// Windows, Linux, and macOS use the SQLite FFI implementation. Android and
/// iOS continue to use the native sqflite implementation. Web callers receive
/// an explicit unsupported error because this service requires a relational
/// database implementation rather than silently storing data elsewhere.
class DatabaseService {
  DatabaseService({this.databaseName = 'finai_studio.db'});

  static const int currentSchemaVersion = 6;

  final String databaseName;
  Future<Database>? _databaseFuture;
  String? _databasePath;

  /// Resolves the single shared database connection.
  Future<Database> get database => _databaseFuture ??= _openDatabase();

  /// The resolved path after the database has been opened.
  String? get databasePath => _databasePath;

  /// Opens the database and applies the current schema if needed.
  Future<void> initialize() async {
    await database;
  }

  /// Closes the connection, primarily for tests and controlled shutdowns.
  Future<void> close() async {
    final Future<Database>? pendingDatabase = _databaseFuture;
    if (pendingDatabase == null) {
      return;
    }

    final Database openedDatabase = await pendingDatabase;
    await openedDatabase.close();
    _databaseFuture = null;
  }

  Future<Database> _openDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite persistence is not configured for the web target.',
      );
    }

    _configureDatabaseFactory();

    final String applicationSupportPath =
        (await getApplicationSupportDirectory()).path;
    final String path = p.join(applicationSupportPath, databaseName);

    final Database openedDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    _databasePath = path;
    debugPrint('[DatabaseService] SQLite database ready: $path');
    return openedDatabase;
  }

  void _configureDatabaseFactory() {
    if (_isDesktopPlatform) {
      // FFI is required for Windows/Linux/macOS because sqflite's native
      // mobile implementation is not available on those targets.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Foreign keys must be enabled for every connection, not only at schema
    // creation time. WAL improves concurrent read/write behavior for offline
    // document and transaction workflows.
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');

    final List<Map<String, Object?>> pragmaResult =
        await db.rawQuery('PRAGMA foreign_keys');
    final Object? foreignKeysValue = pragmaResult.isEmpty
        ? null
        : pragmaResult.first['foreign_keys'];
    debugPrint('[DatabaseService] PRAGMA foreign_keys = $foreignKeysValue');

    if (foreignKeysValue != 1 && foreignKeysValue != '1') {
      throw StateError('SQLite foreign key enforcement could not be enabled.');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
    debugPrint('[DatabaseService] Created schema version $version.');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Add future migrations as explicit version blocks. Never edit an already
    // shipped CREATE TABLE statement without adding a new block here.
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          await _createSchema(db);
        case 2:
          await db.execute(
            'ALTER TABLE ${DatabaseTables.companies} '
            'ADD COLUMN tax_type TEXT NOT NULL DEFAULT \'VAT\'',
          );
        case 3:
          await _migrateDocumentsToVersion3(db);
        case 4:
          await _migrateDocumentsToVersion4(db);
        case 5:
          await _migrateTaxCopilotToVersion5(db);
        case 6:
          await _migrateReconciliationToVersion6(db);
        default:
          debugPrint(
            '[DatabaseService] No migration registered for schema version '
            '$version.',
          );
      }
    }

    debugPrint(
      '[DatabaseService] Migrated schema from $oldVersion to $newVersion.',
    );
  }

  Future<void> _migrateDocumentsToVersion3(Database db) async {
    const List<String> statements = <String>[
      "ALTER TABLE ${DatabaseTables.documents} ADD COLUMN file_name TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN vendor_name TEXT',
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN vendor_voen TEXT',
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN invoice_number TEXT',
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN issue_date TIMESTAMP',
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN subtotal REAL',
      "ALTER TABLE ${DatabaseTables.documents} ADD COLUMN currency TEXT NOT NULL DEFAULT 'AZN'",
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN line_items_json TEXT',
    ];
    for (final String statement in statements) {
      await db.execute(statement);
    }
  }

  Future<void> _migrateDocumentsToVersion4(Database db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseTables.documents} ADD COLUMN due_date TIMESTAMP',
    );
  }

  Future<void> _migrateTaxCopilotToVersion5(Database db) async {
    await db.execute(
      "ALTER TABLE ${DatabaseTables.taxRules} "
      "ADD COLUMN content TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      "ALTER TABLE ${DatabaseTables.taxRules} "
      "ADD COLUMN category TEXT NOT NULL DEFAULT 'tax'",
    );
    await db.execute(
      'UPDATE ${DatabaseTables.taxRules} '
      'SET content = description WHERE content = \'\'',
    );
    await db.execute(DatabaseTables.createTaxQueries);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tax_queries_company_timestamp '
      'ON ${DatabaseTables.taxQueries} (company_id, timestamp)',
    );
  }

  Future<void> _migrateReconciliationToVersion6(Database db) async {
    const List<String> statements = <String>[
      'ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN counterparty_name TEXT',
      'ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN counterparty_voen TEXT',
      'ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN reference_code TEXT',
      "ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN transaction_type TEXT NOT NULL DEFAULT 'debit' CHECK (transaction_type IN ('credit', 'debit'))",
      'ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN match_confidence REAL NOT NULL DEFAULT 0 CHECK (match_confidence >= 0 AND match_confidence <= 1)',
      "ALTER TABLE ${DatabaseTables.transactions} ADD COLUMN match_status TEXT NOT NULL DEFAULT 'unmatched' CHECK (match_status IN ('unmatched', 'suggested', 'reconciled'))",
    ];
    for (final String statement in statements) {
      await db.execute(statement);
    }

    // Preserve the meaning of legacy rows that were already reconciled before
    // the confidence/status columns existed.
    await db.execute(
      "UPDATE ${DatabaseTables.transactions} "
      "SET match_status = 'reconciled', match_confidence = 1 "
      'WHERE reconciled = 1 AND document_id IS NOT NULL',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_match_status '
      'ON ${DatabaseTables.transactions} (company_id, match_status)',
    );
  }

  Future<void> _createSchema(Database db) async {
    for (final String statement in DatabaseTables.createTables) {
      await db.execute(statement);
    }
    for (final String statement in DatabaseTables.createIndexes) {
      await db.execute(statement);
    }
  }
}

bool get _isDesktopPlatform {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
