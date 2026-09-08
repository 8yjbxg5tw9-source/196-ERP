import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/app_directory_service.dart';
import 'fts_setup.dart';
import 'global_fts_setup.dart';
import 'tables.dart';

/// Owns the local SQLite connection and schema lifecycle.
///
/// Windows, Linux, and macOS use the SQLite FFI implementation. Android and
/// iOS continue to use the native sqflite implementation. Web callers receive
/// an explicit unsupported error because this service requires a relational
/// database implementation rather than silently storing data elsewhere.
class DatabaseService {
  DatabaseService({
    this.databaseName = 'finai_studio.db',
    AppDirectoryService? directoryService,
  }) : _directoryService = directoryService;

  static const int currentSchemaVersion = 21;

  final String databaseName;
  final AppDirectoryService? _directoryService;
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

    final String applicationSupportPath = _directoryService != null
        ? (await _directoryService!.databases()).path
        : (await getApplicationSupportDirectory()).path;
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
          break;
        case 2:
          await db.execute(
            'ALTER TABLE ${DatabaseTables.companies} '
            'ADD COLUMN tax_type TEXT NOT NULL DEFAULT \'VAT\'',
          );
          break;
        case 3:
          await _migrateDocumentsToVersion3(db);
          break;
        case 4:
          await _migrateDocumentsToVersion4(db);
          break;
        case 5:
          await _migrateTaxCopilotToVersion5(db);
          break;
        case 6:
          await _migrateReconciliationToVersion6(db);
          break;
        case 7:
          await _migrateChartOfAccountsToVersion7(db);
          break;
        case 8:
          await _migrateUsersToVersion8(db);
          break;
        case 9:
          await _migrateAuditToVersion9(db);
          break;
        case 10:
          await _migrateCurrencyToVersion10(db);
          break;
        case 11:
          await _migrateSearchToVersion11(db);
          break;
        case 12:
          await _migrateConsolidationToVersion12(db);
          break;
        case 13:
          await _migrateRulesToVersion13(db);
          break;
        case 14:
          await _migrateAssetsToVersion14(db);
          break;
        case 15:
          await _migratePayrollToVersion15(db);
          break;
        case 16:
          await _migrateInventoryToVersion16(db);
          break;
        case 17:
          await _migrateIntercompanyToVersion17(db);
          break;
        case 18:
          await _migrateFxToVersion18(db);
          break;
        case 19:
          await _migrateDeferredTaxToVersion19(db);
          break;
        case 20:
          await _migrateAuditHashChainToVersion20(db);
          break;
        case 21:
          await _migrateGlobalFtsToVersion21(db);
          break;
        default:
          debugPrint(
            '[DatabaseService] No migration registered for schema version '
            '$version.',
          );
          break;
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

