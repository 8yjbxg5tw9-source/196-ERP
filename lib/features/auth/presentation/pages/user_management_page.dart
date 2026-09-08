import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/permission_guard.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/role_badge.dart';

/// Administration screen for provisioning users and assigning roles.
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (AuthState previous, AuthState current) =>
          current is AuthFailure && current.currentUser != null,
      listener: (BuildContext context, AuthState state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (BuildContext context, AuthState state) {
        final UserEntity? current = _userOf(state);
        final List<UserEntity> users = state is AuthAuthenticated
            ? state.users
            : const <UserEntity>[];
        final bool canManage = current != null &&
            PermissionGuard.canExecute(current.role, AppPermission.manageUsers);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Users & Roles'),
            actions: <Widget>[
              if (canManage)
                IconButton(
                  tooltip: 'Add user',
                  onPressed: () => _showCreateUserDialog(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final UserEntity user = users[index];
              return _UserTile(
                user: user,
                isCurrent: current?.id == user.id,
                canManage: canManage,
                onRoleChanged: (UserRole role) {
                  context.read<AuthBloc>().add(
                        SwitchUserRoleEvent(userId: user.id, role: role),
                      );
                },
                onChangePassword: () =>
                    _showChangePasswordDialog(context, user),
              );
            },
          ),
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

  Future<void> _showCreateUserDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateUserDialog(),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    UserEntity user,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _ChangePasswordDialog(user: user),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isCurrent,
    required this.canManage,
    required this.onRoleChanged,
    required this.onChangePassword,
  });

  final UserEntity user;
  final bool isCurrent;
  final bool canManage;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = user.fullName.trim().isEmpty
        ? user.username
        : user.fullName;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: theme.colorScheme.secondary.withAlpha(26),
            child: Text(
              name.trim().isEmpty
                  ? '?'
                  : name.trim().substring(0, 1).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCurrent) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        'You',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username} · ${user.email.isEmpty ? 'no email' : user.email}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          RoleBadge(role: user.role),
          if (canManage) ...<Widget>[
            const SizedBox(width: 8),
            DropdownButton<UserRole>(
              value: user.role,
              underline: const SizedBox.shrink(),
              onChanged: (UserRole? role) {
                if (role != null && role != user.role) {
                  onRoleChanged(role);
                }
              },
              items: UserRole.values
                  .map(
                    (UserRole role) => DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Change password',
            onPressed: onChangePassword,
            icon: const Icon(Icons.password_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  UserRole _role = UserRole.juniorAccountant;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<AuthBloc>().add(
          CreateUserEvent(
            username: _usernameController.text,
            email: _emailController.text,
            fullName: _fullNameController.text,
            password: _passwordController.text,
            role: _role,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add user'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _fullNameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter a full name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (String? value) =>
                    (value == null || value.trim().length < 3)
                        ? 'At least 3 characters'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (String? value) =>
                    (value == null || value.length < 6)
                        ? 'At least 6 characters'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .map(
                      (UserRole role) => DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (UserRole? role) =>
                    setState(() => _role = role ?? _role),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.user});

  final UserEntity user;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    context.read<AuthBloc>().add(
          ChangePasswordEvent(
            userId: widget.user.id,
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Change password — ${widget.user.username}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
