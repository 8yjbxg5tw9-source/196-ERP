import '../../domain/entities/warehouse_entity.dart';

/// SQLite mapping for the `warehouses` table.
class WarehouseModel extends WarehouseEntity {
  const WarehouseModel({
    required super.id,
    required super.companyId,
    required super.code,
    required super.name,
    super.location,
    super.isPrimary,
    super.createdAt,
  });

  factory WarehouseModel.fromMap(Map<String, Object?> map) {
    return WarehouseModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      location: _nullable(map['location']),
      isPrimary: _bool(map['is_primary']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'code': code,
      'name': name,
      'location': location,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  static String? _nullable(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _bool(Object? value) =>
      value == 1 || value == true || value?.toString() == 'true';
}
