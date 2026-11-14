class CampoColeta {
  final int? id;
  final String codigo;
  final String titulo;
  final bool obrigatorio;
  final String tipo;
  final String? mascara;
  final List<CampoOpcao> opcoes;
  final String valorInicial;

  const CampoColeta({
    this.id,
    required this.codigo,
    required this.titulo,
    required this.obrigatorio,
    required this.tipo,
    this.mascara,
    required this.opcoes,
    required this.valorInicial,
  });

  factory CampoColeta.fromJson(Map<String, dynamic> json) {
    final atributos = _map(json['atributos']) ?? <String, dynamic>{};
    final respostas = json['respostas'];
    return CampoColeta(
      id: _int(json['id']),
      codigo: _string(json['codigo']),
      titulo: _string(
        json['titulo'] ?? json['nome'] ?? json['descricao'] ?? json['codigo'],
      ),
      obrigatorio: _bool(atributos['obrigatorio'] ?? json['obrigatorio']),
      tipo: _string(
        json['tipo'] ??
            atributos['tipo'] ??
            atributos['textoModoEntrada'] ??
            'texto',
      ),
      mascara: _stringOrNull(atributos['textoMascara'] ?? json['mascara']),
      opcoes: _parseOpcoes(
        json['opcoes'] ??
            json['valores'] ??
            atributos['opcoes'] ??
            atributos['valores'],
      ),
      valorInicial: _valorInicial(respostas, json['valor']),
    );
  }

  bool get isDropdown => opcoes.isNotEmpty;
  bool get isDate => tipo.toLowerCase().contains('data');
}

class CampoOpcao {
  final String valor;
  final String label;

  const CampoOpcao({required this.valor, required this.label});
}

List<CampoColeta> extrairCampos(dynamic data) {
  final result = <CampoColeta>[];
  final vistos = <String>{};
  void visit(dynamic value) {
    if (value is List) {
      for (final item in value) {
        visit(item);
      }
      return;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final campos = map['campos'];
      if (campos is List) {
        for (final campo in campos) {
          if (campo is Map) {
            final parsed = CampoColeta.fromJson(
              Map<String, dynamic>.from(campo),
            );
            if (parsed.codigo.isNotEmpty && vistos.add(parsed.codigo)) {
              result.add(parsed);
            }
          }
        }
      }
      final grupos = map['grupos'];
      if (grupos is List) visit(grupos);
      final subgrupos = map['subgrupos'];
      if (subgrupos is List) visit(subgrupos);
    }
  }

  visit(data);
  return result;
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _stringOrNull(dynamic value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'sim';
}

String _valorInicial(dynamic respostas, dynamic valor) {
  if (respostas is List && respostas.isNotEmpty) {
    final first = respostas.first;
    if (first is Map) {
      return _string(first['valor'] ?? first['valorVisual']);
    }
    return _string(first);
  }
  return _string(valor);
}

List<CampoOpcao> _parseOpcoes(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          return CampoOpcao(
            valor: _string(map['valor'] ?? map['value'] ?? map['codigo']),
            label: _string(
              map['label'] ?? map['titulo'] ?? map['descricao'] ?? map['valor'],
            ),
          );
        }
        final text = _string(item);
        return CampoOpcao(valor: text, label: text);
      })
      .where((e) => e.valor.isNotEmpty)
      .toList();
}
