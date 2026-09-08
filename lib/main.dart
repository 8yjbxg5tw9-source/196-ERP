import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'config/env/env_config.dart';
import 'config/routes/app_navigator.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/native/notification_service.dart';
import 'core/native/system_tray_service.dart';
import 'core/native_windows/bloc/windows_native_bloc.dart';
import 'core/native_windows/bloc/windows_native_event.dart';
import 'core/services/audit_logger_service.dart';
import 'core/services/auto_backup_service.dart';
import 'core/storage/app_preferences.dart';
import 'core/utils/constants.dart';
import 'features/audit/domain/entities/audit_log_entity.dart';
import 'features/auth/auth.dart';
import 'features/company/presentation/bloc/company_bloc.dart';
import 'features/company/presentation/bloc/company_event.dart';
import 'features/currency/currency.dart';
import 'features/document_ocr/domain/repositories/document_repository.dart';
import 'features/tax_copilot/domain/repositories/tax_copilot_repository.dart';
import 'injection_container.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/command_palette.dart';

const String _windowTitle = 'FinAI Studio - Enterprise Accounting Copilot';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  await init();
  _configureErrorReporting();
  if (!kIsWeb) {
    WidgetsBinding.instance.addObserver(_AppExitBackupObserver());
    sl<AutoBackupService>().start();
    await _initializeNativeServices();
  }
  runApp(FinAiApp(config: sl<EnvConfig>()));
}

/// Routes uncaught framework and isolate errors into the immutable audit log
/// (Step 36) and silences verbose debug logging in release builds.
void _configureErrorReporting() {
  if (kProductBuild) {
    // Release builds disable verbose debug logging entirely.
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _reportUncaughtError(
      'FlutterError: ${details.exceptionAsString()}',
      details.stack?.toString(),
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
    _reportUncaughtError('Uncaught exception: $error', stack.toString());
    return true;
  };
}

/// Fire-and-forget audit write; the handler must never throw or block the
/// event loop, even if the database or secure storage is unavailable.
void _reportUncaughtError(String message, String? stackTrace) {
  try {
    unawaited(
      sl<AuditLoggerService>().logAction(
        action: AuditAction.systemError,
        entityName: 'System',
        after: <String, dynamic>{
          'message': message,
          'stackTrace': stackTrace ?? '',
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
  } on Object {
    // Swallow: a failing error reporter must not mask the original error.
  }
}

/// Starts desktop notifications and the system tray according to settings.
///
/// The notification service is always prepared so feature code (VAT deadline
/// warnings, OCR batch completion, unmatched bank alerts) can fire toasts
/// later; the system tray is only created when the user has it enabled.
Future<void> _initializeNativeServices() async {
  final AppPreferences preferences = sl<AppPreferences>();

  await sl<NotificationService>().initialize();

  if (await preferences.isSystemTrayEnabled()) {
    await sl<SystemTrayService>().initialize();
  }

  // Register global keyboard shortcuts (Ctrl+N, Ctrl+Shift+R, Ctrl+F,
  // Ctrl+Shift+A) and surface them through the native-integration bloc.
  await sl<WindowsNativeBloc>().add(const InitNativeServicesEvent());
}

/// Runs the "On App Exit" backup when the operating system asks the app to
/// quit, complementing the desktop close button handled by [AppShell].
class _AppExitBackupObserver with WidgetsBindingObserver {
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await sl<AutoBackupService>().backupOnAppExit();
    return AppExitResponse.exit;
  }
}

/// Applies native window constraints only on supported desktop targets.
///
/// The title bar is hidden so [AppShell] can render a consistent custom action
/// bar while [window_manager] still owns native sizing and lifecycle calls.
Future<void> _configureDesktopWindow() async {
  if (!_isDesktopPlatform) {
    return;
  }

  await windowManager.ensureInitialized();
  final WindowOptions options = WindowOptions(
    size: const Size(1280, 800),
    minimumSize: const Size(1100, 700),
    center: true,
    title: _windowTitle,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options);
  await windowManager.show();
  await windowManager.focus();
}

bool get _isDesktopPlatform {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class FinAiApp extends StatefulWidget {
  const FinAiApp({required this.config, super.key});

  final EnvConfig config;

  @override
  State<FinAiApp> createState() => _FinAiAppState();
}

class _FinAiAppState extends State<FinAiApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    final Brightness systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool isCurrentlyDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            systemBrightness == Brightness.dark);

    setState(() {
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TaxCopilotRepository>.value(
      value: sl<TaxCopilotRepository>(),
      child: RepositoryProvider<DocumentRepository>.value(
        value: sl<DocumentRepository>(),
        child: BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
          child: BlocProvider<CompanyBloc>(
            create: (_) => sl<CompanyBloc>()..add(const LoadCompaniesEvent()),
            child: BlocProvider<CurrencyBloc>(
              create: (_) => sl<CurrencyBloc>(),
              child: CommandPaletteShortcuts(
                child: MaterialApp(
                  title: _windowTitle,
                  debugShowCheckedModeBanner: false,
                  navigatorKey: AppNavigator.key,
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: _themeMode,
                  home: BlocBuilder<AuthBloc, AuthState>(
                    builder: (BuildContext context, AuthState state) =>
                        _buildHome(context, state),
                  ),
                  onGenerateRoute: AppRouter.onGenerateRoute,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context, AuthState state) {
    final UserEntity? user = switch (state) {
      AuthAuthenticated(:final currentUser) => currentUser,
      AuthFailure(:final currentUser) => currentUser,
      _ => null,
    };
    if (user == null) {
      return const LoginPage();
    }
    return InactivityWatcher(
      onLock: () =>
          context.read<AuthBloc>().add(const SessionLockedEvent()),
      child: AppShell(
        config: widget.config,
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
