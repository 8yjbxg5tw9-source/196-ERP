import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../audit/domain/entities/audit_log_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/user_model.dart';
import '../password_hasher.dart';
import '../session_token_service.dart';

/// Local authentication implementation: PBKDF2 password verification, signed
/// session tokens, and role/user management backed by SQLite.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource localDataSource,
    required SecureStorageService secureStorage,
    AuditLoggerService? auditLogger,
    PasswordHasher passwordHasher = const PasswordHasher(),
    SessionTokenService? tokenService,
  })  : _localDataSource = localDataSource,
        _secureStorage = secureStorage,
        _auditLogger = auditLogger,
        _passwordHasher = passwordHasher,
        _tokenService = tokenService ?? SessionTokenService(secureStorage);

  final AuthLocalDataSource _localDataSource;
  final SecureStorageService _secureStorage;
  final AuditLoggerService? _auditLogger;
  final PasswordHasher _passwordHasher;
  final SessionTokenService _tokenService;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    final String? token =
        await _secureStorage.read(SecureStorageKeys.authSessionToken);
    final String? userId =
        await _secureStorage.read(SecureStorageKeys.authUserId);
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return const Right<Failure, UserEntity?>(null);
    }
    if (!await _tokenService.verify(token)) {
      await _clearSession();
      return const Right<Failure, UserEntity?>(null);
    }
    final UserModel? user = await _localDataSource.findUserById(userId);
    if (user == null) {
      await _clearSession();
      return const Right<Failure, UserEntity?>(null);
    }
    return Right<Failure, UserEntity?>(user);
  }

  @override
  Future<Either<Failure, UserEntity>> login(
    String username,
    String password, {
    bool remember = true,
  }) async {
    final String normalizedUsername = username.trim();
    final UserModel? user =
        await _localDataSource.findUserByUsername(normalizedUsername);
    if (user == null ||
        !_passwordHasher.verify(password, user.salt, user.passwordHash)) {
      return const Left<Failure, UserEntity>(
        UnauthenticatedFailure(
          message: 'Invalid username or password.',
        ),
      );
    }
    if (remember) {
      await _persistSession(user);
    }
    await _auditLogger?.logAction(
      action: AuditAction.login,
      entityName: 'User',
      entityId: user.id,
      after: <String, dynamic>{
        'username': user.username,
        'role': user.role.name,
      },
    );
    return Right<Failure, UserEntity>(user);
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final UserEntity? current = await _currentUserOrNull();
    await _auditLogger?.logAction(
      action: AuditAction.logout,
      entityName: 'User',
      entityId: current?.id,
      before: current == null
          ? null
          : <String, dynamic>{
              'username': current.username,
              'role': current.role.name,
            },
    );
    await _clearSession();
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getUsers() async {
    final List<UserModel> users = await _localDataSource.getUsers();
    return Right<Failure, List<UserEntity>>(users);
  }

  @override
  Future<Either<Failure, UserEntity>> createUser({
    required String username,
    required String email,
    required String fullName,
    required String password,
    required UserRole role,
    List<String> companyIds = const <String>[],
  }) async {
    final String normalizedUsername = username.trim();
    if (normalizedUsername.length < 3) {
      return const Left<Failure, UserEntity>(
        ValidationFailure(message: 'Username must be at least 3 characters.'),
      );
    }
    if (password.length < 6) {
      return const Left<Failure, UserEntity>(
        ValidationFailure(message: 'Password must be at least 6 characters.'),
      );
    }
    final UserModel? existing =
        await _localDataSource.findUserByUsername(normalizedUsername);
    if (existing != null) {
      return Left<Failure, UserEntity>(
        ValidationFailure(
          message: 'Username "$normalizedUsername" is already taken.',
        ),
      );
    }

    final SaltedPasswordHash salted = _passwordHasher.hash(password);
    final UserModel user = UserModel(
      id: 'user-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      username: normalizedUsername,
      email: email.trim(),
      fullName: fullName.trim(),
      role: role,
      companyIds: companyIds,
      createdAt: DateTime.now().toUtc(),
      salt: salted.salt,
      passwordHash: salted.hash,
    );
    await _localDataSource.insertUser(user);
    return Right<Failure, UserEntity>(user);
  }

  @override
  Future<Either<Failure, UserEntity>> updateUserRole(
    String userId,
    UserRole role,
  ) async {
    final UserModel? existing = await _localDataSource.findUserById(userId);
    if (existing == null) {
      return const Left<Failure, UserEntity>(
        NotFoundFailure(message: 'User not found.'),
      );
    }
    final UserModel updated = UserModel(
      id: existing.id,
      username: existing.username,
      email: existing.email,
      fullName: existing.fullName,
      role: role,
      companyIds: existing.companyIds,
      createdAt: existing.createdAt,
      salt: existing.salt,
      passwordHash: existing.passwordHash,
    );
    await _localDataSource.updateUser(updated);
    return Right<Failure, UserEntity>(updated);
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final UserModel? existing = await _localDataSource.findUserById(userId);
    if (existing == null) {
      return const Left<Failure, void>(
        NotFoundFailure(message: 'User not found.'),
      );
    }
    if (!_passwordHasher.verify(
      currentPassword,
      existing.salt,
      existing.passwordHash,
    )) {
      return const Left<Failure, void>(
        UnauthenticatedFailure(message: 'Current password is incorrect.'),
      );
    }
    if (newPassword.length < 6) {
      return const Left<Failure, void>(
        ValidationFailure(message: 'Password must be at least 6 characters.'),
      );
    }
    final SaltedPasswordHash salted = _passwordHasher.hash(newPassword);
    final UserModel updated = UserModel(
      id: existing.id,
      username: existing.username,
      email: existing.email,
      fullName: existing.fullName,
      role: existing.role,
      companyIds: existing.companyIds,
      createdAt: existing.createdAt,
      salt: salted.salt,
      passwordHash: salted.hash,
    );
    await _localDataSource.updateUser(updated);
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, void>> ensureDefaultAdmin() async {
    final int count = await _localDataSource.countUsers();
    if (count > 0) {
      return const Right<Failure, void>(null);
    }
    final Either<Failure, UserEntity> result = await createUser(
      username: 'admin',
      email: 'admin@finai.local',
      fullName: 'System Administrator',
      password: 'admin123',
      role: UserRole.admin,
    );
    if (result.isRight()) {
      debugPrint('[Auth] Seeded default administrator: admin / admin123');
    }
    return result.fold(
      (Failure failure) => Left<Failure, void>(failure),
      (UserEntity _) => const Right<Failure, void>(null),
    );
  }

  Future<UserEntity?> _currentUserOrNull() async {
    final Either<Failure, UserEntity?> result = await getCurrentUser();
    return result.fold(
      (Failure _) => null,
      (UserEntity? user) => user,
    );
  }

  Future<void> _persistSession(UserEntity user) async {
    final String token = await _tokenService.issue(user);
    await _secureStorage.write(SecureStorageKeys.authSessionToken, token);
    await _secureStorage.write(SecureStorageKeys.authUserId, user.id);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(SecureStorageKeys.authSessionToken);
    await _secureStorage.delete(SecureStorageKeys.authUserId);
  }
}
