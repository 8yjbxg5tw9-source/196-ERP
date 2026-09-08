import 'package:equatable/equatable.dart';

import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/depreciation_schedule_entity.dart';

abstract class AssetState extends Equatable {
  const AssetState();

  @override
  List<Object?> get props => const <Object?>[];
}

class AssetInitial extends AssetState {
  const AssetInitial();
}

class AssetLoading extends AssetState {
  const AssetLoading();
}

class AssetsLoaded extends AssetState {
  const AssetsLoaded({required this.assets});

  final List<AssetEntity> assets;

  @override
  List<Object?> get props => <Object?>[assets];
}

class AssetOperationSuccess extends AssetState {
  const AssetOperationSuccess({
    required this.message,
    this.assets = const <AssetEntity>[],
    this.schedules = const <DepreciationScheduleEntity>[],
  });

  final String message;
  final List<AssetEntity> assets;
  final List<DepreciationScheduleEntity> schedules;

  @override
  List<Object?> get props => <Object?>[message, assets, schedules];
}

class AssetSchedulesLoaded extends AssetState {
  const AssetSchedulesLoaded({
    required this.assetId,
    required this.schedules,
  });

  final String assetId;
  final List<DepreciationScheduleEntity> schedules;

  @override
  List<Object?> get props => <Object?>[assetId, schedules];
}

class AssetError extends AssetState {
  const AssetError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
