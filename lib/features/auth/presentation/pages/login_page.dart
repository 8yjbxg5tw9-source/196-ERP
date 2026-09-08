import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/role_badge.dart';

/// Desktop sign-in screen with local credentials, "remember me", and a
/// role-based access badge row.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<AuthBloc>().add(
          LoginRequestedEvent(
            username: _usernameController.text,
            password: _passwordController.text,
            remember: _rememberMe,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (AuthState previous, AuthState current) =>
          current is AuthAuthenticated,
      listener: (BuildContext context, AuthState state) {
        // Navigation is driven by the root auth gate; nothing to do here.
      },
      builder: (BuildContext context, AuthState state) {
        final bool authenticating = state is AuthAuthenticating;
        final bool isLocked = state is AuthUnauthenticated &&
            state.message != null &&
            state.message!.isNotEmpty;
        final String? error = state is AuthFailure && state.currentUser == null
            ? state.message
            : null;

        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _BrandMark(size: 56),
                    const SizedBox(height: 18),
                    Text(
                      'FinAI Studio',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enterprise Accounting Copilot',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha(90),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (isLocked) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withAlpha(20),
                                  border: Border.all(
                                    color: AppColors.warning.withAlpha(120),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.lock_clock_rounded,
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (state as AuthUnauthenticated).message!,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _usernameController,
                              enabled: !authenticating,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (String? value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Enter your username'
                                      : null,
                              onFieldSubmitted: (_) => _submit(context),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !authenticating,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (String? value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Enter your password'
                                      : null,
                              onFieldSubmitted: (_) => _submit(context),
                            ),
                            const SizedBox(height: 6),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              title: Text(
                                'Remember me',
                                style: theme.textTheme.bodySmall,
                              ),
                              value: _rememberMe,
                              onChanged: authenticating
                                  ? null
                                  : (bool? value) => setState(
                                        () => _rememberMe = value ?? true,
                                      ),
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                error,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: authenticating
                                  ? null
                                  : () => _submit(context),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: authenticating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Role-based access',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        RoleBadge(role: UserRole.admin),
                        RoleBadge(role: UserRole.chiefAccountant),
                        RoleBadge(role: UserRole.juniorAccountant),
                        RoleBadge(role: UserRole.auditor),
                        RoleBadge(role: UserRole.clientViewer),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Default sign-in: admin / admin123',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.account_balance_rounded,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}
