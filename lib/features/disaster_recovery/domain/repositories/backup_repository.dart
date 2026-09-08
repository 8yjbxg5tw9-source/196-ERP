import '../../../../core/errors/failures.dart';
import '../entities/backup_config_entity.dart';
import '../entities/backup_snapshot_entity.dart';

/// Boundary for encrypted backup, verification, restore, and scheduling.
abstract interface class BackupRepository {
  Future<Result<BackupSnapshotEntity>> createBackup(
    String companyId, {
    BackupType type,
    String? customPath,
  });

  Future<Result<void>> restoreBackup(String filePath);

  Future<Result<List<BackupSnapshotEntity>>> listSnapshots();

  Future<Result<bool>> verifySnapshot(String filePath);

  Future<Result<void>> deleteSnapshot(String fileName);

  Future<Result<BackupConfigEntity>> getConfig();

  Future<Result<void>> updateConfig(BackupConfigEntity config);
}
