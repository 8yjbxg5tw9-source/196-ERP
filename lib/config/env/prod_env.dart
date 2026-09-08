import 'env_config.dart';

/// Production defaults. Secrets must be supplied by the backend or a secure
/// deployment pipeline and should never be committed to this file.
abstract final class ProdEnv {
  static const EnvConfig config = EnvConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: 'https://api.finai.studio',
    appName: 'FinAI Studio',
    enableLogging: false,
  );
}

const EnvConfig prodEnv = ProdEnv.config;
