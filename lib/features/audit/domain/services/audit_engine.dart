import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/audit_log_entity.dart';
import '../entities/integrity_check_result.dart';

/// Cryptographic audit engine: SHA-256 hash chaining and tamper verification.
///
/// Each chained record's hash is computed as
///
/// ```text
/// SHA256(previousHash + timestamp + userId + action + targetEntityId + fieldDeltasJson)
/// ```
///
/// mirroring a blockchain ledger where every block commits to the one before
/// it, so a single altered field anywhere in the chain breaks every hash that
/// follows and is flagged precisely by [verifyChain].
class AuditEngine {
  const AuditEngine();

  /// The genesis hash a company's first chained record points back to.
  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Computes the canonical JSON of [deltas] used as the hash input tail.
  String deltasJson(List<EntityChangeDelta> deltas) {
    return jsonEncode(
      <Map<String, dynamic>>[
        for (final EntityChangeDelta delta in deltas) delta.toJson(),
      ],
    );
  }

  /// Computes the SHA-256 chain hash for one record.
  String computeHash({
    required String previousHash,
    required DateTime timestamp,
    required String userId,
    required String action,
    required String targetEntityId,
    required List<EntityChangeDelta> deltas,
  }) {
    final String input = <String>[
      previousHash,
      timestamp.toUtc().toIso8601String(),
      userId,
      action,
      targetEntityId,
      deltasJson(deltas),
    ].join();
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Verifies the hash chain over [logs], which must be in ascending
  /// chronological order.
  ///
  /// Legacy rows (no `currentHash`) are counted but skipped: they predate hash
  /// chaining and cannot be back-filled because the audit table is append-only.
  IntegrityCheckResult verifyChain({
    required String companyId,
    required List<AuditLogEntity> logs,
  }) {
    final List<AuditLogEntity> chained = logs
        .where((AuditLogEntity log) => log.isChained)
        .toList(growable: false);
    final List<int> chainedPositions = <int>[
      for (int index = 0; index < logs.length; index++)
        if (logs[index].isChained) index + 1,
    ];

    final List<int> tampered = <int>[];
    String expectedPrevious = genesisHash;
    for (int index = 0; index < chained.length; index++) {
      final AuditLogEntity log = chained[index];
      final String? previous = log.previousHash?.trim();
      final String? current = log.currentHash?.trim();

      final bool previousValid =
          previous != null && previous.isNotEmpty && previous == expectedPrevious;
      final String recomputed = computeHash(
        previousHash: previous ?? genesisHash,
        timestamp: log.timestamp,
        userId: log.userId,
        action: log.action.name,
        targetEntityId: log.entityId ?? '',
        deltas: log.fieldDeltas(),
      );
      final bool currentValid =
          current != null && current.isNotEmpty && current == recomputed;

      if (!previousValid || !currentValid) {
        tampered.add(chainedPositions[index]);
      }
      // The chain continues from the *stored* hash so a tampered row also
      // propagates the failure forward (like a broken blockchain link).
      expectedPrevious = current ?? genesisHash;
    }

    return IntegrityCheckResult(
      companyId: companyId,
      totalRecords: logs.length,
      hashedRecords: chained.length,
      legacyRecords: logs.length - chained.length,
      isValid: tampered.isEmpty,
      tamperedIndexes: tampered,
      firstTamperIndex: tampered.isEmpty ? null : tampered.first,
    );
  }
}
