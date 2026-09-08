import 'package:flutter/foundation.dart';

import '../../features/audit/domain/entities/audit_log_entity.dart';
import '../../features/audit/domain/repositories/audit_repository.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../storage/secure_storage_service.dart';

/// Single write path for the immutable audit trail.
///
/// Every financial modification, login/logout, export, and backup/restore goes
/// through [logAction] so session context (user id, name, role, company) is
/// attached consistently. Records are append-only: SQLite triggers reject any
/// UPDATE or DELETE against the underlying table.
class AuditLoggerService {
  AuditLoggerService({
    required AuditRepository auditRepository,
    required SecureStorageService secureStorage,
    required AuthLocalDataSource authLocalDataSource,
  })  : _auditRepository = auditRepository,
        _secureStorage = secureStorage,
        _authLocalDataSource = authLocalDataSource;

  final AuditRepository _auditRepository;
  final SecureStorageService _secureStorage;
  final AuthLocalDataSource _authLocalDataSource;

  /// Records an action with the current session context. Failures are logged
  /// rather than thrown so auditing never blocks the primary operation.
  Future<void> logAction({
    required AuditAction action,
    required String entityName,
    String? entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    try {
      final AuditLogEntity log = await buildLog(
        action: action,
        entityName: entityName,
        entityId: entityId,
        before: before,
        after: after,
      );
      await _auditRepository.logAction(log);
    } on Object catch (error) {
      debugPrint('[AuditLoggerService] Audit write failed: $error');
    }
  }

  /// Builds a fully contextualized record (without persisting it) so callers
  /// that need the write to be atomic with another database operation can
  /// insert it inside the same transaction.
  Future<AuditLogEntity> buildLog({
    required AuditAction action,
    required String entityName,
    String? entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? companyId,
  }) async {
    final String userId =
        await _secureStorage.read(SecureStorageKeys.authUserId) ?? '';
    final String resolvedCompanyId =
        companyId ??
        await _secureStorage.read(SecureStorageKeys.activeCompanyId) ??
        '';

    UserEntity? user;
    if (userId.isNotEmpty) {
      user = await _authLocalDataSource.findUserById(userId);
    }

    final String userName;
    final String userRole;
    if (user == null) {
      userName = 'System';
      userRole = 'system';
    } else {
      userName = user.fullName.isEmpty ? user.username : user.fullName;
      userRole = user.role.name;
    }

    return AuditLogEntity(
      id: 'audit-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      companyId: resolvedCompanyId,
      userId: userId,
      userName: userName,
      userRole: userRole,
      action: action,
      entityName: entityName,
      entityId: entityId,
      beforeState: before,
      afterState: after,
      ipAddress: null,
      timestamp: DateTime.now().toUtc(),
    );
  }
}
