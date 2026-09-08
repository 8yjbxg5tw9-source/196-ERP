import 'env_config.dart';

/// Development defaults used when no `APP_ENV` dart define is supplied.
abstract final class DevEnv {
  static const EnvConfig config = EnvConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'https://api-dev.finai.studio',
    appName: 'FinAI Studio · Development',
    enableLogging: true,
  );
}

const EnvConfig devEnv = DevEnv.config;
