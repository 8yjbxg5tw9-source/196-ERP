import 'dart:convert';

import '../../domain/entities/company_group_entity.dart';

/// SQLite mapping for the `company_groups` table.
class CompanyGroupModel extends CompanyGroupEntity {
  const CompanyGroupModel({
    required super.id,
    required super.groupName,
    required super.parentCompanyId,
    super.subsidiaryCompanyIds = const <String>[],
    super.createdAt,
  });

  factory CompanyGroupModel.fromMap(Map<String, Object?> map) {
    return CompanyGroupModel(
      id: map['id']?.toString() ?? '',
      groupName: map['group_name']?.toString() ?? '',
      parentCompanyId: map['parent_company_id']?.toString() ?? '',
      subsidiaryCompanyIds: _decodeIds(map['subsidiary_company_ids']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'group_name': groupName,
      'parent_company_id': parentCompanyId,
      'subsidiary_company_ids': jsonEncode(subsidiaryCompanyIds),
      'created_at': createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  static List<String> _decodeIds(Object? value) {
    if (value is List) {
      return value.map((Object? e) => e.toString()).toList(growable: false);
    }
    try {
      final dynamic decoded = jsonDecode(value?.toString() ?? '[]');
      if (decoded is List) {
        return decoded
            .map((Object? e) => e.toString())
            .toList(growable: false);
      }
    } on FormatException {
      // Fall through to the empty default.
    }
    return const <String>[];
  }
}
