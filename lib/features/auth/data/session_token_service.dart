import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/entities/user_entity.dart';

/// Issues and validates compact HS256 JSON Web Tokens for local sessions.
///
/// The signing secret lives in platform secure storage (generated on first
/// run), so tokens remain verifiable across app restarts without shipping a
/// hard-coded key.
class SessionTokenService {
  SessionTokenService(this._secureStorage);

  static const Duration _validity = Duration(days: 30);

  final SecureStorageService _secureStorage;

  Future<String> issue(UserEntity user) async {
    final String secret = await _loadOrCreateSecret();
    final DateTime now = DateTime.now().toUtc();
    final Map<String, Object> payload = <String, Object>{
      'sub': user.id,
      'username': user.username,
      'role': user.role.name,
      'iat': now.millisecondsSinceEpoch,
      'exp': now.add(_validity).millisecondsSinceEpoch,
    };
    final String encodedHeader = _base64Url(
      jsonEncode(<String, String>{'alg': 'HS256', 'typ': 'JWT'}),
    );
    final String encodedPayload = _base64Url(jsonEncode(payload));
    final String signingInput = '$encodedHeader.$encodedPayload';
    return '$signingInput.${_signature(signingInput, secret)}';
  }

  Future<bool> verify(String token) async {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return false;
    }
    final String secret = await _loadOrCreateSecret();
    final String signingInput = '${parts[0]}.${parts[1]}';
    if (_signature(signingInput, secret) != parts[2]) {
      return false;
    }
    final Map<String, dynamic> payload = _decodePayload(parts[1]);
    final Object? expiry = payload['exp'];
    if (expiry is int && expiry < DateTime.now().toUtc().millisecondsSinceEpoch) {
      return false;
    }
    return true;
  }

  Future<String?> subjectOf(String token) async {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    final Map<String, dynamic> payload = _decodePayload(parts[1]);
    final Object? subject = payload['sub'];
    return subject is String && subject.isNotEmpty ? subject : null;
  }

  Map<String, dynamic> _decodePayload(String encodedPayload) {
    final String normalized =
        '${encodedPayload.replaceAll('-', '+').replaceAll('_', '/')}'
        '${'=' * ((4 - encodedPayload.length % 4) % 4)}';
    final Map<String, dynamic> decoded = jsonDecode(
      utf8.decode(base64.decode(normalized)),
    ) as Map<String, dynamic>;
    return decoded;
  }

  String _signature(String input, String secret) {
    final Hmac hmac = Hmac(sha256, utf8.encode(secret));
    return base64Url.encode(hmac.convert(utf8.encode(input)).bytes).replaceAll(
          '=',
          '',
        );
  }

  Future<String> _loadOrCreateSecret() async {
    final String? existing =
        await _secureStorage.read(SecureStorageKeys.authSessionSecret);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String secret = _randomToken(32);
    await _secureStorage.write(SecureStorageKeys.authSessionSecret, secret);
    return secret;
  }

  static String _base64Url(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  static String _randomToken(int length) {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(length, (int _) => random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
