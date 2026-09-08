import 'package:equatable/equatable.dart';

import '../../domain/entities/backup_config_entity.dart';
import '../../domain/entities/backup_snapshot_entity.dart';

abstract class BackupState extends Equatable {
  const BackupState();

  @override
  List<Object?> get props => const <Object?>[];
}

class BackupInitial extends BackupState {
  const BackupInitial();
}

class BackupLoading extends BackupState {
  const BackupLoading();
}

class BackupHistoryLoaded extends BackupState {
  const BackupHistoryLoaded({
    required this.snapshots,
    required this.config,
    this.message,
  });

  final List<BackupSnapshotEntity> snapshots;
  final BackupConfigEntity config;

  /// Transient banner (e.g. a verification result or an export path).
  final String? message;

  BackupHistoryLoaded copyWith({
    List<BackupSnapshotEntity>? snapshots,
    BackupConfigEntity? config,
    String? message,
  }) {
    return BackupHistoryLoaded(
      snapshots: snapshots ?? this.snapshots,
      config: config ?? this.config,
      message: message,
    );
  }

  @override
  List<Object?> get props => <Object?>[snapshots, config, message];
}

class BackupCreationSuccess extends BackupState {
  const BackupCreationSuccess(this.snapshot);

  final BackupSnapshotEntity snapshot;

  @override
  List<Object?> get props => <Object?>[snapshot];
}

class RestoreSuccess extends BackupState {
  const RestoreSuccess();
}

class BackupError extends BackupState {
  const BackupError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
