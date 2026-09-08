import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/permission_guard.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

/// Renders [child] only when the active user's role grants [permission].
///
/// Widgets that should remain visible but disabled can instead use
/// [PermissionGate.builder] to receive the boolean decision.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  const PermissionGate.builder({
    required this.permission,
    required Widget Function(BuildContext context, bool allowed) builder,
    super.key,
  })  : child = null,
        fallback = null,
        _builder = builder;

  final AppPermission permission;
  final Widget? child;
  final Widget? fallback;
  final Widget Function(BuildContext context, bool allowed)? _builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (BuildContext context, AuthState state) {
        final UserEntity? user = _userOf(state);
        final bool allowed =
            user != null && PermissionGuard.canExecute(user.role, permission);
        final Widget Function(BuildContext, bool)? builder = _builder;
        if (builder != null) {
          return builder(context, allowed);
        }
        return allowed ? child! : fallback ?? const SizedBox.shrink();
      },
    );
  }

  static UserEntity? _userOf(AuthState state) {
    return switch (state) {
      AuthAuthenticated(:final currentUser) => currentUser,
      AuthFailure(:final currentUser) => currentUser,
      _ => null,
    };
  }
}
