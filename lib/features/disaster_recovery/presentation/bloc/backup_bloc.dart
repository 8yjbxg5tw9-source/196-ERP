import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/backup_config_entity.dart';
import '../../domain/entities/backup_snapshot_entity.dart';
import '../../domain/repositories/backup_repository.dart';
import 'backup_event.dart';
import 'backup_state.dart';

/// Coordinates snapshot creation, restore, history, verification, and the
/// automated-backup configuration policy.
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  BackupBloc({required BackupRepository repository})
      : _repository = repository,
        super(const BackupInitial()) {
    on<LoadBackupHistoryEvent>(_onLoad);
    on<CreateBackupEvent>(_onCreate);
    on<RestoreBackupEvent>(_onRestore);
    on<VerifySnapshotEvent>(_onVerify);
    on<DeleteSnapshotEvent>(_onDelete);
    on<UpdateBackupConfigEvent>(_onUpdateConfig);
  }

  final BackupRepository _repository;

  Future<void> _onLoad(
    LoadBackupHistoryEvent event,
    Emitter<BackupState> emit,
  ) async {
    emit(const BackupLoading());
    final Either<Failure, List<BackupSnapshotEntity>> snapshotsResult =
        await _repository.listSnapshots();
    final Either<Failure, BackupConfigEntity> configResult =
        await _repository.getConfig();

    if (snapshotsResult.isLeft()) {
      final Failure failure =
          (snapshotsResult as Left<Failure, List<BackupSnapshotEntity>>).value;
      emit(BackupError(failure.message));
      return;
    }
    final List<BackupSnapshotEntity> snapshots =
        (snapshotsResult as Right<Failure, List<BackupSnapshotEntity>>).value;
    final BackupConfigEntity config = configResult.fold(
      (_) => const BackupConfigEntity(),
      (BackupConfigEntity value) => value,
    );
    emit(BackupHistoryLoaded(snapshots: snapshots, config: config));
  }

  Future<void> _onCreate(
    CreateBackupEvent event,
    Emitter<BackupState> emit,
  ) async {
    emit(const BackupLoading());
    final Either<Failure, BackupSnapshotEntity> result =
        await _repository.createBackup(
      event.companyId,
      type: BackupType.manual,
      customPath: event.customPath,
    );
    if (result.isLeft()) {
      final Failure failure =
          (result as Left<Failure, BackupSnapshotEntity>).value;
      emit(BackupError(failure.message));
      return;
    }
    emit(
      BackupCreationSuccess(
        (result as Right<Failure, BackupSnapshotEntity>).value,
      ),
    );
  }

  Future<void> _onRestore(
    RestoreBackupEvent event,
    Emitter<BackupState> emit,
  ) async {
    emit(const BackupLoading());
    final Either<Failure, void> result =
        await _repository.restoreBackup(event.filePath);
    if (result.isLeft()) {
      final Failure failure = (result as Left<Failure, void>).value;
      emit(BackupError(failure.message));
      return;
    }
    emit(const RestoreSuccess());
  }

  Future<void> _onVerify(
    VerifySnapshotEvent event,
    Emitter<BackupState> emit,
  ) async {
    final Either<Failure, bool> result =
        await _repository.verifySnapshot(event.filePath);
    if (result.isLeft()) {
      final Failure failure = (result as Left<Failure, bool>).value;
      emit(BackupError(failure.message));
      return;
    }
    final bool valid = (result as Right<Failure, bool>).value;
    final BackupState current = state;
    if (current is BackupHistoryLoaded) {
      final List<BackupSnapshotEntity> updated = <BackupSnapshotEntity>[
        for (final BackupSnapshotEntity snapshot in current.snapshots)
          snapshot.filePath == event.filePath
              ? snapshot.copyWith(isVerified: valid)
              : snapshot,
      ];
      emit(
        BackupHistoryLoaded(
          snapshots: updated,
          config: current.config,
          message: valid
              ? 'SHA-256 integrity verified.'
              : 'Verification failed — the archive is corrupt.',
        ),
      );
    }
  }

  Future<void> _onDelete(
    DeleteSnapshotEvent event,
    Emitter<BackupState> emit,
  ) async {
    final Either<Failure, void> result =
        await _repository.deleteSnapshot(event.fileName);
    if (result.isLeft()) {
      final Failure failure = (result as Left<Failure, void>).value;
      emit(BackupError(failure.message));
      return;
    }
    await _onLoad(const LoadBackupHistoryEvent(), emit);
  }

  Future<void> _onUpdateConfig(
    UpdateBackupConfigEvent event,
    Emitter<BackupState> emit,
  ) async {
    final Either<Failure, void> result =
        await _repository.updateConfig(event.config);
    if (result.isLeft()) {
      final Failure failure = (result as Left<Failure, void>).value;
      emit(BackupError(failure.message));
      return;
    }
    final BackupState current = state;
    if (current is BackupHistoryLoaded) {
      emit(
        BackupHistoryLoaded(
          snapshots: current.snapshots,
          config: event.config,
          message: 'Backup schedule saved.',
        ),
      );
    }
  }
}
