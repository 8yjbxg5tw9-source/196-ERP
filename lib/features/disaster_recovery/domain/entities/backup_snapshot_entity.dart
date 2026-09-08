import 'package:equatable/equatable.dart';

/// How a backup snapshot was created.
enum BackupType { manual, scheduledAuto, preUpdate }

extension BackupTypeLabel on BackupType {
  String get label => switch (this) {
        BackupType.manual => 'Manual',
        BackupType.scheduledAuto => 'Auto',
        BackupType.preUpdate => 'Pre-update',
      };
}

/// A single encrypted, point-in-time backup snapshot discovered on disk.
class BackupSnapshotEntity extends Equatable {
  const BackupSnapshotEntity({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.checksumSha256,
    required this.backupType,
    required this.isEncrypted,
    required this.isVerified,
  });

  final String id;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final DateTime createdAt;

  /// SHA-256 of the encrypted archive file.
  final String checksumSha256;

  final BackupType backupType;
  final bool isEncrypted;
  final bool isVerified;

  BackupSnapshotEntity copyWith({bool? isVerified}) {
    return BackupSnapshotEntity(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
      checksumSha256: checksumSha256,
      backupType: backupType,
      isEncrypted: isEncrypted,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        fileName,
        filePath,
        fileSizeBytes,
        createdAt,
        checksumSha256,
        backupType,
        isEncrypted,
        isVerified,
      ];
}
