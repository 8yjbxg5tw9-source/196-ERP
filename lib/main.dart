import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'config/env/env_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'features/company/presentation/bloc/company_bloc.dart';
import 'features/company/presentation/bloc/company_event.dart';
import 'features/document_ocr/domain/repositories/document_repository.dart';
import 'features/tax_copilot/domain/repositories/tax_copilot_repository.dart';
import 'injection_container.dart';
import 'shared/widgets/app_shell.dart';

const String _windowTitle = 'FinAI Studio - Enterprise Accounting Copilot';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  await init();
  runApp(FinAiApp(config: sl<EnvConfig>()));
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
        child: BlocProvider<CompanyBloc>(
          create: (_) => sl<CompanyBloc>()..add(const LoadCompaniesEvent()),
          child: MaterialApp(
            title: _windowTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeMode,
            home: AppShell(
              config: widget.config,
              themeMode: _themeMode,
              onToggleTheme: _toggleTheme,
            ),
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
  }
}
