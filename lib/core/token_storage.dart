import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _origemKey = 'origem_comercial';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readUser() => _storage.read(key: _userKey);

  Future<void> writeUser(String json) =>
      _storage.write(key: _userKey, value: json);

  Future<String?> readOrigem() => _storage.read(key: _origemKey);

  Future<void> writeOrigem(String json) =>
      _storage.write(key: _origemKey, value: json);

  Future<void> clearOrigem() => _storage.delete(key: _origemKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _origemKey);
  }
}
