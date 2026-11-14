import 'package:dio/dio.dart';

import '../core/api_client.dart';

class OrigemComercial {
  final int id;
  final String nome;
  final String codigo;

  const OrigemComercial({
    required this.id,
    required this.nome,
    this.codigo = '',
  });

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
      codigo: _string(
        json['codigo'] ??
            json['codigoExterno'] ??
            json['numero'] ??
            json['numeroLoja'],
      ),
    );
  }

  String get label {
    if (nome.isNotEmpty) return nome;
    if (codigo.isNotEmpty) return 'Loja $codigo';
    return 'Loja $id';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'codigo': codigo,
      };
}

class MinhasLojas {
  final int? usuarioId;
  final List<OrigemComercial> lojas;

  const MinhasLojas({this.usuarioId, required this.lojas});
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

  Future<Map<int, String>> nomesOrigens(List<int> ids) async {
    if (ids.isEmpty) return {};
    final response = await _dio.get<dynamic>(
      '/gerencial/origens-comerciais/nome',
      queryParameters: {'ids': ids.join(',')},
    );
    final list = _extractList(response.data);
    final nomes = <int, String>{};
    for (final item in list) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final id = _int(map['id']);
        final nome = _string(map['nome']);
        if (id != null && nome.isNotEmpty) nomes[id] = nome;
      }
    }
    return nomes;
  }

  Future<MinhasLojas> minhasLojas() async {
    try {
      final response = await _dio.get<dynamic>(
        '/gerencial/usuarios/promotores/me',
      );
      final data = response.data;
      dynamic payload = data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        payload = map['data'] ?? map;
      }
      if (payload is Map) {
        final map = Map<String, dynamic>.from(payload);
        final origens = map['origensComerciais'];
        if (origens is List) {
          final list = origens
              .whereType<Map>()
              .map(
                (item) => OrigemComercial.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((e) => e.id > 0)
              .toList();
          if (list.isNotEmpty) {
            return MinhasLojas(
              usuarioId: _int(map['id']),
              lojas: list,
            );
          }
        }
      }
    } catch (_) {}
    return MinhasLojas(lojas: await origens());
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
