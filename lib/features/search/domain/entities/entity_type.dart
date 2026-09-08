/// The financial entity dimensions indexed by the global FTS5 engine.
enum EntityType {
  transaction,
  invoice,
  counterparty,
  asset,
  payroll,
  account,
}

extension EntityTypeMeta on EntityType {
  /// Human-readable group header shown in the command palette.
  String get label => switch (this) {
        EntityType.transaction => 'Ledger Entries',
        EntityType.invoice => 'Invoices',
        EntityType.counterparty => 'Counterparties',
        EntityType.asset => 'Fixed Assets',
        EntityType.payroll => 'Payroll',
        EntityType.account => 'Accounts',
      };

  /// Stable wire name persisted in the FTS index `entity_type` column.
  String get wireName => name;

  /// Parses a wire name back into an [EntityType], defaulting to
  /// [EntityType.transaction] for unknown values encountered in an older
  /// index.
  static EntityType fromWireName(String value) {
    for (final EntityType type in EntityType.values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return EntityType.transaction;
  }
}
