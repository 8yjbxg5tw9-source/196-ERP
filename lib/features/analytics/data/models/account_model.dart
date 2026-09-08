import '../../domain/entities/chart_of_accounts.dart';

/// SQLite representation of a chart-of-accounts node.
class AccountModel extends AccountEntity {
  const AccountModel({
    required super.id,
    required super.companyId,
    required super.code,
    required super.name,
    required super.type,
    super.parentCode,
  });

  factory AccountModel.fromEntity(AccountEntity entity) {
    return AccountModel(
      id: entity.id,
      companyId: entity.companyId,
      code: entity.code,
      name: entity.name,
      type: entity.type,
      parentCode: entity.parentCode,
    );
  }

  factory AccountModel.fromMap(Map<String, Object?> map) {
    return AccountModel(
      id: _stringValue(map['id']),
      companyId: _stringValue(map['company_id']),
      code: _stringValue(map['code']),
      name: _stringValue(map['name']),
      type: _typeFromValue(map['type']),
      parentCode: _nullableString(map['parent_code']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'code': code,
      'name': name,
      'type': type.name,
      'parent_code': parentCode,
    };
  }

  static String _stringValue(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _nullableString(Object? value) {
    final String text = _stringValue(value).trim();
    return text.isEmpty ? null : text;
  }

  static AccountType _typeFromValue(Object? value) {
    final String name = value?.toString() ?? '';
    for (final AccountType type in AccountType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return AccountType.expense;
  }
}
