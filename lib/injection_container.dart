import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env/dev_env.dart';
import 'config/env/env_config.dart';
import 'config/env/prod_env.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/utils/constants.dart';

/// Global, type-safe service locator.
final GetIt sl = GetIt.instance;

/// Registers application-wide dependencies.
///
/// Registration is deliberately kept explicit for the initial architecture.
/// Feature repositories, data sources, and BLoCs can be registered here (or
/// migrated to injectable-generated modules) as they are introduced.
Future<void> init({EnvConfig? environment}) async {
  if (!sl.isRegistered<EnvConfig>()) {
    sl.registerSingleton<EnvConfig>(environment ?? _resolveEnvironment());
  }

  if (!sl.isRegistered<Dio>()) {
    sl.registerLazySingleton<Dio>(() {
      final EnvConfig config = sl<EnvConfig>();
      final Dio dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: AppConstants.connectionTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          sendTimeout: AppConstants.sendTimeout,
          headers: <String, String>{'Accept': 'application/json'},
        ),
      );

      if (config.enableLogging) {
        dio.interceptors.add(
          LogInterceptor(requestBody: false, responseBody: false),
        );
      }
      return dio;
    });
  }

  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>()));
  }

  if (!sl.isRegistered<Connectivity>()) {
    sl.registerLazySingleton<Connectivity>(() => Connectivity());
  }

  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(sl<Connectivity>()),
    );
  }

  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => FlutterSecureStorage(),
    );
  }

  if (!sl.isRegistered<SharedPreferences>()) {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(preferences);
  }
}

EnvConfig _resolveEnvironment() {
  const String flavor = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  switch (flavor.toLowerCase()) {
    case 'prod':
    case 'production':
      return ProdEnv.config;
    case 'dev':
    case 'development':
    default:
      return DevEnv.config;
  }
}
