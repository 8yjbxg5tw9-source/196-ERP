import 'package:flutter/material.dart';

/// Centralized route names keep navigation independent from feature widgets.
abstract final class AppRoutes {
  static const String home = '/';
  static const String notFound = '/not-found';
}

/// Route factory for the application shell.
///
/// Feature routes can be added here as each feature's presentation layer is
/// introduced. Keeping the route boundary in `config` prevents feature code
/// from depending on `MaterialApp` configuration.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _pageRoute(settings, const _BootstrapPage());
      case AppRoutes.notFound:
      default:
        return _pageRoute(
          settings,
          _NotFoundPage(routeName: settings.name),
        );
    }
  }

  static MaterialPageRoute<void> _pageRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }
}

class _BootstrapPage extends StatelessWidget {
  const _BootstrapPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FinAI Studio')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Your intelligent financial workspace',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Core architecture initialized. Feature modules are ready to be added.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Text(
          'No route was registered for ${routeName ?? 'this path'}.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
