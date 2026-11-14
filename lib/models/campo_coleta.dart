class CampoColeta {
  final int? id;
  final String codigo;
  final String titulo;
  final String descricao;
  final bool obrigatorio;
  final bool oculto;
  final int ordem;
  final String tipo;
  final String? mascara;
  final String modoEntrada;
  final List<CampoOpcao> opcoes;
  final String valorInicial;

  const CampoColeta({
    this.id,
    required this.codigo,
    required this.titulo,
    required this.descricao,
    required this.obrigatorio,
    required this.oculto,
    required this.ordem,
    required this.tipo,
    this.mascara,
    required this.modoEntrada,
    required this.opcoes,
    required this.valorInicial,
  });

  factory CampoColeta.fromJson(Map<String, dynamic> json) {
    final atributos = _parseAtributos(json['atributos']);
    final respostas = json['respostas'];
    return CampoColeta(
      id: _int(json['id']),
      codigo: _string(json['codigo']),
      titulo: _string(
        json['titulo'] ?? json['nome'] ?? json['descricao'] ?? json['codigo'],
      ),
      descricao: _string(json['descricao']),
      obrigatorio: _bool(
        atributos['OBRIGATORIEDADE'] ??
            atributos['obrigatorio'] ??
            json['obrigatorio'],
      ),
      oculto: _bool(atributos['OCULTO'] ?? atributos['oculto'] ?? false),
      ordem: _int(atributos['ORDEM'] ?? atributos['ordem']) ?? 999999,
      tipo: _string(
        json['tipo'] ??
            atributos['TIPO'] ??
            atributos['tipo'] ??
            atributos['textoModoEntrada'] ??
            'texto',
      ),
      mascara: _stringOrNull(
        atributos['MASCARA'] ??
            atributos['textoMascara'] ??
            json['mascara'],
      ),
      modoEntrada: _string(
        atributos['MODO_ENTRADA'] ??
            atributos['modoEntrada'] ??
            atributos['textoModoEntrada'],
      ),
      opcoes: _parseOpcoes(
        json['opcoes'] ??
            json['valores'] ??
            atributos['opcoes'] ??
            atributos['valores'],
      ),
      valorInicial: _valorInicial(
        respostas,
        json['valor'] ?? atributos['VALOR_PADRAO'],
      ),
    );
  }

  bool get isDropdown => opcoes.isNotEmpty;
  bool get isDate => tipo.toLowerCase() == 'data';
  bool get isNumeric =>
      tipo.toLowerCase() == 'numerico' ||
      modoEntrada.toLowerCase() == 'numeric';
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
      final wrapped = map['data'] ?? map['conteudo'];
      if (wrapped is List || wrapped is Map) visit(wrapped);
      final campos = map['campos'];
      if (campos is List) {
        final doGrupo = <MapEntry<int, CampoColeta>>[];
        var posicao = 0;
        for (final campo in campos) {
          if (campo is Map) {
            final parsed = CampoColeta.fromJson(
              Map<String, dynamic>.from(campo),
            );
            if (parsed.codigo.isNotEmpty && vistos.add(parsed.codigo)) {
              doGrupo.add(MapEntry(posicao++, parsed));
            }
          }
        }
        doGrupo.sort((a, b) {
          final byOrder = a.value.ordem.compareTo(b.value.ordem);
          if (byOrder != 0) return byOrder;
          return a.key.compareTo(b.key);
        });
        result.addAll(doGrupo.map((entry) => entry.value));
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

Map<String, dynamic> _parseAtributos(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List) {
    final map = <String, dynamic>{};
    for (final item in value) {
      if (item is Map) {
        final atributo = Map<String, dynamic>.from(item);
        final propriedade = _string(atributo['propriedade']);
        if (propriedade.isNotEmpty) {
          map[propriedade] = atributo['valor'];
        }
      }
    }
    return map;
  }
  return <String, dynamic>{};
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
