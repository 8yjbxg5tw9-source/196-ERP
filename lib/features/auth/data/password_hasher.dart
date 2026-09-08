import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The salt + derived key produced for one password.
class SaltedPasswordHash {
  const SaltedPasswordHash({required this.salt, required this.hash});

  final String salt;
  final String hash;
}

/// PBKDF2-HMAC-SHA256 password hashing.
///
/// Passwords are never persisted in plain text. Each user gets a fresh random
/// salt and the derived key is stored alongside it in the `users` table.
class PasswordHasher {
  const PasswordHasher({this.iterations = 120000});

  static const int _keyLength = 32;
  static const int _saltLength = 16;

  /// Cost factor for the key-derivation function.
  final int iterations;

  SaltedPasswordHash hash(String password) {
    final Uint8List salt = _randomBytes(_saltLength);
    final Uint8List derived = _pbkdf2(
      Uint8List.fromList(utf8.encode(password)),
      salt,
      iterations,
    );
    return SaltedPasswordHash(
      salt: base64.encode(salt),
      hash: base64.encode(derived),
    );
  }

  bool verify(String password, String salt, String expectedHash) {
    final Uint8List derived = _pbkdf2(
      Uint8List.fromList(utf8.encode(password)),
      base64.decode(salt),
      iterations,
    );
    return _constantTimeEquals(base64.encode(derived), expectedHash);
  }

  static Uint8List _pbkdf2(
    Uint8List password,
    Uint8List salt,
    int iterations,
  ) {
    final Hmac hmac = Hmac(sha256, password);
    Uint8List block = Uint8List.fromList(
      hmac.convert(<int>[...salt, 0, 0, 0, 1]).bytes,
    );
    final Uint8List result = Uint8List.fromList(block);
    for (int iteration = 1; iteration < iterations; iteration++) {
      block = Uint8List.fromList(hmac.convert(block).bytes);
      for (int index = 0; index < _keyLength; index++) {
        result[index] ^= block[index];
      }
    }
    return result;
  }

  static Uint8List _randomBytes(int length) {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (int _) => random.nextInt(256)),
    );
  }

  static bool _constantTimeEquals(String left, String right) {
    final List<int> leftBytes = utf8.encode(left);
    final List<int> rightBytes = utf8.encode(right);
    if (leftBytes.length != rightBytes.length) {
      return false;
    }
    int difference = 0;
    for (int index = 0; index < leftBytes.length; index++) {
      difference |= leftBytes[index] ^ rightBytes[index];
    }
    return difference == 0;
  }
}
