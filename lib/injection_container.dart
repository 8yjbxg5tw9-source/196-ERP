import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env/dev_env.dart';
import 'config/env/env_config.dart';
import 'config/env/prod_env.dart';
import 'core/database/database_service.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/utils/constants.dart';
import 'features/company/data/company_data.dart';
import 'features/company/domain/company_domain.dart';
import 'features/company/presentation/bloc/company_bloc.dart';

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
      return dio;
    });
  }

  if (!sl.isRegistered<Connectivity>()) {
    sl.registerSingleton<Connectivity>(Connectivity());
  }

  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerSingleton<NetworkInfo>(
      NetworkInfoImpl(sl<Connectivity>()),
    );
  }

  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => FlutterSecureStorage(),
    );
  }

  if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerSingleton<SecureStorageService>(
      SecureStorageServiceImpl(sl<FlutterSecureStorage>()),
    );
  }

  if (!sl.isRegistered<ApiClient>()) {
    sl.registerSingleton<ApiClient>(
      ApiClient(
        sl<Dio>(),
        secureStorage: sl<SecureStorageService>(),
        networkInfo: sl<NetworkInfo>(),
        enableLogging: kDebugMode && sl<EnvConfig>().enableLogging,
      ),
    );
  }
  await _logInitialConnectivity();

  if (!sl.isRegistered<DatabaseService>()) {
    sl.registerSingleton<DatabaseService>(DatabaseService());
  }

  if (!sl.isRegistered<CompanyLocalDataSource>()) {
    sl.registerLazySingleton<CompanyLocalDataSource>(
      () => CompanyLocalDataSourceImpl(
        sl<DatabaseService>(),
        sl<SecureStorageService>(),
      ),
    );
  }

  if (!sl.isRegistered<CompanyRepository>()) {
    sl.registerLazySingleton<CompanyRepository>(
      () => CompanyRepositoryImpl(sl<CompanyLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<GetCompaniesUseCase>()) {
    sl.registerLazySingleton<GetCompaniesUseCase>(
      () => GetCompaniesUseCase(sl<CompanyRepository>()),
    );
  }
  if (!sl.isRegistered<CreateCompanyUseCase>()) {
    sl.registerLazySingleton<CreateCompanyUseCase>(
      () => CreateCompanyUseCase(sl<CompanyRepository>()),
    );
  }
  if (!sl.isRegistered<DeleteCompanyUseCase>()) {
    sl.registerLazySingleton<DeleteCompanyUseCase>(
      () => DeleteCompanyUseCase(sl<CompanyRepository>()),
    );
  }
  if (!sl.isRegistered<GetActiveCompanyUseCase>()) {
    sl.registerLazySingleton<GetActiveCompanyUseCase>(
      () => GetActiveCompanyUseCase(sl<CompanyRepository>()),
    );
  }
  if (!sl.isRegistered<SwitchActiveCompanyUseCase>()) {
    sl.registerLazySingleton<SwitchActiveCompanyUseCase>(
      () => SwitchActiveCompanyUseCase(sl<CompanyRepository>()),
    );
  }
  if (!sl.isRegistered<CompanyBloc>()) {
    sl.registerFactory<CompanyBloc>(
      () => CompanyBloc(
        getCompanies: sl<GetCompaniesUseCase>(),
        createCompany: sl<CreateCompanyUseCase>(),
        deleteCompany: sl<DeleteCompanyUseCase>(),
        getActiveCompany: sl<GetActiveCompanyUseCase>(),
        switchActiveCompany: sl<SwitchActiveCompanyUseCase>(),
      ),
    );
  }

  // The relational implementation is available on desktop and mobile. Web
  // can still boot and use the shell, but does not initialize native SQLite.
  if (!kIsWeb) {
    await sl<DatabaseService>().initialize();
  }

  if (!sl.isRegistered<SharedPreferences>()) {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(preferences);
  }
}

Future<void> _logInitialConnectivity() async {
  if (!kDebugMode) {
    return;
  }

  try {
    final bool connected = await sl<NetworkInfo>().isConnected;
    debugPrint('[NetworkInfo] Initial connectivity: $connected');
  } on Object catch (error) {
    debugPrint('[NetworkInfo] Initial connectivity check unavailable: $error');
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
