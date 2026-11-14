import 'package:dio/dio.dart';

import '../core/api_client.dart';

class OrigemComercial {
  final int id;
  final String nome;

  const OrigemComercial({required this.id, required this.nome});

  factory OrigemComercial.fromJson(Map<String, dynamic> json) {
    return OrigemComercial(
      id: _int(json['id']) ?? 0,
      nome: _string(
        json['descricao'] ??
            json['nome'] ??
            json['fantasia'] ??
            json['titulo'] ??
            json['razaoSocial'],
      ),
    );
  }
}

class Produto {
  final int id;
  final String titulo;
  final String codigoExterno;

  const Produto({
    required this.id,
    required this.titulo,
    required this.codigoExterno,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: _int(json['id']) ?? 0,
      titulo: _string(json['titulo'] ?? json['nome'] ?? json['descricao']),
      codigoExterno: _string(json['codigoExterno']),
    );
  }
}

class CatalogoService {
  final Dio _dio;

  CatalogoService(ApiClient client) : _dio = client.dio;

  Future<List<OrigemComercial>> origens() async {
    final response = await _dio.get<dynamic>(
      '/gerencial/origens-comerciais',
      queryParameters: {'page': 0, 'size': 100, 'ativo': true},
    );
    final list = _extractList(response.data);
    return list
        .whereType<Map>()
        .map((e) => OrigemComercial.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id > 0)
        .toList();
  }

  Future<List<Produto>> produtos({required int origemComercialId}) async {
    final response = await _dio.get<dynamic>(
      '/gerencial/produtos',
      queryParameters: {
        'page': 0,
        'size': 100,
        'ativo': true,
        'origensComerciaisIds': origemComercialId,
      },
    );
    final list = _extractList(response.data);
    return list
        .whereType<Map>()
        .map((e) => Produto.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id > 0)
        .toList();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final content = map['content'] ?? map['data'] ?? map['items'];
      if (content is List) return content;
      if (content is Map) {
        final nested = content['content'] ?? content['items'];
        if (nested is List) return nested;
      }
    }
    return const [];
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
