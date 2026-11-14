class PropostaCliente {
  final String nome;
  final String documento;

  const PropostaCliente({required this.nome, required this.documento});

  factory PropostaCliente.fromJson(Map<String, dynamic> json) {
    return PropostaCliente(
      nome: _string(json['nome'] ?? json['clienteNome'] ?? json['name']),
      documento: _string(
        json['documento'] ?? json['cpf'] ?? json['cnpj'] ?? json['document'],
      ),
    );
  }

  static PropostaCliente empty() =>
      const PropostaCliente(nome: '', documento: '');
}

class PropostaEtapa {
  final int? id;
  final String nome;
  final String codigo;
  final String status;
  final String observacao;

  const PropostaEtapa({
    this.id,
    required this.nome,
    required this.codigo,
    required this.status,
    required this.observacao,
  });

  factory PropostaEtapa.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PropostaEtapa.empty();
    return PropostaEtapa(
      id: _int(json['id']),
      nome: _string(json['nome']),
      codigo: _string(json['codigo']),
      status: _string(json['status']),
      observacao: _string(json['observacao']),
    );
  }

  factory PropostaEtapa.empty() => const PropostaEtapa(
        nome: '',
        codigo: '',
        status: '',
        observacao: '',
      );
}

class PropostaOrigem {
  final int? id;
  final String nome;

  const PropostaOrigem({this.id, required this.nome});

  factory PropostaOrigem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PropostaOrigem(nome: '');
    return PropostaOrigem(
      id: _int(json['id']),
      nome: _string(
        json['descricao'] ??
            json['nome'] ??
            json['fantasia'] ??
            json['razaoSocial'] ??
            json['titulo'],
      ),
    );
  }
}

class Proposta {
  final int id;
  final String status;
  final PropostaCliente cliente;
  final DateTime? data;
  final PropostaOrigem origem;
  final PropostaEtapa etapaAtual;
  final Map<String, dynamic> raw;

  const Proposta({
    required this.id,
    required this.status,
    required this.cliente,
    required this.data,
    required this.origem,
    required this.etapaAtual,
    required this.raw,
  });

  factory Proposta.fromJson(Map<String, dynamic> json) {
    final clienteJson = _map(json['cliente']);
    final etapaJson = _map(json['etapaAtual']);
    final origemJson = _map(json['origemComercial'] ?? json['origem']);
    return Proposta(
      id: _int(json['id']) ?? 0,
      status: _string(json['status']),
      cliente: clienteJson == null
          ? PropostaCliente.empty()
          : PropostaCliente.fromJson(clienteJson),
      data: _date(_first(json, const [
        'data',
        'dataCadastro',
        'dataHora',
        'dataCriacao',
        'criadoEm',
        'createdAt',
      ])),
      origem: PropostaOrigem.fromJson(origemJson),
      etapaAtual: PropostaEtapa.fromJson(etapaJson),
      raw: json,
    );
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'REPROVADO':
        return 'Proposta reprovada';
      case 'APROVADO':
        return 'Proposta aprovada';
      case 'EXPIRADO':
        return 'Proposta expirada';
      case 'EM_ANDAMENTO':
        if (etapaAtual.status.toUpperCase() == 'PREENCHIMENTO') {
          return 'Aguardando preenchimento';
        }
        return 'Em análise';
      case 'EM_PREENCHIMENTO':
        return 'Aguardando preenchimento';
      case 'CORRECAO':
        return 'Aguardando correção';
      case 'INCONSISTENTE':
        return 'Em análise';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  bool get isReprovada => status.toUpperCase() == 'REPROVADO';
  bool get isAprovada => status.toUpperCase() == 'APROVADO';
  bool get isAguardandoPreenchimento =>
      statusLabel == 'Aguardando preenchimento';

  String get motivoReprovacao {
    if (etapaAtual.observacao.isNotEmpty) return etapaAtual.observacao;
    return _string(raw['observacao'] ?? raw['motivo'] ?? raw['mensagem']);
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

dynamic _first(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
