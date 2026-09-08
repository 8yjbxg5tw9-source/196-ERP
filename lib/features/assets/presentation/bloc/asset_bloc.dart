import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/depreciation_schedule_entity.dart';
import '../../domain/repositories/asset_repository.dart';
import 'asset_event.dart';
import 'asset_state.dart';

/// Coordinates the fixed asset register: loading, creation, the monthly
/// depreciation run, disposal, and schedule retrieval.
class AssetBloc extends Bloc<AssetEvent, AssetState> {
  AssetBloc({required AssetRepository repository})
      : _repository = repository,
        super(const AssetInitial()) {
    on<LoadAssetsEvent>(_onLoadAssets);
    on<CreateAssetEvent>(_onCreateAsset);
    on<RunMonthlyDepreciationEvent>(_onRunMonthlyDepreciation);
    on<DisposeAssetEvent>(_onDisposeAsset);
    on<LoadAssetSchedulesEvent>(_onLoadSchedules);
  }

  final AssetRepository _repository;

  Future<void> _onLoadAssets(
    LoadAssetsEvent event,
    Emitter<AssetState> emit,
  ) async {
    emit(const AssetLoading());
    final result = await _repository.getAssets(event.companyId);
    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (assets) => emit(AssetsLoaded(assets: assets)),
    );
  }

  Future<void> _onCreateAsset(
    CreateAssetEvent event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.createAsset(event.asset);
    await result.fold(
      (failure) async => emit(AssetError(failure.message)),
      (asset) async {
        final assetsResult = await _repository.getAssets(asset.companyId);
        assetsResult.fold(
          (failure) => emit(AssetError(failure.message)),
          (assets) => emit(
            AssetOperationSuccess(
              message: 'Asset "${asset.name}" registered.',
              assets: assets,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRunMonthlyDepreciation(
    RunMonthlyDepreciationEvent event,
    Emitter<AssetState> emit,
  ) async {
    emit(const AssetLoading());
    final result = await _repository.runMonthlyDepreciation(
      companyId: event.companyId,
      periodDate: event.periodDate,
    );
    await result.fold(
      (failure) async => emit(AssetError(failure.message)),
      (schedules) async {
        final assetsResult = await _repository.getAssets(event.companyId);
        assetsResult.fold(
          (failure) => emit(AssetError(failure.message)),
          (assets) => emit(
            AssetOperationSuccess(
              message: 'Depreciation run posted ${schedules.length} '
                  'schedule line(s).',
              assets: assets,
              schedules: schedules,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDisposeAsset(
    DisposeAssetEvent event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.disposeAsset(event.assetId);
    await result.fold(
      (failure) async => emit(AssetError(failure.message)),
      (asset) async {
        final assetsResult = await _repository.getAssets(asset.companyId);
        assetsResult.fold(
          (failure) => emit(AssetError(failure.message)),
          (assets) => emit(
            AssetOperationSuccess(
              message: 'Asset "${asset.name}" disposed.',
              assets: assets,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onLoadSchedules(
    LoadAssetSchedulesEvent event,
    Emitter<AssetState> emit,
  ) async {
    final result = await _repository.getSchedules(event.assetId);
    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (schedules) => emit(
        AssetSchedulesLoaded(assetId: event.assetId, schedules: schedules),
      ),
    );
  }
}
