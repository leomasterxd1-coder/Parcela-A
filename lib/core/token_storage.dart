import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _origemKey = 'origem_comercial';
  static const _usuarioIdKey = 'usuario_id';
  static const _savedLoginKey = 'saved_login';
  static const _savedPasswordKey = 'saved_password';

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

  Future<int?> readUsuarioId() async {
    final valor = await _storage.read(key: _usuarioIdKey);
    return int.tryParse(valor ?? '');
  }

  Future<void> writeUsuarioId(int id) =>
      _storage.write(key: _usuarioIdKey, value: id.toString());

  Future<void> clearUsuarioId() => _storage.delete(key: _usuarioIdKey);

  Future<String?> readSavedLogin() => _storage.read(key: _savedLoginKey);

  Future<String?> readSavedPassword() =>
      _storage.read(key: _savedPasswordKey);

  Future<void> writeSavedCredentials(String login, String senha) async {
    await _storage.write(key: _savedLoginKey, value: login);
    await _storage.write(key: _savedPasswordKey, value: senha);
  }

  Future<void> clearSavedCredentials() async {
    await _storage.delete(key: _savedLoginKey);
    await _storage.delete(key: _savedPasswordKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _origemKey);
    await _storage.delete(key: _usuarioIdKey);
  }
}
