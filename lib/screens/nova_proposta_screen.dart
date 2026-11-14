import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../models/campo_coleta.dart';
import '../services/catalogo_service.dart';
import '../services/coleta_service.dart';
import '../services/proposta_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import 'preenchimento_proposta_screen.dart';

class NovaPropostaScreen extends StatefulWidget {
  final List<OrigemComercial> origens;
  final OrigemComercial? origemSelecionada;

  const NovaPropostaScreen({
    super.key,
    this.origens = const [],
    this.origemSelecionada,
  });

  @override
  State<NovaPropostaScreen> createState() => _NovaPropostaScreenState();
}

class _NovaPropostaScreenState extends State<NovaPropostaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _masks = <String, MaskTextInputFormatter>{};
  final _datas = <String, DateTime>{};
  int? _fluxoId;

  List<OrigemComercial> _origens = [];
  OrigemComercial? _origem;
  List<Produto> _produtos = [];
  Produto? _produto;
  List<CampoColeta> _campos = [];
  bool _carregando = true;
  bool _carregandoCampos = false;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _origens = widget.origens;
    _origem = widget.origemSelecionada;
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _inicializar() async {
    if (_origens.isEmpty) {
      try {
        _origens = await context.read<CatalogoService>().origens();
      } catch (_) {
        _origens = const [];
      }
    }
    if (_origem == null && _origens.isNotEmpty) {
      _origem = _origens.first;
    }
    await _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    final origem = _origem;
    if (origem == null) {
      setState(() {
        _carregando = false;
        _erro = 'Nenhuma origem comercial disponível.';
      });
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
      _produtos = [];
      _produto = null;
      _campos = [];
    });
    try {
      final produtos = await context
          .read<CatalogoService>()
          .produtos(origemComercialId: origem.id);
      if (!mounted) return;
      setState(() {
        _produtos = produtos;
        _produto = produtos.isNotEmpty ? produtos.first : null;
        _carregando = false;
      });
      if (_produto != null) {
        await _carregarCampos();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _carregarCampos() async {
    final origem = _origem;
    final produto = _produto;
    if (origem == null || produto == null) return;
    setState(() {
      _carregandoCampos = true;
      _erro = null;
    });
    try {
      final coleta = context.read<ColetaService>();
      final politica = await coleta.politicaIdeal(
        origemComercialId: origem.id,
        produtoId: produto.id,
      );
      final fluxoId = _int(politica['idFluxo'] ?? politica['fluxo']);
      if (fluxoId == null) {
        throw Exception('Fluxo não encontrado.');
      }
      _fluxoId = fluxoId;
      final fluxo = await coleta.fluxo(fluxoId);
      final etapaInicial = _map(fluxo['etapaInicial']);
      final etapaId = _int(etapaInicial?['id']);
      final parametros = etapaInicial?['parametros'];
      int? perfilId;
      if (parametros is List) {
        for (final item in parametros) {
          if (item is Map && item['codigo'] == 'COLETA') {
            perfilId = _int(item['valor']);
          }
        }
      }
      if (etapaId == null || perfilId == null) {
        throw Exception('Configuração de coleta não encontrada.');
      }
      final campos = await coleta.primeiraColeta(
        perfilId: perfilId,
        produtoId: produto.id,
        etapaId: etapaId,
      );
      if (!mounted) return;
      setState(() {
        _campos = campos;
        _montarControllers(campos);
        _carregandoCampos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregandoCampos = false;
      });
    }
  }

  void _montarControllers(List<CampoColeta> campos) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _masks.clear();
    _datas.clear();
    for (final campo in campos) {
      final controller = TextEditingController(text: campo.valorInicial);
      if (campo.isDate && controller.text.isNotEmpty) {
        final data = DateTime.tryParse(controller.text);
        if (data != null) {
          _datas[campo.codigo] = data;
          controller.text = DateFormat('dd/MM/yyyy').format(data);
        }
      }
      _controllers[campo.codigo] = controller;
      final mascara = campo.mascara;
      if (mascara != null && mascara.isNotEmpty) {
        _masks[campo.codigo] = MaskTextInputFormatter(mask: mascara);
      }
    }
  }

  Future<void> _enviar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final origem = _origem;
    final produto = _produto;
    if (origem == null || produto == null) return;

    final respostas = <Map<String, dynamic>>[];
    for (final campo in _campos) {
      final data = _datas[campo.codigo];
      final valor = data != null
          ? DateFormat('yyyy-MM-dd').format(data)
          : _controllers[campo.codigo]?.text.trim() ?? '';
      if (valor.isEmpty) continue;
      respostas.add({
        if (campo.id != null) 'campoId': campo.id,
        'campoCodigo': campo.codigo,
        'valor': valor,
        'ordem': '0',
      });
    }
    if (!respostas.any((e) => e['campoCodigo'] == 'proposta.origem')) {
      respostas.add({
        'campoCodigo': 'proposta.origem',
        'valor': AppConfig.origem,
        'ordem': '0',
      });
    }

    final documento = _valorPorCodigo(
      respostas,
      const ['pessoa.cpf', 'pessoa.cnpj', 'empresa.cnpj'],
    );
    final nome = _valorPorCodigo(respostas, const ['pessoa.nome']);
    if (documento.isEmpty || nome.isEmpty) {
      _mostrarErro('Informe o documento e o nome do cliente.');
      return;
    }

    setState(() => _enviando = true);
    var dialogOpen = true;
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Processando Proposta'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Aguardando análise...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                dialogOpen = false;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Aguardar em segundo-plano'),
            ),
          ],
        ),
      );
    }

    try {
      final propostas = context.read<PropostaService>();
      final validacao = await propostas.validarCliente(
        documento: documento,
        produtoId: produto.id,
        origemComercialId: origem.id,
        fluxo: _fluxoId,
      );
      if (validacao['cadastrado'] == true ||
          validacao['restricao'] == true ||
          validacao['cartaoAdicional'] == true) {
        throw Exception(
          validacao['mensagem']?.toString() ??
              'Cliente não elegível para esta proposta.',
        );
      }

      final result = await propostas.iniciarProposta({
        'clienteDocumento': documento,
        'clienteNome': nome,
        'respostas': respostas,
        'produto': produto.id,
        'origemComercial': origem.id,
        'origem': AppConfig.origem,
      });

      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      final id = result['id'] ?? result['propostaId'];
      if (id is int) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PreenchimentoPropostaScreen(propostaId: id),
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Proposta enviada'),
          content: const Text('A proposta foi criada com sucesso.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      _mostrarErro(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _valorPorCodigo(
    List<Map<String, dynamic>> respostas,
    List<String> codigos,
  ) {
    for (final codigo in codigos) {
      for (final resposta in respostas) {
        if (resposta['campoCodigo'] == codigo) {
          return resposta['valor']?.toString() ?? '';
        }
      }
    }
    return '';
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.red, content: Text(mensagem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-Proposta'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    const BrandMark(size: 76),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _origem?.nome ?? 'Origem comercial',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_origens.length > 1)
                  DropdownButtonFormField<OrigemComercial>(
                    initialValue: _origem,
                    decoration: const InputDecoration(
                      labelText: 'Origem Comercial',
                    ),
                    items: _origens
                        .map(
                          (origem) => DropdownMenuItem(
                            value: origem,
                            child: Text(origem.nome),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _origem = value);
                      _carregarProdutos();
                    },
                  ),
                const SizedBox(height: 12),
                if (_produtos.isNotEmpty)
                  DropdownButtonFormField<Produto>(
                    initialValue: _produto,
                    decoration: const InputDecoration(labelText: 'Produto'),
                    items: _produtos
                        .map(
                          (produto) => DropdownMenuItem(
                            value: produto,
                            child: Text(produto.titulo),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _produto = value);
                      _carregarCampos();
                    },
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Pré-proposta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 12),
                if (_carregandoCampos)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_erro != null)
                  _erroWidget()
                else if (_campos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Nenhum campo de coleta encontrado.'),
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        ..._campos.map(_campo),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _enviando ? null : _enviar,
                            child: _enviando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enviar'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _erroWidget() {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.error_outline, size: 48, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(_erro!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _carregarCampos,
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _campo(CampoColeta campo) {
    if (campo.oculto) return const SizedBox.shrink();
    final controller = _controllers[campo.codigo];
    if (controller == null) return const SizedBox.shrink();
    final label = campo.titulo.isEmpty ? campo.codigo : campo.titulo;
    final obrigatorio = campo.obrigatorio;

    if (campo.isDropdown) {
      final opcoes = campo.opcoes
          .map(
            (opcao) => CampoOpcao(
              valor: _resolverPlaceholders(opcao.valor),
              label: _resolverPlaceholders(opcao.label),
            ),
          )
          .where((opcao) => opcao.valor.isNotEmpty)
          .toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: opcoes.any((opcao) => opcao.valor == controller.text)
              ? controller.text
              : null,
          decoration: InputDecoration(
            labelText: obrigatorio ? '$label *' : label,
          ),
          items: opcoes
              .map(
                (opcao) => DropdownMenuItem(
                  value: opcao.valor,
                  child: Text(opcao.label),
                ),
              )
              .toList(),
          onChanged: (value) => controller.text = value ?? '',
          validator: obrigatorio
              ? (value) => (value == null || value.isEmpty)
                  ? 'Selecione uma opção'
                  : null
              : null,
        ),
      );
    }

    if (campo.isDate) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selecionarData(campo, controller),
          decoration: InputDecoration(
            labelText: obrigatorio ? '$label *' : label,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          validator: obrigatorio
              ? (value) => (value == null || value.trim().isEmpty)
                  ? 'Campo obrigatório'
                  : null
              : null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: campo.isNumeric ||
                campo.codigo.contains('cpf') ||
                campo.codigo.contains('cnpj') ||
                campo.codigo.contains('telefone') ||
                campo.codigo.contains('numero')
            ? TextInputType.number
            : TextInputType.text,
        inputFormatters: _masks[campo.codigo] == null
            ? null
            : [_masks[campo.codigo]!],
        onChanged: campo.codigo.startsWith('pessoa.telefones.')
            ? (_) => setState(() {})
            : null,
        decoration: InputDecoration(
          labelText: obrigatorio ? '$label *' : label,
        ),
        validator: obrigatorio
            ? (value) => (value == null || value.trim().isEmpty)
                ? 'Campo obrigatório'
                : null
            : null,
      ),
    );
  }

  String _resolverPlaceholders(String texto) {
    var resultado = texto;
    for (final entry in _controllers.entries) {
      resultado = resultado.replaceAll(
        '{{${entry.key}}}',
        entry.value.text,
      );
    }
    return resultado;
  }

  Future<void> _selecionarData(
    CampoColeta campo,
    TextEditingController controller,
  ) async {
    final atual = _datas[campo.codigo];
    final hoje = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime(hoje.year - 25, hoje.month, hoje.day),
      firstDate: DateTime(1900),
      lastDate: hoje,
    );
    if (picked == null) return;
    _datas[campo.codigo] = picked;
    controller.text = DateFormat('dd/MM/yyyy').format(picked);
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
