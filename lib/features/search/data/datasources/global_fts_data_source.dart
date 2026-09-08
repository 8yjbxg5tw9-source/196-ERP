import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/global_fts_setup.dart';
import '../../../../core/database/tables.dart';
import '../../domain/entities/entity_lineage_node.dart';
import '../../domain/entities/entity_type.dart';
import '../../domain/entities/search_query_entity.dart';
import '../../domain/entities/search_result_item_entity.dart';
import '../../domain/services/fts_search_engine.dart';

/// SQLite boundary for the multi-index FTS5 search engine and lineage graph.
abstract interface class GlobalFtsDataSource {
  Future<List<SearchResultItemEntity>> search(SearchQueryEntity query);

  Future<EntityLineageGraph> lineage({
    required String entityId,
    required EntityType type,
  });
}

class GlobalFtsDataSourceImpl implements GlobalFtsDataSource {
  GlobalFtsDataSourceImpl(
    this._databaseService, {
    FtsSearchEngine engine = const FtsSearchEngine(),
  }) : _engine = engine;

  final DatabaseService _databaseService;
  final FtsSearchEngine _engine;

  @override
  Future<List<SearchResultItemEntity>> search(SearchQueryEntity query) async {
    final String match = _engine.ftsMatchExpression(query.query);
    if (match.isEmpty) {
      return const <SearchResultItemEntity>[];
    }

    final Database db = await _databaseService.database;
    final List<Object?> args = <Object?>[match];
    final StringBuffer where = StringBuffer(
      '${GlobalFtsSetup.table} MATCH ?',
    );

    final List<EntityType>? filters = query.filters;
    if (filters != null && filters.isNotEmpty) {
      final List<String> types = <String>[
        for (final EntityType type in filters) type.wireName,
      ];
      where.write(
        ' AND entity_type IN (${_placeholders(types.length)})',
      );
      args.addAll(types);
    }
    args.add(query.limit);

    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT entity_id, entity_type, title, content, voen, amount, '
      'bm25(${GlobalFtsSetup.table}) AS rank '
      'FROM ${GlobalFtsSetup.table} '
      'WHERE $where '
      'ORDER BY rank LIMIT ?',
      args,
    );

