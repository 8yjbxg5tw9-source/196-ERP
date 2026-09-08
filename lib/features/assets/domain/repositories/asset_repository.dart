import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/asset_entity.dart';
import '../entities/depreciation_schedule_entity.dart';

/// Persistence + depreciation boundary for the fixed asset register.
abstract interface class AssetRepository {
  Future<Either<Failure, List<AssetEntity>>> getAssets(String companyId);

  Future<Either<Failure, AssetEntity>> createAsset(AssetEntity asset);

  /// Runs one period of depreciation across all active assets, updates the
  /// carrying values, appends schedule lines, and posts the expense /
  /// accumulated-depreciation journal entries.
  Future<Either<Failure, List<DepreciationScheduleEntity>>>
      runMonthlyDepreciation({
    required String companyId,
    required DateTime periodDate,
  });

  Future<Either<Failure, AssetEntity>> disposeAsset(String assetId);

  Future<Either<Failure, List<DepreciationScheduleEntity>>> getSchedules(
    String assetId,
  );
}
