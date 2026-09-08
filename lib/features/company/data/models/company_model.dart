import '../../domain/entities/company_entity.dart';

/// SQLite/API representation of a [CompanyEntity].
class CompanyModel extends CompanyEntity {
  const CompanyModel({
    required super.id,
    required super.name,
    required super.voenTin,
    required super.taxType,
    required super.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      voenTin: _readString(json, <String>['voenTin', 'voen_tin']),
      taxType: _readString(
        json,
        <String>['taxType', 'tax_type'],
        fallback: 'VAT',
      ),
      createdAt: _readDateTime(json, <String>['createdAt', 'created_at']),
    );
  }

  factory CompanyModel.fromSqflite(Map<String, Object?> row) {
    return CompanyModel(
      id: _requiredRowString(row, 'id'),
      name: _requiredRowString(row, 'name'),
      voenTin: _requiredRowString(row, 'voen_tin'),
      taxType: _rowString(row, 'tax_type', fallback: 'VAT'),
      createdAt: _readRowDateTime(row, 'created_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'voen_tin': voenTin,
      'tax_type': taxType,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toSqflite() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'voen_tin': voenTin,
      'tax_type': taxType,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String _requiredString(
    Map<String, dynamic> values,
    String key,
  ) {
    final Object? value = values[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Company JSON field "$key" is required.');
  }

  static String _readString(
    Map<String, dynamic> values,
    List<String> keys, {
    String? fallback,
  }) {
    for (final String key in keys) {
      final Object? value = values[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    if (fallback != null) {
      return fallback;
    }
    throw FormatException(
      'Company JSON field "${keys.join(' / ')}" is required.',
    );
  }

  static DateTime _readDateTime(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final Object? value = values[key];
      if (value is DateTime) {
        return value;
      }
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.parse(value);
      }
    }
    throw FormatException(
      'Company JSON field "${keys.join(' / ')}" is required.',
    );
  }

  static String _requiredRowString(
    Map<String, Object?> row,
    String key,
  ) {
    final Object? value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Company SQLite field "$key" is required.');
  }

  static String _rowString(
    Map<String, Object?> row,
    String key, {
    required String fallback,
  }) {
    final Object? value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return fallback;
  }

  static DateTime _readRowDateTime(
    Map<String, Object?> row,
    String key,
  ) {
    final Object? value = row[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value);
    }
    throw FormatException('Company SQLite field "$key" is required.');
  }
}