    final List<SearchResultItemEntity> results = await _enrich(db, rows);
    results.sort(
      (SearchResultItemEntity a, SearchResultItemEntity b) =>
          b.score.compareTo(a.score),
    );
    return results;
  }

  @override
  Future<EntityLineageGraph> lineage({
    required String entityId,
    required EntityType type,
  }) async {
    final Database db = await _databaseService.database;
    final List<EntityLineageNode> nodes = switch (type) {
      EntityType.transaction => await _transactionLineage(db, entityId),
      EntityType.invoice => await _invoiceLineage(db, entityId),
      EntityType.counterparty => await _counterpartyLineage(db, entityId),
      EntityType.account => await _accountLineage(db, entityId),
      EntityType.asset => await _assetLineage(db, entityId),
      EntityType.payroll => await _payrollLineage(db, entityId),
    };

    final EntityLineageGraph? graph = _engine.assembleLineage(
      nodes,
      rootId: _nodeId(type, entityId),
    );
    if (graph == null) {
      throw StateError('Lineage for $type:$entityId could not be assembled.');
    }
    return graph;
  }

  // ---------------------------------------------------------------------------
  // Search enrichment
  // ---------------------------------------------------------------------------

  Future<List<SearchResultItemEntity>> _enrich(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    final Map<EntityType, List<Map<String, Object?>>> grouped =
        <EntityType, List<Map<String, Object?>>>{};
    for (final Map<String, Object?> row in rows) {
      final EntityType type = EntityTypeMeta.fromWireName(
        _str(row['entity_type']),
      );
      grouped.putIfAbsent(type, () => <Map<String, Object?>>[]).add(row);
    }

    final List<SearchResultItemEntity> results = <SearchResultItemEntity>[];
    for (final MapEntry<EntityType, List<Map<String, Object?>>> entry
        in grouped.entries) {
      final List<String> ids = <String>[
        for (final Map<String, Object?> row in entry.value)
          _str(row['entity_id']),
      ];
      final Map<String, Map<String, Object?>> sourceRows = await _sourceRows(
        db,
        entry.key,
        ids,
      );

      for (final Map<String, Object?> ftsRow in entry.value) {
        final String id = _str(ftsRow['entity_id']);
        final Map<String, Object?>? source = sourceRows[id];
        results.add(
          _buildResult(
            type: entry.key,
            id: id,
            ftsRow: ftsRow,
            source: source,
            score: _engine.relevanceScore(ftsRow['rank']),
          ),
        );
      }
    }
    return results;
  }

  Future<Map<String, Map<String, Object?>>> _sourceRows(
    Database db,
    EntityType type,
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <String, Map<String, Object?>>{};
    }

    final String idList = _placeholders(ids.length);
    final (String table, String columns) = switch (type) {
      EntityType.transaction => (
          DatabaseTables.transactions,
          'id, company_id, description, counterparty_name, '
              'counterparty_voen, amount, date, reference_code, match_status',
        ),
      EntityType.invoice => (
          DatabaseTables.documents,
          'id, company_id, invoice_number, vendor_name, vendor_voen, '
              'total_amount, issue_date, status, created_at',
        ),
      EntityType.counterparty => (
          DatabaseTables.companies,
          'id, name, voen_tin, tax_type',
        ),
      EntityType.account => (
          DatabaseTables.accounts,
          'id, company_id, code, name, type',
        ),
      EntityType.asset => (
          DatabaseTables.assets,
          'id, company_id, asset_code, name, category, book_value, status',
        ),
      EntityType.payroll => (
          DatabaseTables.payrollRecords,
          'id, company_id, employee_id, period_month, period_year, '
              'net_salary, gross_salary, created_at',
        ),
    };

    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT $columns FROM $table WHERE id IN ($idList)',
      ids,
    );
    return <String, Map<String, Object?>>{
      for (final Map<String, Object?> row in rows) _str(row['id']): row,
    };
  }

  SearchResultItemEntity _buildResult({
    required EntityType type,
    required String id,
    required Map<String, Object?> ftsRow,
    required Map<String, Object?>? source,
    required double score,
  }) {
    final String title = source == null
        ? _str(ftsRow['title'])
        : _titleFor(type, source);
    final String subtitle = source == null
        ? _str(ftsRow['content'])
        : _subtitleFor(type, source);
    final String? voen = source == null
        ? _nullable(ftsRow['voen'])
        : _voenFor(type, source);
    final double? amount = source == null
        ? _double(ftsRow['amount'])
        : _amountFor(type, source);
    final DateTime? timestamp =
        source == null ? null : _timestampFor(type, source);

    return SearchResultItemEntity(
      id: id,
      entityType: type,
      title: title.isEmpty ? type.label : title,
      subtitle: subtitle,
      voen: voen,
      amount: amount,
      timestamp: timestamp,
      score: score,
      deepLinkRoute: SearchResultItemEntity.routeFor(type, id),
    );
  }

  static String _titleFor(EntityType type, Map<String, Object?> row) {
    return switch (type) {
      EntityType.transaction => _str(row['description']),
      EntityType.invoice => _str(row['vendor_name']).isNotEmpty
          ? _str(row['vendor_name'])
          : _str(row['invoice_number']),
      EntityType.counterparty => _str(row['name']),
      EntityType.account =>
        '${_str(row['code'])} ${_str(row['name'])}'.trim(),
      EntityType.asset =>
        '${_str(row['asset_code'])} ${_str(row['name'])}'.trim(),
      EntityType.payroll =>
        'Payroll ${_str(row['period_month'])}/${_str(row['period_year'])}',
    };
  }

  static String _subtitleFor(EntityType type, Map<String, Object?> row) {
    return switch (type) {
      EntityType.transaction => _joinNonEmpty(
          <String>[
            _str(row['counterparty_name']),
            _str(row['counterparty_voen']),
            _money(row['amount']),
          ],
        ),
      EntityType.invoice => _joinNonEmpty(<String>[
          'Invoice ${_str(row['invoice_number'])}'.trim(),
          _str(row['status']),
          _money(row['total_amount']),
        ]),
      EntityType.counterparty => _joinNonEmpty(<String>[
          'VÖEN ${_str(row['voen_tin'])}'.trim(),
          _str(row['tax_type']),
        ]),
      EntityType.account => _str(row['type']),
      EntityType.asset => _joinNonEmpty(<String>[
          _str(row['category']),
          _str(row['status']),
          _money(row['book_value']),
        ]),
      EntityType.payroll => _joinNonEmpty(<String>[
          'Net ${_money(row['net_salary'])}'.trim(),
          'Gross ${_money(row['gross_salary'])}'.trim(),
        ]),
    };
  }

  static String? _voenFor(EntityType type, Map<String, Object?> row) {
    return switch (type) {
      EntityType.transaction => _nullable(row['counterparty_voen']),
      EntityType.invoice => _nullable(row['vendor_voen']),
      EntityType.counterparty => _nullable(row['voen_tin']),
      _ => null,
    };
  }

  static double? _amountFor(EntityType type, Map<String, Object?> row) {
    return switch (type) {
      EntityType.transaction => _double(row['amount']),
      EntityType.invoice => _double(row['total_amount']),
      EntityType.asset => _double(row['book_value']),
      EntityType.payroll => _double(row['net_salary']),
      _ => null,
    };
  }

  static DateTime? _timestampFor(EntityType type, Map<String, Object?> row) {
    return switch (type) {
      EntityType.transaction => _date(row['date']),
      EntityType.invoice =>
        _date(row['issue_date']) ?? _date(row['created_at']),
      EntityType.payroll => _date(row['created_at']),
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Lineage graph construction
  // ---------------------------------------------------------------------------

  Future<List<EntityLineageNode>> _transactionLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.transactions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Transaction $id not found.');
    }
    final Map<String, Object?> tx = rows.first;
    final String transactionNodeId = _nodeId(EntityType.transaction, id);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final String documentId = _str(tx['document_id']);
    if (documentId.isNotEmpty) {
      final EntityLineageNode? invoice = await _documentNode(db, documentId);
      if (invoice != null) {
        nodes.add(invoice.copyWith(childNodeIds: <String>[transactionNodeId]));
      }
    }

    final List<Map<String, Object?>> journalRows = await _journalEntriesForSource(
      db,
      id,
    );
    final List<String> journalIds = <String>[
      for (final Map<String, Object?> row in journalRows)
        _journalNodeId(_str(row['id'])),
    ];
    nodes.addAll(
      journalRows.map(
        (Map<String, Object?> row) =>
            _journalNode(row).copyWith(parentNodeIds: <String>[transactionNodeId]),
      ),
    );

    nodes.add(
      _transactionNode(tx).copyWith(
        parentNodeIds: documentId.isEmpty
            ? const <String>[]
            : <String>[_nodeId(EntityType.invoice, documentId)],
        childNodeIds: journalIds,
      ),
    );
    return nodes;
  }

  Future<List<EntityLineageNode>> _invoiceLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.documents,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Invoice $id not found.');
    }
    final Map<String, Object?> doc = rows.first;
    final String invoiceNodeId = _nodeId(EntityType.invoice, id);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final List<Map<String, Object?>> txRows = await db.query(
      DatabaseTables.transactions,
      where: 'document_id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'date ASC',
    );
    final List<String> txIds = <String>[
      for (final Map<String, Object?> row in txRows) _str(row['id']),
    ];
    final Map<String, List<Map<String, Object?>>> journalsBySource =
        await _journalEntriesBySource(db, txIds);

    final List<String> childIds = <String>[
      for (final Map<String, Object?> row in txRows)
        _nodeId(EntityType.transaction, _str(row['id'])),
    ];

    for (final Map<String, Object?> tx in txRows) {
      final String txId = _str(tx['id']);
      final List<Map<String, Object?>> glRows =
          journalsBySource[txId] ?? const <Map<String, Object?>>[];
      final List<String> glIds = <String>[
        for (final Map<String, Object?> row in glRows) _journalNodeId(_str(row['id'])),
      ];
      nodes.add(
        _transactionNode(tx).copyWith(
          parentNodeIds: <String>[invoiceNodeId],
          childNodeIds: glIds,
        ),
      );
      nodes.addAll(
        glRows.map(
          (Map<String, Object?> row) => _journalNode(row).copyWith(
            parentNodeIds: <String>[_nodeId(EntityType.transaction, txId)],
          ),
        ),
      );
    }

    nodes.add(
      _documentNodeFromRow(doc).copyWith(childNodeIds: childIds),
    );
    return nodes;
  }

  Future<List<EntityLineageNode>> _counterpartyLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.companies,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Counterparty $id not found.');
    }
    final Map<String, Object?> company = rows.first;
    final String companyNodeId = _nodeId(EntityType.counterparty, id);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final List<Map<String, Object?>> docs = await db.query(
      DatabaseTables.documents,
      where: 'company_id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'created_at ASC',
    );
    final List<Map<String, Object?>> transactions = await db.query(
      DatabaseTables.transactions,
      where: 'company_id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'date ASC',
    );

    final List<String> childIds = <String>[
      for (final Map<String, Object?> row in docs)
        _nodeId(EntityType.invoice, _str(row['id'])),
      for (final Map<String, Object?> row in transactions)
        _nodeId(EntityType.transaction, _str(row['id'])),
    ];

    for (final Map<String, Object?> row in docs) {
      nodes.add(
        _documentNodeFromRow(row).copyWith(parentNodeIds: <String>[companyNodeId]),
      );
    }
    for (final Map<String, Object?> row in transactions) {
      nodes.add(
        _transactionNode(row).copyWith(parentNodeIds: <String>[companyNodeId]),
      );
    }

    nodes.add(
      EntityLineageNode(
        id: companyNodeId,
        nodeType: 'CP-${_str(company['voen_tin'])}',
        description: _str(company['name']),
        amount: 0,
        status: _str(company['tax_type']),
        timestamp: _date(company['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        entityType: EntityType.counterparty,
        childNodeIds: childIds,
        rawMetadata: company,
      ),
    );
    return nodes;
  }

  Future<List<EntityLineageNode>> _accountLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.accounts,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Account $id not found.');
    }
    final Map<String, Object?> account = rows.first;
    final String code = _str(account['code']);
    final String accountNodeId = _nodeId(EntityType.account, id);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final List<Map<String, Object?>> journalRows = await db.query(
      DatabaseTables.journalEntries,
      where: 'debit_account = ? OR credit_account = ?',
      whereArgs: <Object?>[code, code],
      orderBy: 'entry_date ASC',
    );
    final List<String> childIds = <String>[
      for (final Map<String, Object?> row in journalRows)
        _journalNodeId(_str(row['id'])),
    ];

    nodes.addAll(
      journalRows.map(
        (Map<String, Object?> row) =>
            _journalNode(row).copyWith(parentNodeIds: <String>[accountNodeId]),
      ),
    );
    nodes.add(
      EntityLineageNode(
        id: accountNodeId,
        nodeType: code,
        description: _str(account['name']),
        amount: 0,
        status: _str(account['type']),
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        entityType: EntityType.account,
        childNodeIds: childIds,
        rawMetadata: account,
      ),
    );
    return nodes;
  }

  Future<List<EntityLineageNode>> _assetLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.assets,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Asset $id not found.');
    }
    final Map<String, Object?> asset = rows.first;
    final String assetNodeId = _nodeId(EntityType.asset, id);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final List<Map<String, Object?>> schedules = await db.query(
      DatabaseTables.depreciationSchedules,
      where: 'asset_id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'period_date ASC',
    );
    final List<Map<String, Object?>> journalRows = await _journalEntriesForSource(
      db,
      id,
      sourceType: 'depreciation',
    );

    final List<String> childIds = <String>[
      for (final Map<String, Object?> row in schedules)
        _scheduleNodeId(_str(row['id'])),
      for (final Map<String, Object?> row in journalRows)
        _journalNodeId(_str(row['id'])),
    ];

    nodes.addAll(
      schedules.map(
        (Map<String, Object?> row) => _scheduleNode(row).copyWith(
          parentNodeIds: <String>[assetNodeId],
        ),
      ),
    );
    nodes.addAll(
      journalRows.map(
        (Map<String, Object?> row) =>
            _journalNode(row).copyWith(parentNodeIds: <String>[assetNodeId]),
      ),
    );
    nodes.add(
      EntityLineageNode(
        id: assetNodeId,
        nodeType: _str(asset['asset_code']),
        description: _str(asset['name']),
        amount: _double(asset['book_value']) ?? 0,
        status: _str(asset['status']),
        timestamp: _date(asset['purchase_date']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        entityType: EntityType.asset,
        childNodeIds: childIds,
        rawMetadata: asset,
      ),
    );
    return nodes;
  }

  Future<List<EntityLineageNode>> _payrollLineage(
    Database db,
    String id,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.payrollRecords,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Payroll record $id not found.');
    }
    final Map<String, Object?> record = rows.first;
    final String payrollNodeId = _nodeId(EntityType.payroll, id);
    final String employeeId = _str(record['employee_id']);
    final List<EntityLineageNode> nodes = <EntityLineageNode>[];

    final EntityLineageNode? employee = await _employeeNode(db, employeeId);
    if (employee != null) {
      nodes.add(employee.copyWith(childNodeIds: <String>[payrollNodeId]));
    }

    final List<Map<String, Object?>> journalRows = await _journalEntriesForSource(
      db,
      id,
      sourceType: 'payroll',
    );
    final List<String> journalIds = <String>[
      for (final Map<String, Object?> row in journalRows)
        _journalNodeId(_str(row['id'])),
    ];
    nodes.addAll(
      journalRows.map(
        (Map<String, Object?> row) =>
            _journalNode(row).copyWith(parentNodeIds: <String>[payrollNodeId]),
      ),
    );

    final String period =
        '${_str(record['period_month'])}/${_str(record['period_year'])}';
    nodes.add(
      EntityLineageNode(
        id: payrollNodeId,
        nodeType: 'PAY-$period',
        description: 'Monthly payroll $period',
        amount: _double(record['net_salary']) ?? 0,
        status: _str(record['is_approved']) == '1' ? 'approved' : 'draft',
        timestamp: _date(record['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        entityType: EntityType.payroll,
        parentNodeIds: employee == null
            ? const <String>[]
            : <String>[_employeeNodeId(employeeId)],
        childNodeIds: journalIds,
        rawMetadata: record,
      ),
    );
    return nodes;
  }

  Future<EntityLineageNode?> _documentNode(Database db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.documents,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _documentNodeFromRow(rows.first);
  }

  Future<EntityLineageNode?> _employeeNode(Database db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.employees,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, Object?> row = rows.first;
    return EntityLineageNode(
      id: _employeeNodeId(id),
      nodeType: 'EMP-${_short(id)}',
      description: _str(row['full_name']),
      amount: _double(row['base_salary']) ?? 0,
      status: _str(row['position']),
      timestamp: _date(row['start_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entityType: EntityType.payroll,
      rawMetadata: row,
    );
  }

  Future<List<Map<String, Object?>>> _journalEntriesForSource(
    Database db,
    String sourceId, {
    String? sourceType,
  }) async {
    if (sourceType != null) {
      return db.query(
        DatabaseTables.journalEntries,
        where: 'source_id = ? AND source_type = ?',
        whereArgs: <Object?>[sourceId, sourceType],
        orderBy: 'entry_date ASC',
      );
    }
    return db.query(
      DatabaseTables.journalEntries,
      where: 'source_id = ? AND source_type IN (?, ?)',
      whereArgs: <Object?>[sourceId, 'bank', 'journal'],
      orderBy: 'entry_date ASC',
    );
  }

  Future<Map<String, List<Map<String, Object?>>>> _journalEntriesBySource(
    Database db,
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) {
      return const <String, List<Map<String, Object?>>>{};
    }
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.journalEntries,
      where:
          'source_id IN (${_placeholders(sourceIds.length)}) '
          "AND source_type IN ('bank', 'journal')",
      whereArgs: sourceIds,
      orderBy: 'entry_date ASC',
    );
    final Map<String, List<Map<String, Object?>>> grouped =
        <String, List<Map<String, Object?>>>{};
    for (final Map<String, Object?> row in rows) {
      grouped
          .putIfAbsent(_str(row['source_id']), () => <Map<String, Object?>>[])
          .add(row);
    }
    return grouped;
  }

  // ---------------------------------------------------------------------------
  // Node builders
  // ---------------------------------------------------------------------------

  EntityLineageNode _transactionNode(Map<String, Object?> row) {
    final String id = _str(row['id']);
    final String reference = _str(row['reference_code']);
    return EntityLineageNode(
      id: _nodeId(EntityType.transaction, id),
      nodeType: reference.isNotEmpty ? reference : 'BANK-TXN-${_short(id)}',
      description: _str(row['description']),
      amount: _double(row['amount']) ?? 0,
      status: _str(row['match_status']),
      timestamp:
          _date(row['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      entityType: EntityType.transaction,
      rawMetadata: row,
    );
  }

  EntityLineageNode _documentNodeFromRow(Map<String, Object?> row) {
    final String id = _str(row['id']);
    final String invoiceNumber = _str(row['invoice_number']);
    return EntityLineageNode(
      id: _nodeId(EntityType.invoice, id),
      nodeType: invoiceNumber.isNotEmpty ? invoiceNumber : 'INV-${_short(id)}',
      description: _str(row['vendor_name']),
      amount: _double(row['total_amount']) ?? 0,
      status: _str(row['status']),
      timestamp: _date(row['issue_date']) ??
          _date(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entityType: EntityType.invoice,
      rawMetadata: row,
    );
  }

  EntityLineageNode _journalNode(Map<String, Object?> row) {
    final String id = _str(row['id']);
    return EntityLineageNode(
      id: _journalNodeId(id),
      nodeType: 'GL-ENTRY-${_short(id)}',
      description: _str(row['description']),
      amount: _double(row['amount']) ?? 0,
      status: 'posted',
      timestamp:
          _date(row['entry_date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      entityType: EntityType.account,
      rawMetadata: row,
    );
  }

  EntityLineageNode _scheduleNode(Map<String, Object?> row) {
    final String id = _str(row['id']);
    return EntityLineageNode(
      id: _scheduleNodeId(id),
      nodeType: 'DEPR-${_str(row['period_date'])}',
      description: 'Depreciation period',
      amount: _double(row['depreciation_amount']) ?? 0,
      status: _str(row['is_posted']) == '1' ? 'posted' : 'pending',
      timestamp:
          _date(row['period_date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      entityType: EntityType.asset,
      rawMetadata: row,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _nodeId(EntityType type, String id) => '${type.name}:$id';

  static String _journalNodeId(String id) => 'journal:$id';

  static String _employeeNodeId(String id) => 'employee:$id';

  static String _scheduleNodeId(String id) => 'schedule:$id';

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');

  static String _str(Object? value) => value?.toString() ?? '';

  static String? _nullable(Object? value) {
    final String text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static double? _double(Object? value) {
    final double? parsed = double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static DateTime? _date(Object? value) {
    final String text = value?.toString() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text);
  }

  static String _short(String id) =>
      id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

  static String _money(Object? value) {
    final double? amount = _double(value);
    return amount == null ? '' : '₼${amount.toStringAsFixed(2)}';
  }

  static String _joinNonEmpty(List<String> parts) {
    return parts.where((String part) => part.isNotEmpty).join(' · ');
  }
}
