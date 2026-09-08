import 'package:equatable/equatable.dart';

import '../../domain/entities/user_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class LoginRequestedEvent extends AuthEvent {
  const LoginRequestedEvent({
    required this.username,
    required this.password,
    this.remember = true,
  });

  final String username;
  final String password;
  final bool remember;

  @override
  List<Object?> get props => <Object?>[username, password, remember];
}

class LogoutRequestedEvent extends AuthEvent {
  const LogoutRequestedEvent();
}

/// Fired by the inactivity watcher after the idle timeout elapses.
class SessionLockedEvent extends AuthEvent {
  const SessionLockedEvent();
}

class LoadUsersEvent extends AuthEvent {
  const LoadUsersEvent();
}

class CreateUserEvent extends AuthEvent {
  const CreateUserEvent({
    required this.username,
    required this.email,
    required this.fullName,
    required this.password,
    required this.role,
    this.companyIds = const <String>[],
  });

  final String username;
  final String email;
  final String fullName;
  final String password;
  final UserRole role;
  final List<String> companyIds;

  @override
  List<Object?> get props => <Object?>[
        username,
        email,
        fullName,
        password,
        role,
        companyIds,
      ];
}

class SwitchUserRoleEvent extends AuthEvent {
  const SwitchUserRoleEvent({
    required this.userId,
    required this.role,
  });

  final String userId;
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[userId, role];
}

class ChangePasswordEvent extends AuthEvent {
  const ChangePasswordEvent({
    required this.userId,
    required this.currentPassword,
    required this.newPassword,
  });

  final String userId;
  final String currentPassword;
  final String newPassword;

  @override
  List<Object?> get props => <Object?>[userId, currentPassword, newPassword];
}
