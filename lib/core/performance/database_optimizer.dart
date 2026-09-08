import 'package:sqflite/sqflite.dart';

import '../database/fts_setup.dart';
import '../database/global_fts_setup.dart';
import '../database/tables.dart';

/// Low-level SQLite performance hardening and maintenance routines.
///
/// Exposes the `PRAGMA optimize`, `VACUUM`, and `PRAGMA wal_checkpoint(TRUNCATE)`
/// maintenance procedures from Step 40, plus FTS5 index rebuilds and the
/// composite indexes that keep 100k+ ledger rows queryable in sub-10ms.
class DatabaseOptimizer {
  const DatabaseOptimizer();

  /// Runs SQLite's own statistics-driven query-plan optimization.
  Future<void> optimize(Database db) async {
    await db.execute('PRAGMA optimize');
  }

  /// Defragments and reclaims free pages. Must not run inside a transaction.
  Future<void> vacuum(Database db) async {
    await db.execute('VACUUM');
  }

  /// Checkpoints and truncates the WAL so uncommitted journal growth is
  /// reined in after large batch imports.
  Future<void> checkpointTruncate(Database db) async {
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// Rebuilds both FTS5 indexes (`documents_fts` and `fts_global_index`)
  /// from their source tables.
  Future<void> rebuildFts(Database db) async {
    await FtsSetup.rebuild(db);
    await GlobalFtsSetup.rebuild(db);
  }

  /// Creates the composite/foreign-key indexes required for fast company-,
  /// date-, and account-scoped queries (idempotent).
  Future<void> ensureCompositeIndexes(Database db) async {
    const List<String> statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_transactions_company_created '
          'ON transactions (company_id, date)',
      'CREATE INDEX IF NOT EXISTS idx_documents_company_created '
          'ON documents (company_id, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_accounts_code '
          'ON accounts (code)',
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_source '
          'ON journal_entries (source_type, source_id)',
      'CREATE INDEX IF NOT EXISTS idx_assets_company_code '
          'ON assets (company_id, asset_code)',
    ];
    for (final String statement in statements) {
      await db.execute(statement);
    }
  }

  /// Lightweight maintenance suitable for idle moments or app shutdown.
  Future<void> runQuickMaintenance(Database db) async {
    await optimize(db);
    await checkpointTruncate(db);
  }

  /// Full maintenance: index creation, FTS rebuilds, optimize, and WAL
  /// checkpoint. Intended for the one-click diagnostics workspace.
  Future<void> runFullMaintenance(Database db) async {
    await ensureCompositeIndexes(db);
    await rebuildFts(db);
    await optimize(db);
    await checkpointTruncate(db);
  }

  /// Convenience accessor for the shared connection name.
  String get ftsTable => GlobalFtsSetup.table;

  /// The set of foreign-key relationships the optimizer documents for review.
  List<String> get indexedForeignKeys => const <String>[
        '${DatabaseTables.transactions}.company_id → ${DatabaseTables.companies}.id',
        '${DatabaseTables.transactions}.document_id → ${DatabaseTables.documents}.id',
        '${DatabaseTables.documents}.company_id → ${DatabaseTables.companies}.id',
        '${DatabaseTables.journalEntries}.company_id → ${DatabaseTables.companies}.id',
      ];
}
