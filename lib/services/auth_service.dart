import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

class AuthResult {
  final String token;
  final Map<String, dynamic> user;

  const AuthResult({required this.token, required this.user});

  String get displayName {
    return (user['nome'] ??
            user['name'] ??
            user['login'] ??
            user['usuario'] ??
            '')
        .toString();
  }
}

class AuthService {
  final Dio _dio;

  AuthService(ApiClient client) : _dio = client.dio;

  Future<AuthResult> login(String login, String senha) async {
    final response = await _dio.post<dynamic>(
      '/autenticacao/tokens',
      data: {'login': login, 'senha': senha},
    );
    final data = response.data;
    var token = _extractToken(data);
    if (token.isEmpty) {
      final header = response.headers.value('authorization') ??
          response.headers.value('x-auth-token');
      if (header != null) {
        token = header
            .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
            .trim();
      }
    }
    if (token.isEmpty) {
      throw Exception('Token não retornado pelo servidor.');
    }
    final user = _extractUser(data);
    return AuthResult(token: token, user: user);
  }

  Future<Map<String, dynamic>?> me() async {
    final response = await _dio.get<dynamic>('/autenticacao/usuarios/me');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['usuario'] ?? data['user'];
      if (nested is Map<String, dynamic>) return nested;
      return data;
    }
    return null;
  }

  String _extractToken(dynamic data) {
    if (data is String) return data.trim();
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final direct = map['token'] ??
          map['accessToken'] ??
          map['access_token'] ??
          map['idToken'];
      if (direct is String && direct.isNotEmpty) return direct;
      final dataField = map['data'];
      if (dataField is String && dataField.isNotEmpty) return dataField;
      final nested = dataField ?? map['auth'] ?? map['usuario'];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        final nestedToken = nestedMap['token'] ??
            nestedMap['accessToken'] ??
            nestedMap['access_token'];
        if (nestedToken is String && nestedToken.isNotEmpty) return nestedToken;
        final nestedData = nestedMap['data'];
        if (nestedData is String && nestedData.isNotEmpty) return nestedData;
      }
    }
    return '';
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['usuario'] ?? map['user'] ?? map['data'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return map;
    }
    return <String, dynamic>{};
  }

  String encodeUser(Map<String, dynamic> user) => jsonEncode(user);
}
