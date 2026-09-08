import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/audit_log_entity.dart';
import '../../domain/entities/integrity_check_result.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/services/audit_engine.dart';
import '../datasources/audit_local_data_source.dart';

/// SQLite implementation of the append-only audit boundary, adding SHA-256
/// hash chaining and chain-integrity verification on top of the data source.
class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(
    this._localDataSource, {
    AuditEngine engine = const AuditEngine(),
  }) : _engine = engine;

  final AuditLocalDataSource _localDataSource;
  final AuditEngine _engine;

  @override
  Future<Either<Failure, void>> logAction(AuditLogEntity log) async {
    try {
      AuditLogEntity record = log;
      if (!log.isChained) {
        final String? latestHash = await _localDataSource.getLatestHash(
          log.companyId,
        );
        final String previousHash = latestHash ?? AuditEngine.genesisHash;
        final String currentHash = _engine.computeHash(
          previousHash: previousHash,
          timestamp: log.timestamp,
          userId: log.userId,
          action: log.action.name,
          targetEntityId: log.entityId ?? '',
          deltas: log.fieldDeltas(),
        );
        record = log.copyWith(
          previousHash: previousHash,
          currentHash: currentHash,
          systemDeviceInfo: log.systemDeviceInfo ?? _deviceInfo(),
        );
      }
      await _localDataSource.insertLog(record);
      return const Right<Failure, void>(null);
    } on DatabaseException catch (error) {
      return Left<Failure, void>(
        DatabaseFailure(
          message: 'The audit record could not be written to SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, void>(
        CacheFailure(
          message: 'The audit record could not be written locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<AuditLogEntity>>> getLogs({
    required String companyId,
    DateTime? from,
    DateTime? to,
    AuditAction? action,
    String? userId,
    String? search,
  }) async {
    try {
      final List<AuditLogEntity> logs = await _localDataSource.getLogs(
        companyId: companyId,
        from: from,
        to: to,
        action: action,
        userId: userId,
        search: search,
      );
      return Right<Failure, List<AuditLogEntity>>(logs);
    } on DatabaseException catch (error) {
      return Left<Failure, List<AuditLogEntity>>(
        DatabaseFailure(
          message: 'The audit trail could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<AuditLogEntity>>(
        CacheFailure(
          message: 'The audit trail could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, IntegrityCheckResult>> verifyAuditChainIntegrity(
    String companyId,
  ) async {
    try {
      final List<AuditLogEntity> logs =
          await _localDataSource.getAllLogsAscending(companyId);
      return Right<Failure, IntegrityCheckResult>(
        _engine.verifyChain(companyId: companyId, logs: logs),
      );
    } on DatabaseException catch (error) {
      return Left<Failure, IntegrityCheckResult>(
        DatabaseFailure(
          message: 'The audit chain could not be verified.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, IntegrityCheckResult>(
        CacheFailure(
          message: 'The audit chain could not be read locally.',
          cause: error,
        ),
      );
    }
  }

  static String _deviceInfo() {
    if (kIsWeb) {
      return 'web';
    }
    try {
      return '${Platform.operatingSystem} ${Platform.localHostname}';
    } on Object {
      return Platform.operatingSystem;
    }
  }
}
