import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/depreciation_schedule_entity.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/services/asset_depreciation_engine.dart';
import '../datasources/asset_local_data_source.dart';
import '../models/asset_model.dart';
import '../models/depreciation_schedule_model.dart';

/// Fixed asset register implementation: persists assets, runs the monthly
/// depreciation engine, and posts expense / accumulated-depreciation journals.
class AssetRepositoryImpl implements AssetRepository {
  AssetRepositoryImpl(
    this._localDataSource, {
    AssetDepreciationEngine engine = const AssetDepreciationEngine(),
  }) : _engine = engine;

  final AssetLocalDataSource _localDataSource;
  final AssetDepreciationEngine _engine;

  @override
  Future<Either<Failure, List<AssetEntity>>> getAssets(String companyId) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<AssetEntity>>(
        const ValidationFailure(message: 'Select a company before loading.'),
      );
    }

    try {
      final List<AssetModel> assets =
          await _localDataSource.getAssets(normalizedCompanyId);
      return Right<Failure, List<AssetEntity>>(assets);
    } on DatabaseException catch (error) {
      return Left<Failure, List<AssetEntity>>(
        DatabaseFailure(
          message: 'Fixed assets could not be loaded from SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<AssetEntity>>(
        CacheFailure(
          message: 'Fixed assets could not be read.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, AssetEntity>> createAsset(AssetEntity asset) async {
    final String normalizedCompanyId = asset.companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, AssetEntity>(
        const ValidationFailure(message: 'Select a company before adding.'),
      );
    }
    if (asset.purchasePrice < 0 || asset.salvageValue < 0) {
      return Left<Failure, AssetEntity>(
        const ValidationFailure(message: 'Asset values cannot be negative.'),
      );
    }
    if (asset.usefulLifeMonths <= 0) {
      return Left<Failure, AssetEntity>(
        const ValidationFailure(
          message: 'Useful life must be at least one month.',
        ),
      );
    }
    if (asset.salvageValue > asset.purchasePrice) {
      return Left<Failure, AssetEntity>(
        const ValidationFailure(
          message: 'Salvage value cannot exceed the purchase price.',
        ),
      );
    }

    try {
      final double initialBookValue = asset.bookValue > 0
          ? asset.bookValue
          : asset.purchasePrice;
      final AssetEntity normalized = asset.copyWith(bookValue: initialBookValue);
      await _localDataSource.createAsset(AssetModel.fromEntity(normalized));
      return Right<Failure, AssetEntity>(normalized);
    } on DatabaseException catch (error) {
      return Left<Failure, AssetEntity>(
        DatabaseFailure(
          message: 'The fixed asset could not be saved to SQLite.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, AssetEntity>(
        CacheFailure(
          message: 'The fixed asset could not be saved.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<DepreciationScheduleEntity>>>
      runMonthlyDepreciation({
    required String companyId,
    required DateTime periodDate,
  }) async {
    final String normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        const ValidationFailure(message: 'Select a company before running.'),
      );
    }

    try {
      final List<AssetModel> assets =
          await _localDataSource.getAssets(normalizedCompanyId);
      final List<DepreciationScheduleEntity> schedules =
          <DepreciationScheduleEntity>[];
      for (final AssetModel asset in assets) {
        if (asset.status != AssetStatus.active) {
          continue;
        }
        final DepreciationResult result = _engine.depreciate(asset);
        final AssetEntity updated = asset.copyWith(
          accumulatedDepreciation: result.accumulatedDepreciation,
          bookValue: result.endingBookValue,
          status: result.isFullyDepreciated
              ? AssetStatus.fullyDepreciated
              : AssetStatus.active,
        );
        final DepreciationScheduleModel schedule = DepreciationScheduleModel(
          id: 'dep-${DateTime.now().toUtc().microsecondsSinceEpoch}-${asset.id}',
          assetId: asset.id,
          companyId: normalizedCompanyId,
          periodDate: periodDate,
          depreciationAmount: result.depreciationAmount,
          accumulatedAmount: result.accumulatedDepreciation,
          endingBookValue: result.endingBookValue,
          isPosted: result.depreciationAmount > 0,
        );
        await _localDataSource.updateAsset(AssetModel.fromEntity(updated));
        await _localDataSource.insertSchedule(schedule);
        if (result.depreciationAmount > 0) {
          await _localDataSource.writeJournalEntry(
            AssetJournalEntry(
              companyId: normalizedCompanyId,
              entryDate: periodDate,
              description:
                  'Monthly depreciation for ${asset.name} (${asset.assetCode})',
              debitAccount: AssetDepreciationEngine.depreciationExpenseAccount,
              creditAccount:
                  AssetDepreciationEngine.accumulatedDepreciationAccount,
              amount: result.depreciationAmount,
              sourceType: 'depreciation',
              sourceId: schedule.id,
            ),
          );
        }
        schedules.add(schedule);
      }
      return Right<Failure, List<DepreciationScheduleEntity>>(schedules);
    } on DatabaseException catch (error) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        DatabaseFailure(
          message: 'The monthly depreciation run could not be saved.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        CacheFailure(
          message: 'The monthly depreciation run could not be completed.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, AssetEntity>> disposeAsset(String assetId) async {
    final String normalizedAssetId = assetId.trim();
    if (normalizedAssetId.isEmpty) {
      return Left<Failure, AssetEntity>(
        const ValidationFailure(message: 'An asset is required to dispose.'),
      );
    }

    try {
      final AssetModel? asset = await _localDataSource.getAsset(
        normalizedAssetId,
      );
      if (asset == null) {
        return Left<Failure, AssetEntity>(
          NotFoundFailure(
            message: 'Asset $normalizedAssetId was not found.',
          ),
        );
      }
      final AssetEntity disposed = asset.copyWith(
        status: AssetStatus.disposed,
        bookValue: 0,
      );
      await _localDataSource.updateAsset(AssetModel.fromEntity(disposed));
      return Right<Failure, AssetEntity>(disposed);
    } on DatabaseException catch (error) {
      return Left<Failure, AssetEntity>(
        DatabaseFailure(
          message: 'The asset could not be disposed.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, AssetEntity>(
        CacheFailure(
          message: 'The asset could not be disposed locally.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<DepreciationScheduleEntity>>> getSchedules(
    String assetId,
  ) async {
    final String normalizedAssetId = assetId.trim();
    if (normalizedAssetId.isEmpty) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        const ValidationFailure(message: 'An asset is required.'),
      );
    }

    try {
      final List<DepreciationScheduleModel> schedules =
          await _localDataSource.getSchedules(normalizedAssetId);
      return Right<Failure, List<DepreciationScheduleEntity>>(schedules);
    } on DatabaseException catch (error) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        DatabaseFailure(
          message: 'Depreciation schedules could not be loaded.',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Left<Failure, List<DepreciationScheduleEntity>>(
        CacheFailure(
          message: 'Depreciation schedules could not be read.',
          cause: error,
        ),
      );
    }
  }
}
