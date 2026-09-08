import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'config/env/dev_env.dart';
import 'config/env/env_config.dart';
import 'config/env/prod_env.dart';
import 'core/database/database_service.dart';
import 'core/native/notification_service.dart';
import 'core/native/system_tray_service.dart';
import 'core/native_windows/bloc/windows_native_bloc.dart';
import 'core/native_windows/hotkey_service.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/performance/database_optimizer.dart';
import 'core/services/app_directory_service.dart';
import 'core/services/audit_logger_service.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/backup_service.dart';
import 'core/services/excel_export_service.dart';
import 'core/services/export_service.dart';
import 'core/services/ocr_service.dart';
import 'core/services/pdf_generator_service.dart';
import 'core/services/task_queue_manager.dart';
import 'core/services/tax_xml_serializer.dart';
import 'core/storage/app_preferences.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/utils/constants.dart';
import 'features/analytics/analytics.dart';
import 'features/assets/assets.dart';
import 'features/audit/audit.dart';
import 'features/auth/auth.dart';
import 'features/cash_flow/cash_flow.dart';
import 'features/company/data/company_data.dart';
import 'features/company/domain/company_domain.dart';
import 'features/company/presentation/bloc/company_bloc.dart';
import 'features/consolidation/consolidation.dart';
import 'features/currency/currency.dart';
import 'features/disaster_recovery/disaster_recovery.dart';
import 'features/document_ocr/data/document_data.dart';
import 'features/document_ocr/domain/document_domain.dart';
import 'features/document_ocr/presentation/bloc/document_ocr_bloc.dart';
import 'features/intercompany/intercompany.dart';
import 'features/inventory/inventory.dart';
import 'features/payroll/payroll.dart';
import 'features/reconciliation/reconciliation.dart';
import 'features/search/search.dart';
import 'features/tax_copilot/data/tax_copilot_data.dart';
import 'features/tax_copilot/domain/tax_domain.dart';
import 'features/tax_copilot/presentation/bloc/tax_copilot_bloc.dart';
import 'features/tax_declaration/tax_declaration.dart';
import 'features/tax_deferred/tax_deferred.dart';
import 'shared/bloc/search_bloc.dart';
import 'shared/navigation/app_shell_controller.dart';

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

  if (!sl.isRegistered<AppDirectoryService>()) {
    sl.registerLazySingleton<AppDirectoryService>(
      () => const AppDirectoryServiceImpl(),
    );
  }

  if (!sl.isRegistered<DatabaseService>()) {
    sl.registerSingleton<DatabaseService>(
      DatabaseService(directoryService: sl<AppDirectoryService>()),
    );
  }

  if (!sl.isRegistered<DatabaseOptimizer>()) {
    sl.registerLazySingleton<DatabaseOptimizer>(() => const DatabaseOptimizer());
  }

  if (!sl.isRegistered<AuditLocalDataSource>()) {
    sl.registerLazySingleton<AuditLocalDataSource>(
      () => AuditLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<AuditRepository>()) {
    sl.registerLazySingleton<AuditRepository>(
      () => AuditRepositoryImpl(sl<AuditLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<AuditLoggerService>()) {
    sl.registerLazySingleton<AuditLoggerService>(
      () => AuditLoggerService(
        auditRepository: sl<AuditRepository>(),
        secureStorage: sl<SecureStorageService>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
      ),
    );
  }

  if (!sl.isRegistered<AuditBloc>()) {
    sl.registerFactory<AuditBloc>(
      () => AuditBloc(
        repository: sl<AuditRepository>(),
        exportService: sl<ExportService>(),
      ),
    );
  }

  if (!sl.isRegistered<BackupService>()) {
    sl.registerLazySingleton<BackupService>(
      () => BackupServiceImpl(
        databaseService: sl<DatabaseService>(),
        secureStorage: sl<SecureStorageService>(),
        directoryService: sl<AppDirectoryService>(),
        auditLogger: sl<AuditLoggerService>(),
      ),
    );
  }

  if (!sl.isRegistered<AutoBackupService>()) {
    sl.registerLazySingleton<AutoBackupService>(
      () => AutoBackupService(
        backupService: sl<BackupService>(),
        secureStorage: sl<SecureStorageService>(),
        preferences: sl<SharedPreferences>(),
      ),
    );
  }

  if (!sl.isRegistered<BackupRepository>()) {
    sl.registerLazySingleton<BackupRepository>(
      () => BackupRepositoryImpl(
        backupService: sl<BackupService>(),
        autoBackupService: sl<AutoBackupService>(),
        preferences: sl<SharedPreferences>(),
      ),
    );
  }

  if (!sl.isRegistered<BackupBloc>()) {
    sl.registerFactory<BackupBloc>(
      () => BackupBloc(repository: sl<BackupRepository>()),
    );
  }

  if (!sl.isRegistered<CurrencyLocalDataSource>()) {
    sl.registerLazySingleton<CurrencyLocalDataSource>(
      () => CurrencyLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<CurrencyRemoteDataSource>()) {
    sl.registerLazySingleton<CurrencyRemoteDataSource>(
      () => CurrencyRemoteDataSourceImpl(sl<Dio>()),
    );
  }

  if (!sl.isRegistered<CurrencyRepository>()) {
    sl.registerLazySingleton<CurrencyRepository>(
      () => CurrencyRepositoryImpl(
        localDataSource: sl<CurrencyLocalDataSource>(),
        remoteDataSource: sl<CurrencyRemoteDataSource>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }

  if (!sl.isRegistered<CurrencyConversionService>()) {
    sl.registerLazySingleton<CurrencyConversionService>(
      () => CurrencyConversionServiceImpl(
        repository: sl<CurrencyRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<CurrencyBloc>()) {
    sl.registerFactory<CurrencyBloc>(
      () => CurrencyBloc(repository: sl<CurrencyRepository>()),
    );
  }

  if (!sl.isRegistered<AuthLocalDataSource>()) {
    sl.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        localDataSource: sl<AuthLocalDataSource>(),
        secureStorage: sl<SecureStorageService>(),
        auditLogger: sl<AuditLoggerService>(),
      ),
    );
  }

  if (!sl.isRegistered<AuthBloc>()) {
    sl.registerFactory<AuthBloc>(
      () => AuthBloc(repository: sl<AuthRepository>()),
    );
  }

  if (!sl.isRegistered<PdfGeneratorService>()) {
    sl.registerLazySingleton<PdfGeneratorService>(
      () => const PdfGeneratorService(),
    );
  }

  if (!sl.isRegistered<ExcelExportService>()) {
    sl.registerLazySingleton<ExcelExportService>(
      () => const ExcelExportService(),
    );
  }

  if (!sl.isRegistered<TaxXmlSerializer>()) {
    sl.registerLazySingleton<TaxXmlSerializer>(
      () => const TaxXmlSerializer(),
    );
  }

  if (!sl.isRegistered<ExportService>()) {
    sl.registerLazySingleton<ExportService>(
      () => ExportServiceImpl(
        pdfGenerator: sl<PdfGeneratorService>(),
        excelService: sl<ExcelExportService>(),
        xmlSerializer: sl<TaxXmlSerializer>(),
        directoryService: sl<AppDirectoryService>(),
        auditLogger: sl<AuditLoggerService>(),
      ),
    );
  }

  if (!sl.isRegistered<OcrService>()) {
    sl.registerLazySingleton<OcrService>(() => const MockOcrService());
  }

  if (!sl.isRegistered<DocumentLocalDataSource>()) {
    sl.registerLazySingleton<DocumentLocalDataSource>(
      () => DocumentLocalDataSourceImpl(
        sl<DatabaseService>(),
        auditLogger: sl<AuditLoggerService>(),
        directoryService: sl<AppDirectoryService>(),
      ),
    );
  }

  if (!sl.isRegistered<DocumentRepository>()) {
    sl.registerLazySingleton<DocumentRepository>(
      () => DocumentRepositoryImpl(
        sl<DocumentLocalDataSource>(),
        sl<OcrService>(),
      ),
    );
  }

  if (!sl.isRegistered<DocumentOcrBloc>()) {
    sl.registerFactory<DocumentOcrBloc>(
      () => DocumentOcrBloc(repository: sl<DocumentRepository>()),
    );
  }

  if (!sl.isRegistered<ReconciliationLocalDataSource>()) {
    sl.registerLazySingleton<ReconciliationLocalDataSource>(
      () => ReconciliationLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<MatchingEngine>()) {
    sl.registerLazySingleton<MatchingEngine>(() => const MatchingEngine());
  }

  if (!sl.isRegistered<RulesLocalDataSource>()) {
    sl.registerLazySingleton<RulesLocalDataSource>(
      () => RulesLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<RuleRepository>()) {
    sl.registerLazySingleton<RuleRepository>(
      () => RuleRepositoryImpl(sl<RulesLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<RuleMatchingEvaluator>()) {
    sl.registerLazySingleton<RuleMatchingEvaluator>(
      () => const RuleMatchingEvaluator(),
    );
  }

  if (!sl.isRegistered<AnomalyDetectionEngine>()) {
    sl.registerLazySingleton<AnomalyDetectionEngine>(
      () => const AnomalyDetectionEngine(),
    );
  }

  if (!sl.isRegistered<ReconciliationRepository>()) {
    sl.registerLazySingleton<ReconciliationRepository>(
      () => ReconciliationRepositoryImpl(
        sl<ReconciliationLocalDataSource>(),
        sl<DocumentLocalDataSource>(),
        matchingEngine: sl<MatchingEngine>(),
        ruleRepository: sl<RuleRepository>(),
        ruleEvaluator: sl<RuleMatchingEvaluator>(),
      ),
    );
  }

  if (!sl.isRegistered<ReconciliationBloc>()) {
    sl.registerFactory<ReconciliationBloc>(
      () => ReconciliationBloc(repository: sl<ReconciliationRepository>()),
    );
  }

  if (!sl.isRegistered<RulesBloc>()) {
    sl.registerFactory<RulesBloc>(
      () => RulesBloc(repository: sl<RuleRepository>()),
    );
  }

  if (!sl.isRegistered<AnomalyBloc>()) {
    sl.registerFactory<AnomalyBloc>(
      () => AnomalyBloc(
        engine: sl<AnomalyDetectionEngine>(),
        transactionsDataSource: sl<ReconciliationLocalDataSource>(),
        documentDataSource: sl<DocumentLocalDataSource>(),
      ),
    );
  }

  if (!sl.isRegistered<AnalyticsLocalDataSource>()) {
    sl.registerLazySingleton<AnalyticsLocalDataSource>(
      () => AnalyticsLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<FinancialReportRepository>()) {
    sl.registerLazySingleton<FinancialReportRepository>(
      () => FinancialReportRepositoryImpl(sl<AnalyticsLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<ReportPdfExporter>()) {
    sl.registerLazySingleton<ReportPdfExporter>(() => const ReportPdfExporter());
  }

  if (!sl.isRegistered<FinancialReportBloc>()) {
    sl.registerFactory<FinancialReportBloc>(
      () => FinancialReportBloc(
        repository: sl<FinancialReportRepository>(),
        exporter: sl<ReportPdfExporter>(),
      ),
    );
  }

  if (!sl.isRegistered<FinancialRatioRepository>()) {
    sl.registerLazySingleton<FinancialRatioRepository>(
      () => FinancialRatioRepositoryImpl(
        sl<AnalyticsLocalDataSource>(),
        sl<FinancialReportRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<AnalyticsBloc>()) {
    sl.registerFactory<AnalyticsBloc>(
      () => AnalyticsBloc(repository: sl<FinancialRatioRepository>()),
    );
  }

  if (!sl.isRegistered<CashFlowLocalDataSource>()) {
    sl.registerLazySingleton<CashFlowLocalDataSource>(
      () => CashFlowLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<CashFlowRepository>()) {
    sl.registerLazySingleton<CashFlowRepository>(
      () => CashFlowRepositoryImpl(
        sl<CashFlowLocalDataSource>(),
        sl<FinancialReportRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<CashFlowPdfExporter>()) {
    sl.registerLazySingleton<CashFlowPdfExporter>(
      () => const CashFlowPdfExporter(),
    );
  }

  if (!sl.isRegistered<CashFlowBloc>()) {
    sl.registerFactory<CashFlowBloc>(
      () => CashFlowBloc(
        repository: sl<CashFlowRepository>(),
        exporter: sl<CashFlowPdfExporter>(),
      ),
    );
  }

  if (!sl.isRegistered<TaxCopilotLocalDataSource>()) {
    sl.registerLazySingleton<TaxCopilotLocalDataSource>(
      () => TaxCopilotLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<LlmRemoteDataSource>()) {
    sl.registerLazySingleton<LlmRemoteDataSource>(
      () => LlmRemoteDataSourceImpl(
        sl<ApiClient>(),
        sl<SecureStorageService>(),
      ),
    );
  }

  if (!sl.isRegistered<TaxCopilotRepository>()) {
    sl.registerLazySingleton<TaxCopilotRepository>(
      () => TaxCopilotRepositoryImpl(
        sl<TaxCopilotLocalDataSource>(),
        sl<LlmRemoteDataSource>(),
      ),
    );
  }

  if (!sl.isRegistered<TaxCopilotBloc>()) {
    sl.registerFactory<TaxCopilotBloc>(
      () => TaxCopilotBloc(repository: sl<TaxCopilotRepository>()),
    );
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

  if (!sl.isRegistered<AppPreferences>()) {
    sl.registerLazySingleton<AppPreferences>(() => AppPreferences());
  }

  if (!sl.isRegistered<TaskQueueManager>()) {
    sl.registerSingleton<TaskQueueManager>(TaskQueueManager.instance);
  }

  if (!sl.isRegistered<AppShellController>()) {
    sl.registerSingleton<AppShellController>(AppShellController());
  }

  if (!sl.isRegistered<GlobalSearchDataSource>()) {
    sl.registerLazySingleton<GlobalSearchDataSource>(
      () => GlobalSearchDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<SearchRepository>()) {
    sl.registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(sl<GlobalSearchDataSource>()),
    );
  }

  if (!sl.isRegistered<SearchBloc>()) {
    sl.registerFactory<SearchBloc>(
      () => SearchBloc(repository: sl<SearchRepository>()),
    );
  }

  if (!sl.isRegistered<FtsSearchEngine>()) {
    sl.registerLazySingleton<FtsSearchEngine>(() => const FtsSearchEngine());
  }

  if (!sl.isRegistered<GlobalFtsDataSource>()) {
    sl.registerLazySingleton<GlobalFtsDataSource>(
      () => GlobalFtsDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<GlobalSearchRepository>()) {
    sl.registerLazySingleton<GlobalSearchRepository>(
      () => GlobalSearchRepositoryImpl(sl<GlobalFtsDataSource>()),
    );
  }

  if (!sl.isRegistered<GlobalSearchBloc>()) {
    sl.registerFactory<GlobalSearchBloc>(
      () => GlobalSearchBloc(repository: sl<GlobalSearchRepository>()),
    );
  }

  if (!sl.isRegistered<ConsolidationLocalDataSource>()) {
    sl.registerLazySingleton<ConsolidationLocalDataSource>(
      () => ConsolidationLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<EliminationEngine>()) {
    sl.registerLazySingleton<EliminationEngine>(
      () => const EliminationEngine(),
    );
  }

  if (!sl.isRegistered<ConsolidationRepository>()) {
    sl.registerLazySingleton<ConsolidationRepository>(
      () => ConsolidationRepositoryImpl(
        localDataSource: sl<ConsolidationLocalDataSource>(),
        companyRepository: sl<CompanyRepository>(),
        financialReportRepository: sl<FinancialReportRepository>(),
        eliminationEngine: sl<EliminationEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<ConsolidationBloc>()) {
    sl.registerFactory<ConsolidationBloc>(
      () => ConsolidationBloc(repository: sl<ConsolidationRepository>()),
    );
  }

  if (!sl.isRegistered<AssetLocalDataSource>()) {
    sl.registerLazySingleton<AssetLocalDataSource>(
      () => AssetLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<AssetDepreciationEngine>()) {
    sl.registerLazySingleton<AssetDepreciationEngine>(
      () => const AssetDepreciationEngine(),
    );
  }

  if (!sl.isRegistered<AssetRepository>()) {
    sl.registerLazySingleton<AssetRepository>(
      () => AssetRepositoryImpl(
        sl<AssetLocalDataSource>(),
        engine: sl<AssetDepreciationEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<AssetBloc>()) {
    sl.registerFactory<AssetBloc>(
      () => AssetBloc(repository: sl<AssetRepository>()),
    );
  }

  if (!sl.isRegistered<InventoryLocalDataSource>()) {
    sl.registerLazySingleton<InventoryLocalDataSource>(
      () => InventoryLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<InventoryValuationEngine>()) {
    sl.registerLazySingleton<InventoryValuationEngine>(
      () => const InventoryValuationEngine(),
    );
  }

  if (!sl.isRegistered<InventoryRepository>()) {
    sl.registerLazySingleton<InventoryRepository>(
      () => InventoryRepositoryImpl(
        sl<InventoryLocalDataSource>(),
        valuationEngine: sl<InventoryValuationEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<InventoryBloc>()) {
    sl.registerFactory<InventoryBloc>(
      () => InventoryBloc(repository: sl<InventoryRepository>()),
    );
  }

  if (!sl.isRegistered<IntercompanyLocalDataSource>()) {
    sl.registerLazySingleton<IntercompanyLocalDataSource>(
      () => IntercompanyLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<IntercompanyEngine>()) {
    sl.registerLazySingleton<IntercompanyEngine>(
      () => const IntercompanyEngine(),
    );
  }

  if (!sl.isRegistered<IntercompanyRepository>()) {
    sl.registerLazySingleton<IntercompanyRepository>(
      () => IntercompanyRepositoryImpl(
        sl<IntercompanyLocalDataSource>(),
        engine: sl<IntercompanyEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<IntercompanyBloc>()) {
    sl.registerFactory<IntercompanyBloc>(
      () => IntercompanyBloc(repository: sl<IntercompanyRepository>()),
    );
  }

  if (!sl.isRegistered<FxRevaluationLocalDataSource>()) {
    sl.registerLazySingleton<FxRevaluationLocalDataSource>(
      () => FxRevaluationLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<FxRevaluationEngine>()) {
    sl.registerLazySingleton<FxRevaluationEngine>(
      () => const FxRevaluationEngine(),
    );
  }

  if (!sl.isRegistered<FxRevaluationRepository>()) {
    sl.registerLazySingleton<FxRevaluationRepository>(
      () => FxRevaluationRepositoryImpl(
        sl<FxRevaluationLocalDataSource>(),
        sl<CurrencyRepository>(),
        engine: sl<FxRevaluationEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<FxRevaluationBloc>()) {
    sl.registerFactory<FxRevaluationBloc>(
      () => FxRevaluationBloc(repository: sl<FxRevaluationRepository>()),
    );
  }

  if (!sl.isRegistered<PayrollLocalDataSource>()) {
    sl.registerLazySingleton<PayrollLocalDataSource>(
      () => PayrollLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<PayrollEngine>()) {
    sl.registerLazySingleton<PayrollEngine>(() => const PayrollEngine());
  }

  if (!sl.isRegistered<PayrollRepository>()) {
    sl.registerLazySingleton<PayrollRepository>(
      () => PayrollRepositoryImpl(
        sl<PayrollLocalDataSource>(),
        engine: sl<PayrollEngine>(),
      ),
    );
  }

  if (!sl.isRegistered<PayrollBloc>()) {
    sl.registerFactory<PayrollBloc>(
      () => PayrollBloc(repository: sl<PayrollRepository>()),
    );
  }

  if (!sl.isRegistered<DeferredTaxLocalDataSource>()) {
    sl.registerLazySingleton<DeferredTaxLocalDataSource>(
      () => DeferredTaxLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<DeferredTaxRepository>()) {
    sl.registerLazySingleton<DeferredTaxRepository>(
      () => DeferredTaxRepositoryImpl(
        sl<DeferredTaxLocalDataSource>(),
        sl<FinancialReportRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<DeferredTaxBloc>()) {
    sl.registerFactory<DeferredTaxBloc>(
      () => DeferredTaxBloc(repository: sl<DeferredTaxRepository>()),
    );
  }

  if (!sl.isRegistered<TaxDeclarationLocalDataSource>()) {
    sl.registerLazySingleton<TaxDeclarationLocalDataSource>(
      () => TaxDeclarationLocalDataSourceImpl(sl<DatabaseService>()),
    );
  }

  if (!sl.isRegistered<TaxDeclarationRepository>()) {
    sl.registerLazySingleton<TaxDeclarationRepository>(
      () => TaxDeclarationRepositoryImpl(
        sl<TaxDeclarationLocalDataSource>(),
        sl<FinancialReportRepository>(),
        sl<CompanyRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<TaxXmlFileExporter>()) {
    sl.registerLazySingleton<TaxXmlFileExporter>(
      () => const TaxXmlFileExporter(),
    );
  }

  if (!sl.isRegistered<TaxDeclarationBloc>()) {
    sl.registerFactory<TaxDeclarationBloc>(
      () => TaxDeclarationBloc(
        repository: sl<TaxDeclarationRepository>(),
        exporter: sl<TaxXmlFileExporter>(),
      ),
    );
  }

  if (!sl.isRegistered<NotificationService>()) {
    sl.registerLazySingleton<NotificationService>(
      () => NotificationServiceImpl(appName: 'FinAI Studio'),
    );
  }

  if (!sl.isRegistered<SystemTrayService>()) {
    sl.registerLazySingleton<SystemTrayService>(
      () => SystemTrayServiceImpl(
        onShowWindow: () async {
          await windowManager.show();
          await windowManager.focus();
        },
        onQuickUpload: () =>
            sl<AppShellController>().select(AppSection.ocrInvoices),
        onRunAutoReconciliation: () =>
            sl<AppShellController>().select(AppSection.reconciliation),
        onExit: () async {
          await sl<DatabaseService>().close();
          await windowManager.destroy();
        },
      ),
    );
  }

  if (!sl.isRegistered<HotkeyService>()) {
    sl.registerLazySingleton<HotkeyService>(
      () => HotkeyService(preferences: sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<WindowsNativeBloc>()) {
    sl.registerLazySingleton<WindowsNativeBloc>(
      () => WindowsNativeBloc(
        hotkeyService: sl<HotkeyService>(),
        notificationService: sl<NotificationService>(),
        systemTrayService: sl<SystemTrayService>(),
        preferences: sl<AppPreferences>(),
        shellController: sl<AppShellController>(),
        onGlobalSearch: showGlobalCommandPalette,
      ),
    );
  }

  // The relational implementation is available on desktop and mobile. Web
  // can still boot and use the shell, but does not initialize native SQLite.
  if (!kIsWeb) {
    await sl<DatabaseService>().initialize();
    // Seed a default administrator so a fresh install is always signable.
    await sl<AuthRepository>().ensureDefaultAdmin();
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
