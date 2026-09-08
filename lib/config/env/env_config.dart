/// The runtime flavor used to select an environment configuration.
enum AppEnvironment {
  development,
  production,
}

/// Immutable configuration shared by infrastructure and presentation layers.
///
/// Values are selected at compile time through the `APP_ENV` dart define. This
/// keeps secrets and deployment-specific values out of feature code while
/// making the active environment explicit and testable.
class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    required this.enableLogging,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String appName;
  final bool enableLogging;

  bool get isProduction => environment == AppEnvironment.production;
}
