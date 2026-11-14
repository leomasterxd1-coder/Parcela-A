import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../models/proposta.dart';

class PropostaService {
  final Dio _dio;

  PropostaService(ApiClient client) : _dio = client.dio;

  Future<List<Proposta>> listar({
    bool minhas = false,
    String? id,
    String? documento,
    String? status,
    DateTime? dataInicial,
    DateTime? dataFinal,
    int? origemComercialId,
    int? usuarioId,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      'sort': 'id,desc',
    };
    if (id != null && id.trim().isNotEmpty) {
      params['id'] = id.trim();
    }
    if (documento != null && documento.trim().isNotEmpty) {
      params['documento'] = documento.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (dataInicial != null) {
      params['dataInicial'] = _dateParam(dataInicial);
    }
    if (dataFinal != null) {
      params['dataFinal'] = _dateParam(dataFinal);
    }
    if (usuarioId != null) {
      params['usuario'] = usuarioId;
    }

    final path = minhas && origemComercialId != null
        ? '/proposta/propostas/minhas/origens-comerciais'
        : '/proposta/propostas';

    if (minhas && origemComercialId != null) {
      params['origemComercial'] = origemComercialId;
    }

    final response = await _dio.get<dynamic>(path, queryParameters: params);
    final data = response.data;
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map((item) => Proposta.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Proposta> buscar(int id) async {
    final response = await _dio.get<dynamic>('/proposta/propostas/$id');
    final data = response.data;
    final map = _extractMap(data);
    if (map == null) {
      throw Exception('Proposta não encontrada.');
    }
    return Proposta.fromJson(map);
  }

  Future<Map<String, dynamic>> validarCliente({
    required String documento,
    required int produtoId,
    required int origemComercialId,
    int? fluxo,
    String? fluxoIdentificador,
  }) async {
    final response = await _dio.post<dynamic>(
      '/proposta/propostas/cliente/validacao',
      data: {
        'origemComercialId': origemComercialId,
        'produtoId': produtoId,
        'cpf': documento,
        'origem': AppConfig.origem,
        if (fluxo != null) 'fluxo': fluxo,
        if (fluxoIdentificador != null) 'fluxoIdentificador': fluxoIdentificador,
      },
    );
    return _extractMap(response.data) ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> iniciarProposta(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<dynamic>(
      '/proposta/propostas/inicio',
      data: payload,
    );
    return _extractMap(response.data) ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> enviarColeta(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<dynamic>(
      '/proposta/captacoes',
      data: payload,
    );
    return _extractMap(response.data) ?? <String, dynamic>{};
  }

  Future<void> reenviarSms(int propostaId, {bool limitar = false}) async {
    await _dio.post<dynamic>(
      '/proposta/propostas/$propostaId/reenviar-sms',
      queryParameters: {'limitar': limitar.toString()},
      data: const <String, dynamic>{},
    );
  }

  Future<List<dynamic>> enviosSms(int propostaId) async {
    final response = await _dio.get<dynamic>(
      '/proposta/propostas/$propostaId/envios-sms',
    );
    final data = response.data;
    if (data is List) return data;
    if (data is Map) {
      final list = data['content'] ?? data['data'];
      if (list is List) return list;
    }
    return const [];
  }

  Future<void> enviarTokenSms({
    required String phoneNumber,
    required int propostaId,
    required String propostaUUID,
    required String stepName,
  }) async {
    await _dio.post<dynamic>(
      '/tokendispatcher/token',
      data: {
        'phoneNumber': phoneNumber,
        'propostaId': propostaId,
        'propostaUUID': propostaUUID,
        'stepName': stepName,
      },
    );
  }

  String _dateParam(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['proposta'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return data;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
