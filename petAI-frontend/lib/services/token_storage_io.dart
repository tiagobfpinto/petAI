import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth token securely on device.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = "token";

  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> deleteToken() {
    return _storage.delete(key: _tokenKey);
  }
}
