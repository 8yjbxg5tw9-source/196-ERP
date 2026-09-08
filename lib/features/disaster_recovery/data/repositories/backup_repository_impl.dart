import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../domain/entities/backup_config_entity.dart';
import '../../domain/entities/backup_snapshot_entity.dart';
import '../../domain/repositories/backup_repository.dart';

/// Wraps the encrypted [BackupService] engine and the [AutoBackupService]
/// scheduler behind the disaster-recovery domain boundary.
class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required BackupService backupService,
    required AutoBackupService autoBackupService,
    required SharedPreferences preferences,
  })  : _backupService = backupService,
        _autoBackupService = autoBackupService,
        _preferences = preferences;

  static const String _enabledKey = 'dr.backup_enabled';
  static const String _retentionKey = 'dr.retention_count';
  static const String _targetDirKey = 'dr.target_directory';

  final BackupService _backupService;
  final AutoBackupService _autoBackupService;
  final SharedPreferences _preferences;

  @override
  Future<Either<Failure, BackupSnapshotEntity>> createBackup(
    String companyId, {
    BackupType type = BackupType.manual,
    String? customPath,
  }) async {
    try {
      final File file = await _backupService.createBackup(companyId);
      if (customPath != null && customPath.trim().isNotEmpty) {
        final File target = File(customPath.trim());
        await target.parent.create(recursive: true);
        await file.copy(target.path);
        return Right<Failure, BackupSnapshotEntity>(
          _toSnapshot(target, type),
        );
      }
      return Right<Failure, BackupSnapshotEntity>(_toSnapshot(file, type));
    } on Object catch (error) {
      return Left<Failure, BackupSnapshotEntity>(
        CacheFailure(message: 'The backup could not be created: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> restoreBackup(String filePath) async {
    try {
      await _backupService.restoreBackup(File(filePath));
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'The backup could not be restored: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, List<BackupSnapshotEntity>>> listSnapshots() async {
    try {
      final List<BackupArchiveInfo> archives = await _backupService.listBackups();
      final List<BackupSnapshotEntity> snapshots = <BackupSnapshotEntity>[];
      for (final BackupArchiveInfo archive in archives) {
        snapshots.add(_toSnapshot(File(archive.path), BackupType.manual));
      }
      return Right<Failure, List<BackupSnapshotEntity>>(snapshots);
    } on Object catch (error) {
      return Left<Failure, List<BackupSnapshotEntity>>(
        CacheFailure(message: 'The backup history could not be loaded: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> verifySnapshot(String filePath) async {
    try {
      final bool valid = await _backupService.verifyBackup(File(filePath));
      return Right<Failure, bool>(valid);
    } on Object catch (error) {
      return Left<Failure, bool>(
        CacheFailure(message: 'The snapshot could not be verified: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteSnapshot(String fileName) async {
    try {
      await _backupService.deleteBackup(fileName);
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'The snapshot could not be deleted: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, BackupConfigEntity>> getConfig() async {
    try {
      final BackupFrequency frequency = _autoBackupService.frequency;
      return Right<Failure, BackupConfigEntity>(
        BackupConfigEntity(
          autoBackupEnabled:
              _preferences.getBool(_enabledKey) ?? frequency != BackupFrequency.onAppExit,
          schedule: _scheduleOf(frequency),
          retentionCount: _preferences.getInt(_retentionKey) ?? 10,
          backupTargetDirectory:
              _preferences.getString(_targetDirKey) ?? '',
        ),
      );
    } on Object catch (error) {
      return Left<Failure, BackupConfigEntity>(
        CacheFailure(message: 'The backup configuration could not be read: $error'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateConfig(BackupConfigEntity config) async {
    try {
      await _preferences.setBool(_enabledKey, config.autoBackupEnabled);
      await _preferences.setInt(_retentionKey, config.retentionCount);
      await _preferences.setString(
        _targetDirKey,
        config.backupTargetDirectory,
      );
      await _autoBackupService.setFrequency(_frequencyOf(config.schedule));
      return const Right<Failure, void>(null);
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(message: 'The backup configuration could not be saved: $error'),
      );
    }
  }

  Future<BackupSnapshotEntity> _toSnapshot(File file, BackupType type) async {
    final List<int> bytes = await file.readAsBytes();
    final Digest digest = sha256.convert(bytes);
    return BackupSnapshotEntity(
      id: 'snapshot-${file.path}',
      fileName: file.uri.pathSegments.isEmpty
          ? 'backup'
          : file.uri.pathSegments.last,
      filePath: file.path,
      fileSizeBytes: await file.length(),
      createdAt: await _modifiedAt(file),
      checksumSha256: digest.toString(),
      backupType: type,
      isEncrypted: true,
      isVerified: false,
    );
  }

  static Future<DateTime> _modifiedAt(File file) async {
    try {
      final FileStat stat = await file.stat();
      return stat.modified;
    } on Object {
      return DateTime.now();
    }
  }

  static BackupSchedule _scheduleOf(BackupFrequency frequency) {
    return switch (frequency) {
      BackupFrequency.daily => BackupSchedule.daily,
      BackupFrequency.weekly => BackupSchedule.weekly,
      BackupFrequency.onAppExit => BackupSchedule.onAppExit,
    };
  }

  static BackupFrequency _frequencyOf(BackupSchedule schedule) {
    return switch (schedule) {
      BackupSchedule.daily => BackupFrequency.daily,
      BackupSchedule.weekly => BackupFrequency.weekly,
      BackupSchedule.monthly => BackupFrequency.weekly,
      BackupSchedule.onAppExit => BackupFrequency.onAppExit,
    };
  }
}
