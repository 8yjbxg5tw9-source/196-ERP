import 'package:equatable/equatable.dart';

/// The classified set of audited operations. Values are persisted by [name],
/// so rename with care once a schema has shipped.
enum AuditAction {
  create,
  update,
  delete,
  approve,
  reject,
  login,
  loginFailed,
  logout,
  export,
  backupRestore,
  taxSubmit,
  systemError,
}

extension AuditActionLabel on AuditAction {
  /// Human-readable label shown in the inspector grid and badges.
  String get label => switch (this) {
        AuditAction.create => 'Create',
        AuditAction.update => 'Update',
        AuditAction.delete => 'Delete',
        AuditAction.approve => 'Approve',
        AuditAction.reject => 'Reject',
        AuditAction.login => 'Login',
        AuditAction.loginFailed => 'Login Failed',
        AuditAction.logout => 'Logout',
        AuditAction.export => 'Export',
        AuditAction.backupRestore => 'Backup / Restore',
        AuditAction.taxSubmit => 'Tax Submit',
        AuditAction.systemError => 'System Error',
      };
}

/// An immutable audit-trail record with full session context and cryptographic
/// hash-chaining metadata for tamper-evident integrity verification.
class AuditLogEntity extends Equatable {
  const AuditLogEntity({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.entityName,
    required this.timestamp,
    this.entityId,
    this.beforeState,
    this.afterState,
    this.ipAddress,
    this.previousHash,
    this.currentHash,
    this.systemDeviceInfo,
  });

  final String id;
  final String companyId;
  final String userId;
  final String userName;
  final String userRole;
  final AuditAction action;
  final String entityName;
  final String? entityId;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String? ipAddress;

  /// SHA-256 of the preceding chained record (`64 × '0'` for the first).
  final String? previousHash;

  /// SHA-256 of this record's canonical fields. Empty for legacy rows written
  /// before hash chaining was introduced.
  final String? currentHash;

  /// Best-effort device identity captured at write time.
  final String? systemDeviceInfo;

  final DateTime timestamp;

  /// Whether this record participates in the cryptographic hash chain.
  bool get isChained =>
      currentHash != null && currentHash!.trim().isNotEmpty;

  /// The fields that actually changed between [beforeState] and [afterState],
  /// keyed by field name with the old and new values.
  Map<String, ({Object? before, Object? after})> changedFields() {
    final Map<String, dynamic>? before = beforeState;
    final Map<String, dynamic>? after = afterState;
    final Map<String, ({Object? before, Object? after})> changes =
        <String, ({Object? before, Object? after})>{};
    final Set<String> keys = <String>{
      ...?before?.keys,
      ...?after?.keys,
    };
    for (final String key in keys) {
      final Object? oldValue = before?[key];
      final Object? newValue = after?[key];
      if (!_valuesEqual(oldValue, newValue)) {
        changes[key] = (before: oldValue, after: newValue);
      }
    }
    return changes;
  }

  /// Ordered (sorted by field name) field-level deltas for this record.
  List<EntityChangeDelta> fieldDeltas() {
    final List<EntityChangeDelta> deltas = <EntityChangeDelta>[
      for (final MapEntry<String, ({Object? before, Object? after})> entry
          in changedFields().entries)
        EntityChangeDelta(
          fieldName: entry.key,
          oldValue: entry.value.before,
          newValue: entry.value.after,
        ),
    ]..sort(
        (EntityChangeDelta left, EntityChangeDelta right) =>
            left.fieldName.compareTo(right.fieldName),
      );
    return deltas;
  }

  AuditLogEntity copyWith({
    String? previousHash,
    String? currentHash,
    String? systemDeviceInfo,
  }) {
    return AuditLogEntity(
      id: id,
      companyId: companyId,
      userId: userId,
      userName: userName,
      userRole: userRole,
      action: action,
      entityName: entityName,
      entityId: entityId,
      beforeState: beforeState,
      afterState: afterState,
      ipAddress: ipAddress,
      previousHash: previousHash ?? this.previousHash,
      currentHash: currentHash ?? this.currentHash,
      systemDeviceInfo: systemDeviceInfo ?? this.systemDeviceInfo,
      timestamp: timestamp,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        userId,
        userName,
        userRole,
        action,
        entityName,
        entityId,
        beforeState,
        afterState,
        ipAddress,
        previousHash,
        currentHash,
        systemDeviceInfo,
        timestamp,
      ];

  static bool _valuesEqual(Object? left, Object? right) {
    if (left is num && right is num) {
      return left == right;
    }
    if (left is List && right is List) {
      return left.toString() == right.toString();
    }
    return left == right;
  }
}

/// A single field-level change captured between the before and after states.
class EntityChangeDelta extends Equatable {
  const EntityChangeDelta({
    required this.fieldName,
    this.oldValue,
    this.newValue,
  });

  final String fieldName;
  final Object? oldValue;
  final Object? newValue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fieldName': fieldName,
        'oldValue': oldValue,
        'newValue': newValue,
      };

  @override
  List<Object?> get props => <Object?>[fieldName, oldValue, newValue];
}
