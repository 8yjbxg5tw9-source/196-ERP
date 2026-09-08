import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/fts_setup.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/search_result_entity.dart';

/// SQLite boundary for the enterprise global search engine.
///
/// Invoice text is resolved through the `documents_fts` FTS5 index (vendor
/// name, VÖEN, invoice number, and extracted JSON), while companies,
/// transactions, and tax articles use their dedicated tables.
abstract interface class GlobalSearchDataSource {
  Future<List<SearchResultEntity>> search(String query, {int limit});

  Future<List<SearchResultEntity>> recentDocuments({
    String? companyId,
    int limit,
  });
}

class GlobalSearchDataSourceImpl implements GlobalSearchDataSource {
  GlobalSearchDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<SearchResultEntity>> search(String query, {int limit = 20}) async {
    final String normalized = query.trim();
    if (normalized.isEmpty) {
      return recentDocuments(limit: limit);
    }

    final Database database = await _databaseService.database;
    final List<SearchResultEntity> results = <SearchResultEntity>[];

    results.addAll(await _searchDocuments(database, normalized, limit));
    results.addAll(await _searchCompanies(database, normalized, limit));
    results.addAll(await _searchTransactions(database, normalized, limit));
    results.addAll(await _searchTaxRules(database, normalized, limit));

    // Cap the combined payload while keeping at least one row per source.
    return results.take(limit).toList(growable: false);
  }

  @override
  Future<List<SearchResultEntity>> recentDocuments({
    String? companyId,
    int limit = 5,
  }) async {
    final Database database = await _databaseService.database;
    final List<Object?> args = <Object?>[];
    final StringBuffer where = StringBuffer("status = 'completed'");
    if (companyId != null && companyId.trim().isNotEmpty) {
      where.write(' AND company_id = ?');
      args.add(companyId.trim());
    }
    args.add(limit);

    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT id, company_id, vendor_name, vendor_voen, invoice_number, '
      'total_amount, created_at '
      'FROM ${DatabaseTables.documents} '
      'WHERE $where '
      'ORDER BY created_at DESC LIMIT ?',
      args,
    );
    return rows.map(_documentResult).toList(growable: false);
  }

  Future<List<SearchResultEntity>> _searchDocuments(
    Database database,
    String query,
    int limit,
  ) async {
    final String ftsQuery = _ftsQuery(query);
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT d.id, d.company_id, d.vendor_name, d.vendor_voen, '
      'd.invoice_number, d.total_amount '
      'FROM ${FtsSetup.documentsFts} f '
      'JOIN ${DatabaseTables.documents} d ON d.id = f.document_id '
      'WHERE f.${FtsSetup.documentsFts} MATCH ? '
      'ORDER BY f.rank LIMIT ?',
      <Object?>[ftsQuery, limit],
    );
    return rows.map(_documentResult).toList(growable: false);
  }

  Future<List<SearchResultEntity>> _searchCompanies(
    Database database,
    String query,
    int limit,
  ) async {
    final String pattern = '%$query%';
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT id, name, voen_tin, tax_type '
      'FROM ${DatabaseTables.companies} '
      'WHERE name LIKE ? OR voen_tin LIKE ? OR tax_type LIKE ? '
      'ORDER BY name COLLATE NOCASE ASC LIMIT ?',
      <Object?>[pattern, pattern, pattern, limit],
    );
    return rows
        .map(
          (Map<String, Object?> row) => SearchResultEntity(
            id: 'company-${_string(row['id'])}',
            category: SearchCategory.company,
            title: _string(row['name']),
            subtitle: 'VÖEN ${_string(row['voen_tin'])} · '
                '${_string(row['tax_type'])}',
            entityId: _string(row['id']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SearchResultEntity>> _searchTransactions(
    Database database,
    String query,
    int limit,
  ) async {
    final String pattern = '%$query%';
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT id, company_id, description, counterparty_name, '
      'counterparty_voen, reference_code, amount, date '
      'FROM ${DatabaseTables.transactions} '
      'WHERE description LIKE ? OR counterparty_name LIKE ? '
      'OR counterparty_voen LIKE ? OR reference_code LIKE ? '
      'ORDER BY date DESC LIMIT ?',
      <Object?>[pattern, pattern, pattern, pattern, limit],
    );
    return rows
        .map(
          (Map<String, Object?> row) => SearchResultEntity(
            id: 'transaction-${_string(row['id'])}',
            category: SearchCategory.transaction,
            title: _string(row['description']),
            subtitle: _transactionSubtitle(row),
            entityId: _string(row['id']),
            companyId: _nullableString(row['company_id']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SearchResultEntity>> _searchTaxRules(
    Database database,
    String query,
    int limit,
  ) async {
    final String pattern = '%$query%';
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT article_code, title, description, content '
      'FROM ${DatabaseTables.taxRules} '
      'WHERE title LIKE ? OR article_code LIKE ? OR description LIKE ? '
      'OR content LIKE ? '
      'ORDER BY article_code COLLATE NOCASE ASC LIMIT ?',
      <Object?>[pattern, pattern, pattern, pattern, limit],
    );
    return rows
        .map(
          (Map<String, Object?> row) => SearchResultEntity(
            id: 'taxrule-${_string(row['article_code'])}',
            category: SearchCategory.taxRule,
            title: '${_string(row['article_code'])} · ${_string(row['title'])}',
            subtitle: _snippet(_string(row['description'])),
            entityId: _string(row['article_code']),
          ),
        )
        .toList(growable: false);
  }

  static SearchResultEntity _documentResult(Map<String, Object?> row) {
    final String vendorName = _string(row['vendor_name']);
    final String invoiceNumber = _string(row['invoice_number']);
    final String title = vendorName.isNotEmpty ? vendorName : invoiceNumber;
    final String amount = _amount(row['total_amount']);
    final StringBuffer subtitle = StringBuffer();
    if (invoiceNumber.isNotEmpty) {
      subtitle.write('Invoice $invoiceNumber');
    }
    if (amount.isNotEmpty) {
      if (subtitle.isNotEmpty) {
        subtitle.write(' · ');
      }
      subtitle.write(amount);
    }
    if (subtitle.isEmpty) {
      subtitle.write('OCR invoice');
    }
    return SearchResultEntity(
      id: 'document-${_string(row['id'])}',
      category: SearchCategory.document,
      title: title,
      subtitle: subtitle.toString(),
      entityId: _string(row['id']),
      companyId: _nullableString(row['company_id']),
    );
  }

  static String _transactionSubtitle(Map<String, Object?> row) {
    final String counterparty = _string(row['counterparty_name']);
    final String voen = _string(row['counterparty_voen']);
    final String amount = _amount(row['amount']);
    final List<String> parts = <String>[
      if (counterparty.isNotEmpty) counterparty,
      if (voen.isNotEmpty) voen,
      if (amount.isNotEmpty) amount,
    ];
    return parts.isEmpty ? 'Bank transaction' : parts.join(' · ');
  }

  /// Wraps each whitespace token as a quoted prefix phrase so user input is
  /// treated literally and `*` enables sub-second prefix matching.
  static String _ftsQuery(String raw) {
    final String escaped = raw.replaceAll('"', '""');
    final List<String> tokens = escaped
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    return tokens.map((String token) => '"$token"*').join(' ');
  }

  static String _snippet(String value) {
    final String normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 90
        ? normalized
        : '${normalized.substring(0, 90)}…';
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static String? _nullableString(Object? value) {
    final String text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _amount(Object? value) {
    final double? parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return '';
    }
    return '₼${parsed.toStringAsFixed(2)}';
  }
}
