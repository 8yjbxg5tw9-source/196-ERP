import 'dart:convert';

import '../../domain/entities/user_entity.dart';

/// SQLite representation of a [UserEntity] with the password material that
/// belongs to the data layer only.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    required super.fullName,
    required super.role,
    required super.createdAt,
    required this.salt,
    required this.passwordHash,
    super.companyIds = const <String>[],
  });

  final String salt;
  final String passwordHash;

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: _string(map['id']),
      username: _string(map['username']),
      email: _string(map['email']),
      fullName: _string(map['full_name']),
      role: _roleFromValue(map['role']),
      createdAt: _dateTime(_string(map['created_at'])),
      salt: _string(map['salt']),
      passwordHash: _string(map['password_hash']),
      companyIds: _companyIds(map['company_ids']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'password_hash': passwordHash,
      'salt': salt,
      'role': role.name,
      'company_ids': jsonEncode(companyIds),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String _string(Object? value) {
    return value?.toString() ?? '';
  }

  static DateTime _dateTime(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static UserRole _roleFromValue(Object? value) {
    final String name = value?.toString() ?? '';
    for (final UserRole role in UserRole.values) {
      if (role.name == name) {
        return role;
      }
    }
    return UserRole.clientViewer;
  }

  static List<String> _companyIds(Object? value) {
    if (value is String) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((Object? entry) => entry?.toString() ?? '')
              .where((String entry) => entry.isNotEmpty)
              .toList(growable: false);
        }
      } on FormatException {
        return const <String>[];
      }
    }
    return const <String>[];
  }
}
