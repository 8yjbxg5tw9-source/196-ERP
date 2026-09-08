import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/permission_guard.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../pages/user_management_page.dart';
import 'role_badge.dart';

enum _UserAction { manageUsers, logout }

/// Signed-in user chip shown in the desktop action bar, with role badge and a
/// menu for user management and logout.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (BuildContext context, AuthState state) {
        final UserEntity? user = _userOf(state);
        if (user == null) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<_UserAction>(
          tooltip: 'Account',
          onSelected: (_UserAction action) {
            switch (action) {
              case _UserAction.manageUsers:
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const UserManagementPage(),
                  ),
                );
                break;
              case _UserAction.logout:
                context.read<AuthBloc>().add(const LogoutRequestedEvent());
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<_UserAction>>[
            if (PermissionGuard.canExecute(
              user.role,
              AppPermission.manageUsers,
            ))
              const PopupMenuItem<_UserAction>(
                value: _UserAction.manageUsers,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.group_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Manage Users'),
                  ],
                ),
              ),
            const PopupMenuItem<_UserAction>(
              value: _UserAction.logout,
              child: Row(
                children: <Widget>[
                  Icon(Icons.logout_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Logout'),
                ],
              ),
            ),
          ],
          child: _UserChip(user: user),
        );
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

class _UserChip extends StatelessWidget {
  const _UserChip({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = user.fullName.trim().isEmpty
        ? user.username
        : user.fullName;
    final String initial = name.isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(left: 8, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(100)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.secondary.withAlpha(30),
            child: Text(
              initial,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoleBadge(role: user.role),
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more_rounded, size: 16),
        ],
      ),
    );
  }
}
