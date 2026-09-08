import 'dart:convert';

import '../../domain/entities/audit_log_entity.dart';

/// SQLite representation of an [AuditLogEntity].
class AuditLogModel extends AuditLogEntity {
  const AuditLogModel({
    required super.id,
    required super.companyId,
    required super.userId,
    required super.userName,
    required super.userRole,
    required super.action,
    required super.entityName,
    required super.timestamp,
    super.entityId,
    super.beforeState,
    super.afterState,
    super.ipAddress,
    super.previousHash,
    super.currentHash,
    super.systemDeviceInfo,
  });

  factory AuditLogModel.fromMap(Map<String, Object?> map) {
    return AuditLogModel(
      id: _string(map['id']),
      companyId: _string(map['company_id']),
      userId: _string(map['user_id']),
      userName: _string(map['user_name']),
      userRole: _string(map['user_role']),
      action: _action(map['action']),
      entityName: _string(map['entity_name']),
      entityId: _nullableString(map['entity_id']),
      beforeState: _jsonMap(map['before_state']),
      afterState: _jsonMap(map['after_state']),
      ipAddress: _nullableString(map['ip_address']),
      previousHash: _nullableString(map['previous_hash']),
      currentHash: _nullableString(map['current_hash']),
      systemDeviceInfo: _nullableString(map['system_device_info']),
      timestamp: _dateTime(_string(map['timestamp'])),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'action': action.name,
      'entity_name': entityName,
      'entity_id': entityId,
      'before_state': beforeState == null ? null : jsonEncode(beforeState),
      'after_state': afterState == null ? null : jsonEncode(afterState),
      'ip_address': ipAddress,
      'previous_hash': previousHash,
      'current_hash': currentHash,
      'system_device_info': systemDeviceInfo,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  static String _string(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _nullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  static DateTime _dateTime(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static AuditAction _action(Object? value) {
    final String name = value?.toString() ?? '';
    for (final AuditAction action in AuditAction.values) {
      if (action.name == name) {
        return action;
      }
    }
    return AuditAction.update;
  }

  static Map<String, dynamic>? _jsonMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map<Object?, Object?>) {
          return <String, dynamic>{
            for (final MapEntry<Object?, Object?> entry in decoded.entries)
              entry.key.toString(): entry.value,
          };
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}
