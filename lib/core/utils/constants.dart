/// Stable application constants shared by infrastructure and features.
abstract final class AppConstants {
  static const String appName = 'FinAI Studio';
  static const String authTokenKey = 'auth_token';
  static const String selectedWorkspaceKey = 'selected_workspace';

  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