  Future<void> _migrateChartOfAccountsToVersion7(Database db) async {
    await db.execute(DatabaseTables.createAccounts);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounts_company_id '
      'ON ${DatabaseTables.accounts} (company_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_company_code '
      'ON ${DatabaseTables.accounts} (company_id, code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounts_parent_code '
      'ON ${DatabaseTables.accounts} (parent_code)',
    );
  }

  Future<void> _migrateUsersToVersion8(Database db) async {
    await db.execute(DatabaseTables.createUsers);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_users_role '
      'ON ${DatabaseTables.users} (role)',
    );
  }

  /// Rebuilds the audit table with full session context (user, role, company,
  /// before/after JSON) and enforces append-only behavior with SQL triggers.
  Future<void> _migrateAuditToVersion9(Database db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseTables.auditLogs} RENAME TO audit_logs_legacy',
    );
    await db.execute(DatabaseTables.createAuditLogs);
    await db.execute('''
      INSERT INTO ${DatabaseTables.auditLogs}
        (id, company_id, user_id, user_name, user_role, action, entity_name,
         entity_id, before_state, after_state, ip_address, timestamp)
      SELECT id, NULL, '', 'System', 'system',
        CASE action WHEN 'document_approved' THEN 'update' ELSE action END,
        'Document', NULL, NULL, details, NULL, timestamp
      FROM audit_logs_legacy
    ''');
    await db.execute('DROP TABLE audit_logs_legacy');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp '
      'ON ${DatabaseTables.auditLogs} (timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_action '
      'ON ${DatabaseTables.auditLogs} (action)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_company_timestamp '
      'ON ${DatabaseTables.auditLogs} (company_id, timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_user '
      'ON ${DatabaseTables.auditLogs} (user_id)',
    );
    for (final String trigger in DatabaseTables.createTriggers) {
      await db.execute(trigger);
    }
  }

  Future<void> _migrateCurrencyToVersion10(Database db) async {
    await db.execute(DatabaseTables.createCurrencies);
    await db.execute(DatabaseTables.createExchangeRates);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exchange_rates_lookup '
      'ON ${DatabaseTables.exchangeRates} '
      '(base_currency, target_currency, rate_date)',
    );
    for (final String statement in DatabaseTables.seedCurrencies) {
      await db.execute(statement);
    }
  }

  Future<void> _migrateSearchToVersion11(Database db) async {
    await FtsSetup.install(db);
    await FtsSetup.rebuild(db);
  }

  Future<void> _migrateConsolidationToVersion12(Database db) async {
    await db.execute(DatabaseTables.createCompanyGroups);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_company_groups_parent '
      'ON ${DatabaseTables.companyGroups} (parent_company_id)',
    );
  }

  Future<void> _migrateRulesToVersion13(Database db) async {
    await db.execute(DatabaseTables.createReconciliationRules);
    await db.execute(DatabaseTables.createJournalEntries);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reconciliation_rules_company '
      'ON ${DatabaseTables.reconciliationRules} (company_id, priority)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_company_date '
      'ON ${DatabaseTables.journalEntries} (company_id, entry_date)',
    );
  }

  Future<void> _migrateAssetsToVersion14(Database db) async {
    await db.execute(DatabaseTables.createAssets);
    await db.execute(DatabaseTables.createDepreciationSchedules);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assets_company '
      'ON ${DatabaseTables.assets} (company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_depreciation_schedules_asset '
      'ON ${DatabaseTables.depreciationSchedules} (asset_id, period_date)',
    );
  }

  Future<void> _migratePayrollToVersion15(Database db) async {
    await db.execute(DatabaseTables.createEmployees);
    await db.execute(DatabaseTables.createPayrollRecords);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_employees_company '
      'ON ${DatabaseTables.employees} (company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payroll_records_company_period '
      'ON ${DatabaseTables.payrollRecords} '
      '(company_id, period_year, period_month)',
    );
  }

  Future<void> _migrateInventoryToVersion16(Database db) async {
    await db.execute(DatabaseTables.createWarehouses);
    await db.execute(DatabaseTables.createProducts);
    await db.execute(DatabaseTables.createStockMovements);
    await db.execute(DatabaseTables.createInventoryBatches);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouses_company '
      'ON ${DatabaseTables.warehouses} (company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_company '
      'ON ${DatabaseTables.products} (company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product '
      'ON ${DatabaseTables.stockMovements} (product_id, timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_company_timestamp '
      'ON ${DatabaseTables.stockMovements} (company_id, timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_batches_product '
      'ON ${DatabaseTables.inventoryBatches} (product_id, received_at)',
    );
  }

  Future<void> _migrateIntercompanyToVersion17(Database db) async {
    await db.execute(DatabaseTables.createIntercompanyLoans);
    await db.execute(DatabaseTables.createInterestSchedules);
    await db.execute(DatabaseTables.createDividendDistributions);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_intercompany_loans_lender '
      'ON ${DatabaseTables.intercompanyLoans} (lender_company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_intercompany_loans_borrower '
      'ON ${DatabaseTables.intercompanyLoans} (borrower_company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_interest_schedules_loan '
      'ON ${DatabaseTables.interestSchedules} (loan_id, period_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dividend_distributions_company '
      'ON ${DatabaseTables.dividendDistributions} '
      '(distributing_company_id, declaration_date)',
    );
  }

  Future<void> _migrateFxToVersion18(Database db) async {
    await db.execute(DatabaseTables.createFxBalances);
    await db.execute(DatabaseTables.createFxRevaluations);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fx_balances_company '
      'ON ${DatabaseTables.fxBalances} (company_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fx_revaluations_company_period '
      'ON ${DatabaseTables.fxRevaluations} '
      '(company_id, period_year, period_month)',
    );
  }

  Future<void> _migrateDeferredTaxToVersion19(Database db) async {
    await db.execute(DatabaseTables.createDeferredTaxCalculations);
    await db.execute(DatabaseTables.createTemporaryDifferences);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deferred_tax_calculations_company_period '
      'ON ${DatabaseTables.deferredTaxCalculations} '
      '(company_id, period_year)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_temporary_differences_calculation '
      'ON ${DatabaseTables.temporaryDifferences} (calculation_id)',
    );
  }

  Future<void> _migrateAuditHashChainToVersion20(Database db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseTables.auditLogs} ADD COLUMN previous_hash TEXT',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseTables.auditLogs} ADD COLUMN current_hash TEXT',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseTables.auditLogs} '
      'ADD COLUMN system_device_info TEXT',
    );
  }

  /// Installs the global FTS5 multi-index and backfills it from the existing
  /// relational rows so upgraded installs are searchable immediately.
  Future<void> _migrateGlobalFtsToVersion21(Database db) async {
    await GlobalFtsSetup.install(db);
    await GlobalFtsSetup.rebuild(db);
  }

  Future<void> _createSchema(Database db) async {
    for (final String statement in DatabaseTables.createTables) {
      await db.execute(statement);
    }
    for (final String statement in DatabaseTables.createIndexes) {
      await db.execute(statement);
    }
    for (final String statement in DatabaseTables.createTriggers) {
      await db.execute(statement);
    }
    for (final String statement in DatabaseTables.seedCurrencies) {
      await db.execute(statement);
    }
    await FtsSetup.install(db);
    await GlobalFtsSetup.install(db);
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
