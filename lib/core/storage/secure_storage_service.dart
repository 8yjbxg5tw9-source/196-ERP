import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable keys for secrets kept outside ordinary application preferences.
abstract final class SecureStorageKeys {
  static const String authorizationToken = 'authorization_token';
  static const String refreshToken = 'refresh_token';
  static const String localAiApiKey = 'local_ai_api_key';
  static const String openAiApiKey = 'openai_api_key';
  static const String anthropicApiKey = 'anthropic_api_key';
  static const String llmProvider = 'llm_provider';
  static const String databaseEncryptionKey = 'database_encryption_key';
  static const String activeCompanyId = 'active_company_id';
  static const String authSessionToken = 'auth_session_token';
  static const String authUserId = 'auth_user_id';
  static const String authSessionSecret = 'auth_session_secret';
}

/// Platform-agnostic contract for sensitive key-value data.
abstract interface class SecureStorageService {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> clearAll();
}

/// Flutter Secure Storage implementation backed by the platform keychain,
/// encrypted preferences, or the platform equivalent.
class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> clearAll() {
    return _storage.deleteAll();
  }
}
