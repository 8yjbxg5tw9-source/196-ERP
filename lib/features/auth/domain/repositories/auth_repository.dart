import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Authentication, session, and user-management boundary.
abstract interface class AuthRepository {
  /// Returns the persisted session user, or `null` when signed out.
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Validates credentials and persists a signed session token.
  ///
  /// When [remember] is false the session is held in memory only and is not
  /// written to secure storage, so the next launch starts signed out.
  Future<Either<Failure, UserEntity>> login(
    String username,
    String password, {
    bool remember = true,
  });

  /// Clears the persisted session token and active user.
  Future<Either<Failure, void>> logout();

  /// Lists every local user, ordered by role privilege then username.
  Future<Either<Failure, List<UserEntity>>> getUsers();

  /// Creates a user with a salted, hashed password. Usernames are unique.
  Future<Either<Failure, UserEntity>> createUser({
    required String username,
    required String email,
    required String fullName,
    required String password,
    required UserRole role,
    List<String> companyIds = const <String>[],
  });

  /// Updates a user's role, re-emitting the current session when it is the
  /// active user being changed.
  Future<Either<Failure, UserEntity>> updateUserRole(
    String userId,
    UserRole role,
  );

  /// Rotates a user's password after verifying the current one.
  Future<Either<Failure, void>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });

  /// Seeds a default administrator so a fresh install is always signable.
  Future<Either<Failure, void>> ensureDefaultAdmin();
}
