import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/audit_log_entity.dart';

abstract class AuditEvent extends Equatable {
  const AuditEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Requests the audit trail for the given company, optionally narrowed by a
/// date range, action type, user, and free-text keyword.
class FetchAuditLogsEvent extends AuditEvent {
  const FetchAuditLogsEvent({
    required this.companyId,
    this.range,
    this.actionFilter,
    this.userId,
    this.search,
  });

  final String companyId;
  final DateTimeRange? range;
  final AuditAction? actionFilter;
  final String? userId;
  final String? search;

  @override
  List<Object?> get props => <Object?>[
        companyId,
        range,
        actionFilter,
        userId,
        search,
      ];
}

/// Exports the currently loaded audit records to a PDF report.
class ExportAuditLogsPdfEvent extends AuditEvent {
  const ExportAuditLogsPdfEvent();
}

/// Runs cryptographic SHA-256 chain verification across the whole audit trail.
class RunIntegrityVerificationEvent extends AuditEvent {
  const RunIntegrityVerificationEvent({required this.companyId});

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}
