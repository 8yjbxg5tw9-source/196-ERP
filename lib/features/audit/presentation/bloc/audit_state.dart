import 'package:equatable/equatable.dart';

import '../../domain/entities/audit_log_entity.dart';
import '../../domain/entities/integrity_check_result.dart';

abstract class AuditState extends Equatable {
  const AuditState();

  @override
  List<Object?> get props => const <Object?>[];
}

class AuditInitial extends AuditState {
  const AuditInitial();
}

class AuditLoading extends AuditState {
  const AuditLoading();
}

class AuditLoaded extends AuditState {
  const AuditLoaded(this.logs, {this.message});

  final List<AuditLogEntity> logs;

  /// Transient informational banner (e.g. a completed export path).
  final String? message;

  @override
  List<Object?> get props => <Object?>[logs, message];
}

class AuditError extends AuditState {
  const AuditError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The result of a cryptographic chain-integrity verification run.
class IntegrityCheckComplete extends AuditState {
  const IntegrityCheckComplete(this.result);

  final IntegrityCheckResult result;

  @override
  List<Object?> get props => <Object?>[result];
}
