import '../../domain/entities/asset_entity.dart';

/// SQLite mapping for the `assets` table.
class AssetModel extends AssetEntity {
  const AssetModel({
    required super.id,
    required super.companyId,
    required super.assetCode,
    required super.name,
    required super.category,
    required super.purchaseDate,
    required super.purchasePrice,
    super.salvageValue = 0,
    required super.usefulLifeMonths,
    required super.depreciationMethod,
    super.accumulatedDepreciation = 0,
    required super.bookValue,
    super.status = AssetStatus.active,
    super.createdAt,
  });

  factory AssetModel.fromMap(Map<String, Object?> map) {
    return AssetModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      assetCode: map['asset_code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: _categoryFromValue(map['category']),
      purchaseDate:
          DateTime.tryParse(map['purchase_date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      purchasePrice: _doubleValue(map['purchase_price']),
      salvageValue: _doubleValue(map['salvage_value']),
      usefulLifeMonths:
          int.tryParse(map['useful_life_months']?.toString() ?? '') ?? 0,
      depreciationMethod: _methodFromValue(map['depreciation_method']),
      accumulatedDepreciation:
          _doubleValue(map['accumulated_depreciation']),
      bookValue: _doubleValue(map['book_value']),
      status: _statusFromValue(map['status']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory AssetModel.fromEntity(AssetEntity entity) {
    return AssetModel(
      id: entity.id,
      companyId: entity.companyId,
      assetCode: entity.assetCode,
      name: entity.name,
      category: entity.category,
      purchaseDate: entity.purchaseDate,
      purchasePrice: entity.purchasePrice,
      salvageValue: entity.salvageValue,
      usefulLifeMonths: entity.usefulLifeMonths,
      depreciationMethod: entity.depreciationMethod,
      accumulatedDepreciation: entity.accumulatedDepreciation,
      bookValue: entity.bookValue,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'asset_code': assetCode,
      'name': name,
      'category': category.name,
      'purchase_date': purchaseDate.toUtc().toIso8601String(),
      'purchase_price': purchasePrice,
      'salvage_value': salvageValue,
      'useful_life_months': usefulLifeMonths,
      'depreciation_method': depreciationMethod.name,
      'accumulated_depreciation': accumulatedDepreciation,
      'book_value': bookValue,
      'status': status.name,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static AssetCategory _categoryFromValue(Object? value) {
    return AssetCategory.values.firstWhere(
      (AssetCategory category) => category.name == value?.toString(),
      orElse: () => AssetCategory.machinery,
    );
  }

  static DepreciationMethod _methodFromValue(Object? value) {
    return DepreciationMethod.values.firstWhere(
      (DepreciationMethod method) => method.name == value?.toString(),
      orElse: () => DepreciationMethod.straightLine,
    );
  }

  static AssetStatus _statusFromValue(Object? value) {
    return AssetStatus.values.firstWhere(
      (AssetStatus status) => status.name == value?.toString(),
      orElse: () => AssetStatus.active,
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
