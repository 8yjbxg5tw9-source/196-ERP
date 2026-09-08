import 'package:flutter/material.dart';

import 'config/env/env_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  runApp(FinAiApp(config: sl<EnvConfig>()));
}

class FinAiApp extends StatelessWidget {
  const FinAiApp({required this.config, super.key});

  final EnvConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
