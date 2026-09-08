import 'package:equatable/equatable.dart';

import '../../domain/entities/backup_config_entity.dart';

abstract class BackupEvent extends Equatable {
  const BackupEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class CreateBackupEvent extends BackupEvent {
  const CreateBackupEvent({
    required this.companyId,
    this.customPath,
  });

  final String companyId;
  final String? customPath;

  @override
  List<Object?> get props => <Object?>[companyId, customPath];
}

class RestoreBackupEvent extends BackupEvent {
  const RestoreBackupEvent(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => <Object?>[filePath];
}

class LoadBackupHistoryEvent extends BackupEvent {
  const LoadBackupHistoryEvent();
}

class VerifySnapshotEvent extends BackupEvent {
  const VerifySnapshotEvent(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => <Object?>[filePath];
}

class DeleteSnapshotEvent extends BackupEvent {
  const DeleteSnapshotEvent(this.fileName);

  final String fileName;

  @override
  List<Object?> get props => <Object?>[fileName];
}

class UpdateBackupConfigEvent extends BackupEvent {
  const UpdateBackupConfigEvent(this.config);

  final BackupConfigEntity config;

  @override
  List<Object?> get props => <Object?>[config];
}
