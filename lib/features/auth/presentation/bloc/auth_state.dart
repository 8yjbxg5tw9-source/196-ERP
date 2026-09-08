import 'package:equatable/equatable.dart';

import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const <Object?>[];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  /// Optional banner text, e.g. "Session locked — re-enter your password."
  final String? message;

  @override
  List<Object?> get props => <Object?>[message];
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.currentUser, {this.users = const <UserEntity>[]});

  final UserEntity currentUser;
  final List<UserEntity> users;

  @override
  List<Object?> get props => <Object?>[currentUser, users];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message, {this.currentUser});

  final String message;
  final UserEntity? currentUser;

  @override
  List<Object?> get props => <Object?>[message, currentUser];
}
