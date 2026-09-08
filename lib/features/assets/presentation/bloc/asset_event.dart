import 'package:equatable/equatable.dart';

import '../../domain/entities/asset_entity.dart';

abstract class AssetEvent extends Equatable {
  const AssetEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadAssetsEvent extends AssetEvent {
  const LoadAssetsEvent(this.companyId);

  final String companyId;

  @override
  List<Object?> get props => <Object?>[companyId];
}

class CreateAssetEvent extends AssetEvent {
  const CreateAssetEvent(this.asset);

  final AssetEntity asset;

  @override
  List<Object?> get props => <Object?>[asset];
}

class RunMonthlyDepreciationEvent extends AssetEvent {
  const RunMonthlyDepreciationEvent({
    required this.companyId,
    required this.periodDate,
  });

  final String companyId;
  final DateTime periodDate;

  @override
  List<Object?> get props => <Object?>[companyId, periodDate];
}

class DisposeAssetEvent extends AssetEvent {
  const DisposeAssetEvent(this.assetId);

  final String assetId;

  @override
  List<Object?> get props => <Object?>[assetId];
}

class LoadAssetSchedulesEvent extends AssetEvent {
  const LoadAssetSchedulesEvent(this.assetId);

  final String assetId;

  @override
  List<Object?> get props => <Object?>[assetId];
}
