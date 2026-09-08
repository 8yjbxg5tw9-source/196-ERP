import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/tables.dart';
import '../models/user_model.dart';

/// SQLite boundary for local user accounts.
abstract interface class AuthLocalDataSource {
  Future<UserModel?> findUserByUsername(String username);

  Future<UserModel?> findUserById(String id);

  Future<List<UserModel>> getUsers();

  Future<void> insertUser(UserModel user);

  Future<void> updateUser(UserModel user);

  Future<int> countUsers();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<UserModel?> findUserByUsername(String username) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.users,
      where: 'username = ?',
      whereArgs: <Object?>[username.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel?> findUserById(String id) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.users,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<List<UserModel>> getUsers() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      DatabaseTables.users,
      orderBy: 'created_at ASC',
    );
    final List<UserModel> users =
        rows.map(UserModel.fromMap).toList(growable: false);
    users.sort(
      (UserModel left, UserModel right) =>
          left.role.index.compareTo(right.role.index),
    );
    return users;
  }

  @override
  Future<void> insertUser(UserModel user) async {
    final Database database = await _databaseService.database;
    await database.insert(
      DatabaseTables.users,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateUser(UserModel user) async {
    final Database database = await _databaseService.database;
    await database.update(
      DatabaseTables.users,
      user.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[user.id],
    );
  }

  @override
  Future<int> countUsers() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseTables.users}',
    );
    final Object? total = rows.isEmpty ? null : rows.first['total'];
    return total is int ? total : (int.tryParse(total?.toString() ?? '') ?? 0);
  }
}
