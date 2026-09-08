import 'package:equatable/equatable.dart';

/// Outcome of a cryptographic audit-chain verification run.
class IntegrityCheckResult extends Equatable {
  const IntegrityCheckResult({
    required this.companyId,
    required this.totalRecords,
    required this.hashedRecords,
    required this.legacyRecords,
    required this.isValid,
    required this.tamperedIndexes,
    this.firstTamperIndex,
  });

  final String companyId;

  /// Total audit rows examined (ascending chronological order).
  final int totalRecords;

  /// Rows that participate in the SHA-256 hash chain.
  final int hashedRecords;

  /// Rows written before hash chaining existed (skipped by the verifier).
  final int legacyRecords;

  /// True when every chained row's [previousHash] and [currentHash] match.
  final bool isValid;

  /// 1-based row positions (chronological order) that failed verification.
  final List<int> tamperedIndexes;

  /// The first (earliest) tampered row position, if any.
  final int? firstTamperIndex;

  String get message => isValid
      ? 'All $hashedRecords chained records are cryptographically intact.'
      : 'Database tampering detected at '
          '${tamperedIndexes.length == 1 ? 'row' : 'rows'} '
          '${tamperedIndexes.join(', ')}.';

  @override
  List<Object?> get props => <Object?>[
        companyId,
        totalRecords,
        hashedRecords,
        legacyRecords,
        isValid,
        tamperedIndexes,
        firstTamperIndex,
      ];
}
