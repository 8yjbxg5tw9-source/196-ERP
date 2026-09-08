import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages login sessions, role switching, user provisioning, and the
/// auto-lock flow for the local multi-user workspace.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repository = repository,
        super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginRequestedEvent>(_onLoginRequested);
    on<LogoutRequestedEvent>(_onLogoutRequested);
    on<SessionLockedEvent>(_onSessionLocked);
    on<LoadUsersEvent>(_onLoadUsers);
    on<CreateUserEvent>(_onCreateUser);
    on<SwitchUserRoleEvent>(_onSwitchUserRole);
    on<ChangePasswordEvent>(_onChangePassword);
  }

  final AuthRepository _repository;

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    final UserEntity? user = await _currentUserOrNull();
    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    emit(AuthAuthenticated(user, users: await _loadUsersOrEmpty()));
  }

  Future<void> _onLoginRequested(
    LoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    final Either<Failure, UserEntity> result = await _repository.login(
      event.username,
      event.password,
      remember: event.remember,
    );
    UserEntity? user;
    final Failure? failure = result.fold(
      (Failure value) => value,
      (UserEntity value) {
        user = value;
        return null;
      },
    );
    if (failure != null || user == null) {
      emit(AuthFailure(failure?.message ?? 'Login failed.'));
      return;
    }
    emit(AuthAuthenticated(user!, users: await _loadUsersOrEmpty()));
  }

  Future<void> _onLogoutRequested(
    LogoutRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionLocked(
    SessionLockedEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(
      const AuthUnauthenticated(
        message: 'Session locked after 15 minutes of inactivity. '
            'Please sign in again.',
      ),
    );
  }

  Future<void> _onLoadUsers(
    LoadUsersEvent event,
    Emitter<AuthState> emit,
  ) async {
    final UserEntity? current = _currentUserOf(state);
    if (current == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    emit(AuthAuthenticated(current, users: await _loadUsersOrEmpty()));
  }

  Future<void> _onCreateUser(
    CreateUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final UserEntity? current = _currentUserOf(state);
    final Either<Failure, UserEntity> result = await _repository.createUser(
      username: event.username,
      email: event.email,
      fullName: event.fullName,
      password: event.password,
      role: event.role,
      companyIds: event.companyIds,
    );
    UserEntity? created;
    final Failure? failure = result.fold(
      (Failure value) => value,
      (UserEntity value) {
        created = value;
        return null;
      },
    );
    if (failure != null) {
      emit(AuthFailure(failure.message, currentUser: current));
      return;
    }
    emit(
      AuthAuthenticated(
        current ?? created!,
        users: await _loadUsersOrEmpty(),
      ),
    );
  }

  Future<void> _onSwitchUserRole(
    SwitchUserRoleEvent event,
    Emitter<AuthState> emit,
  ) async {
    final UserEntity? current = _currentUserOf(state);
    final Either<Failure, UserEntity> result = await _repository.updateUserRole(
      event.userId,
      event.role,
    );
    UserEntity? updated;
    final Failure? failure = result.fold(
      (Failure value) => value,
      (UserEntity value) {
        updated = value;
        return null;
      },
    );
    if (failure != null || updated == null) {
      emit(AuthFailure(failure?.message ?? 'Could not update role.'));
      return;
    }
    final UserEntity active =
        current != null && current.id == updated!.id ? updated! : current ?? updated!;
    emit(AuthAuthenticated(active, users: await _loadUsersOrEmpty()));
  }

  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    final UserEntity? current = _currentUserOf(state);
    final Either<Failure, void> result = await _repository.changePassword(
      userId: event.userId,
      currentPassword: event.currentPassword,
      newPassword: event.newPassword,
    );
    final Failure? failure = result.fold(
      (Failure value) => value,
      (void _) => null,
    );
    if (failure != null) {
      emit(AuthFailure(failure.message, currentUser: current));
      return;
    }
    if (current == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    emit(AuthAuthenticated(current, users: await _loadUsersOrEmpty()));
  }

  Future<UserEntity?> _currentUserOrNull() async {
    final Either<Failure, UserEntity?> result = await _repository.getCurrentUser();
    return result.fold(
      (Failure _) => null,
      (UserEntity? value) => value,
    );
  }

  Future<List<UserEntity>> _loadUsersOrEmpty() async {
    final Either<Failure, List<UserEntity>> result = await _repository.getUsers();
    return result.fold(
      (Failure _) => const <UserEntity>[],
      (List<UserEntity> users) => users,
    );
  }

  static UserEntity? _currentUserOf(AuthState state) {
    return switch (state) {
      AuthAuthenticated(:final currentUser) => currentUser,
      AuthFailure(:final currentUser) => currentUser,
      _ => null,
    };
  }
}
