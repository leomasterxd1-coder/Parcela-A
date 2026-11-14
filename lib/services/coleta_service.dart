import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../models/campo_coleta.dart';

class ColetaService {
  final Dio _dio;

  ColetaService(ApiClient client) : _dio = client.dio;

  Future<Map<String, dynamic>> politicaIdeal({
    required int origemComercialId,
    required int produtoId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/gerencial/politicas/ideal',
      queryParameters: {
        'origemComercialId': origemComercialId,
        'produtoId': produtoId,
        'origem': AppConfig.origem,
      },
    );
    return _map(response.data) ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fluxo(int fluxoId) async {
    final response = await _dio.get<dynamic>('/fluxo/fluxos/$fluxoId');
    return _map(response.data) ?? <String, dynamic>{};
  }

  Future<List<CampoColeta>> primeiraColeta({
    required int perfilId,
    required int produtoId,
    required int etapaId,
    String? codigoPerfil,
    int? processo,
  }) async {
    final response = await _dio.get<dynamic>(
      '/coleta/grupos/respondidos',
      queryParameters: {
        'idPerfil': perfilId,
        if (codigoPerfil != null && codigoPerfil.isNotEmpty)
          'codigoPerfil': codigoPerfil,
        if (processo != null) 'processo': processo,
        'etapa': etapaId,
        'configuracaoAtributo': 'etapa=$etapaId,produto=$produtoId',
      },
    );
    return extrairCampos(response.data);
  }

  Future<void> validarRespostas(List<Map<String, dynamic>> respostas) async {
    if (respostas.isEmpty) return;
    await _dio.post<dynamic>(
      '/coleta/respostas/validacao/lista',
      data: respostas,
    );
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      final nested = value['data'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return value;
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
