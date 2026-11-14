import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/token_storage.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final TokenStorage _storage;

  AuthProvider({required AuthService authService, required TokenStorage storage})
      : _authService = authService,
        _storage = storage;

  bool _initializing = true;
  bool _loading = false;
  bool _authenticated = false;
  String? _error;
  Map<String, dynamic>? _user;

  bool get initializing => _initializing;
  bool get loading => _loading;
  bool get authenticated => _authenticated;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;

  String get displayName {
    final value = _user?['nome'] ??
        _user?['name'] ??
        _user?['login'] ??
        _user?['usuario'] ??
        '';
    return value.toString();
  }

  Future<void> init() async {
    try {
      final token = await _storage.readToken();
      final rawUser = await _storage.readUser();
      if (token != null && token.isNotEmpty) {
        _authenticated = true;
        if (rawUser != null && rawUser.isNotEmpty) {
          final decoded = jsonDecode(rawUser);
          if (decoded is Map) {
            _user = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      await _storage.clear();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String login, String senha) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _authService.login(login, senha);
      _user = result.user;
      _authenticated = true;
      await _storage.writeToken(result.token);
      await _storage.writeUser(jsonEncode(result.user));
      return true;
    } catch (e) {
      _error = _messageFromError(e);
      _authenticated = false;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    _user = null;
    _authenticated = false;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.me();
      if (user != null) {
        _user = user;
        await _storage.writeUser(jsonEncode(user));
        notifyListeners();
      }
    } catch (_) {}
  }

  String _messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final message = map['message'] ?? map['mensagem'] ?? map['error'];
        if (message is String && message.isNotEmpty) return message;
        final errors = map['errors'];
        if (errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is String) return first;
          if (first is Map) {
            final text = first['message'] ?? first['mensagem'];
            if (text != null) return text.toString();
          }
        }
      }
      final status = error.response?.statusCode;
      if (status == 401) return 'Login ou senha inválidos.';
      if (status == 403) return 'Acesso negado.';
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Não foi possível conectar ao servidor.';
      }
      return 'Falha na conexão${status == null ? '' : ' ($status)'}.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
