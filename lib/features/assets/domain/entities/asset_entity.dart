import 'package:equatable/equatable.dart';

/// Fixed asset classification used by the normative tax rate table.
enum AssetCategory { buildings, machinery, vehicles, computers, intangible }

extension AssetCategoryLabel on AssetCategory {
  String get label => switch (this) {
        AssetCategory.buildings => 'Buildings',
        AssetCategory.machinery => 'Machinery & Equipment',
        AssetCategory.vehicles => 'Transport Vehicles',
        AssetCategory.computers => 'Computers & Software',
        AssetCategory.intangible => 'Intangible',
      };
}

/// Depreciation basis applied to the asset register.
enum DepreciationMethod { straightLine, decliningBalance, taxNormative }

extension DepreciationMethodLabel on DepreciationMethod {
  String get label => switch (this) {
        DepreciationMethod.straightLine => 'Straight-line',
        DepreciationMethod.decliningBalance => 'Declining balance',
        DepreciationMethod.taxNormative => 'Tax normative',
      };
}

/// Lifecycle state of a fixed asset.
enum AssetStatus { active, fullyDepreciated, disposed }

extension AssetStatusLabel on AssetStatus {
  String get label => switch (this) {
        AssetStatus.active => 'Active',
        AssetStatus.fullyDepreciated => 'Fully depreciated',
        AssetStatus.disposed => 'Disposed',
      };
}

/// A fixed asset master record (Əsas Vəsaitlər). [bookValue] is the carrying
/// amount after accumulated depreciation and is maintained by the engine.
class AssetEntity extends Equatable {
  const AssetEntity({
    required this.id,
    required this.companyId,
    required this.assetCode,
    required this.name,
    required this.category,
    required this.purchaseDate,
    required this.purchasePrice,
    this.salvageValue = 0,
    required this.usefulLifeMonths,
    required this.depreciationMethod,
    this.accumulatedDepreciation = 0,
    required this.bookValue,
    this.status = AssetStatus.active,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String assetCode;
  final String name;
  final AssetCategory category;
  final DateTime purchaseDate;
  final double purchasePrice;
  final double salvageValue;
  final int usefulLifeMonths;
  final DepreciationMethod depreciationMethod;
  final double accumulatedDepreciation;
  final double bookValue;
  final AssetStatus status;
  final DateTime? createdAt;

  double get depreciableBase => purchasePrice - salvageValue;

  AssetEntity copyWith({
    String? id,
    String? companyId,
    String? assetCode,
    String? name,
    AssetCategory? category,
    DateTime? purchaseDate,
    double? purchasePrice,
    double? salvageValue,
    int? usefulLifeMonths,
    DepreciationMethod? depreciationMethod,
    double? accumulatedDepreciation,
    double? bookValue,
    AssetStatus? status,
    DateTime? createdAt,
  }) {
    return AssetEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      assetCode: assetCode ?? this.assetCode,
      name: name ?? this.name,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salvageValue: salvageValue ?? this.salvageValue,
      usefulLifeMonths: usefulLifeMonths ?? this.usefulLifeMonths,
      depreciationMethod: depreciationMethod ?? this.depreciationMethod,
      accumulatedDepreciation:
          accumulatedDepreciation ?? this.accumulatedDepreciation,
      bookValue: bookValue ?? this.bookValue,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        assetCode,
        name,
        category,
        purchaseDate,
        purchasePrice,
        salvageValue,
        usefulLifeMonths,
        depreciationMethod,
        accumulatedDepreciation,
        bookValue,
        status,
        createdAt,
      ];
}
