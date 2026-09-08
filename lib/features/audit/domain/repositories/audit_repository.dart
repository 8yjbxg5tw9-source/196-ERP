import '../../../../core/errors/failures.dart';
import '../entities/audit_log_entity.dart';
import '../entities/integrity_check_result.dart';

/// Append-only audit boundary. Consumers can insert records and read them, but
/// the underlying table forbids updates and deletes at the SQLite level.
abstract interface class AuditRepository {
  /// Persists one audit record. Callers must never modify existing records.
  ///
  /// If the record has no hash yet, the previous hash is read from the latest
  /// chained row and the current hash is computed before insertion.
  Future<Result<void>> logAction(AuditLogEntity log);

  /// Lists audit records for [companyId], newest first, optionally narrowed by
  /// a date range, an action type, a user id, and a free-text search term.
  Future<Result<List<AuditLogEntity>>> getLogs({
    required String companyId,
    DateTime? from,
    DateTime? to,
    AuditAction? action,
    String? userId,
    String? search,
  });

  /// Recomputes every chained hash for [companyId] and flags any tampered row.
  Future<Result<IntegrityCheckResult>> verifyAuditChainIntegrity(
    String companyId,
  );
}
