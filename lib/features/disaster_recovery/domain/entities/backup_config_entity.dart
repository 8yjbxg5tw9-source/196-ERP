import 'package:equatable/equatable.dart';

/// Automated backup cadence.
enum BackupSchedule { daily, weekly, monthly, onAppExit }

extension BackupScheduleLabel on BackupSchedule {
  String get label => switch (this) {
        BackupSchedule.daily => 'Daily',
        BackupSchedule.weekly => 'Weekly',
        BackupSchedule.monthly => 'Monthly',
        BackupSchedule.onAppExit => 'On app exit',
      };
}

/// User-configurable disaster-recovery policy.
class BackupConfigEntity extends Equatable {
  const BackupConfigEntity({
    this.autoBackupEnabled = true,
    this.schedule = BackupSchedule.weekly,
    this.retentionCount = 10,
    this.backupTargetDirectory = '',
  });

  final bool autoBackupEnabled;
  final BackupSchedule schedule;
  final int retentionCount;
  final String backupTargetDirectory;

  BackupConfigEntity copyWith({
    bool? autoBackupEnabled,
    BackupSchedule? schedule,
    int? retentionCount,
    String? backupTargetDirectory,
  }) {
    return BackupConfigEntity(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      schedule: schedule ?? this.schedule,
      retentionCount: retentionCount ?? this.retentionCount,
      backupTargetDirectory:
          backupTargetDirectory ?? this.backupTargetDirectory,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        autoBackupEnabled,
        schedule,
        retentionCount,
        backupTargetDirectory,
      ];
}
