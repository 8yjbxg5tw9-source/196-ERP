import 'package:sqflite/sqflite.dart';

import 'tables.dart';

/// SQLite FTS5 full-text search setup for the local document store.
///
/// [documentsFts] is a self-contained FTS5 virtual table (rather than an
/// external-content table keyed by `documents`), because `documents.id` is a
/// TEXT UUID and FTS5 external-content tables require an INTEGER rowid. The
/// three triggers below keep the index byte-for-byte synchronized with the
/// source `documents` table on INSERT, UPDATE, and DELETE, so search results
/// are always sub-millisecond and always current.
abstract final class FtsSetup {
  static const String documentsFts = 'documents_fts';

  static const String createDocumentsFts = '''
CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
  document_id,
  vendor_name,
  vendor_voen,
  invoice_number,
  extracted_json,
  tokenize = 'unicode61 remove_diacritics 2'
)
''';

  static const String afterInsertTrigger = '''
CREATE TRIGGER IF NOT EXISTS documents_fts_after_insert
AFTER INSERT ON ${DatabaseTables.documents}
BEGIN
  INSERT INTO documents_fts
    (document_id, vendor_name, vendor_voen, invoice_number, extracted_json)
  VALUES
    (new.id, new.vendor_name, new.vendor_voen, new.invoice_number,
     new.extracted_json);
END
''';

  static const String afterDeleteTrigger = '''
CREATE TRIGGER IF NOT EXISTS documents_fts_after_delete
AFTER DELETE ON ${DatabaseTables.documents}
BEGIN
  INSERT INTO documents_fts
    (documents_fts, document_id, vendor_name, vendor_voen, invoice_number,
     extracted_json)
  VALUES
    ('delete', old.id, old.vendor_name, old.vendor_voen, old.invoice_number,
     old.extracted_json);
END
''';

  static const String afterUpdateTrigger = '''
CREATE TRIGGER IF NOT EXISTS documents_fts_after_update
AFTER UPDATE ON ${DatabaseTables.documents}
BEGIN
  INSERT INTO documents_fts
    (documents_fts, document_id, vendor_name, vendor_voen, invoice_number,
     extracted_json)
  VALUES
    ('delete', old.id, old.vendor_name, old.vendor_voen, old.invoice_number,
     old.extracted_json);
  INSERT INTO documents_fts
    (document_id, vendor_name, vendor_voen, invoice_number, extracted_json)
  VALUES
    (new.id, new.vendor_name, new.vendor_voen, new.invoice_number,
     new.extracted_json);
END
''';

  static const List<String> triggers = <String>[
    afterInsertTrigger,
    afterDeleteTrigger,
    afterUpdateTrigger,
  ];

  /// Creates the virtual table and its synchronization triggers (idempotent).
  static Future<void> install(Database db) async {
    await db.execute(createDocumentsFts);
    for (final String trigger in triggers) {
      await db.execute(trigger);
    }
  }

  /// Backfills the index from the current `documents` rows.
  static Future<void> rebuild(Database db) async {
    await db.execute(
      "INSERT INTO documents_fts(documents_fts) VALUES('rebuild')",
    );
  }
}
