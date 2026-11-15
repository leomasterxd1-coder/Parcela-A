import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../models/campo_coleta.dart';
import '../models/proposta.dart';
import '../services/coleta_service.dart';
import '../services/proposta_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/status_badge.dart';

class PreenchimentoPropostaScreen extends StatefulWidget {
  final int propostaId;

  const PreenchimentoPropostaScreen({super.key, required this.propostaId});

  @override
  State<PreenchimentoPropostaScreen> createState() =>
      _PreenchimentoPropostaScreenState();
}

class _PreenchimentoPropostaScreenState
    extends State<PreenchimentoPropostaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _masks = <String, MaskTextInputFormatter>{};
  final _datas = <String, DateTime>{};
  final _valoresAnteriores = <String, String>{};
  List<({String ddd, String numero, String tipo})> _telefones = [];
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _segundosReenvio = 180;

  Proposta? _proposta;
  List<CampoColeta> _campos = [];
  bool _carregando = true;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focus in _otpFocus) {
      focus.dispose();
    }
    super.dispose();
  }

  PropostaEtapa? get _etapa => _proposta?.etapaAtual;

  bool get _isSmsStep {
    final nome = _etapa?.nome.toLowerCase() ?? '';
    return nome.contains('token') || nome.contains('aceite');
  }

  bool get _finalizada {
    final status = _proposta?.status.toUpperCase() ?? '';
    return status == 'REPROVADO' ||
        status == 'APROVADO' ||
        status == 'EXPIRADO';
  }

  List<CampoColeta> get _camposTelefone => _campos
      .where(
        (campo) =>
            campo.codigo == 'pessoa.telefones.ddd' ||
            campo.codigo == 'pessoa.telefones.numero' ||
            campo.codigo == 'pessoa.telefones.tipo',
      )
      .toList();

  List<CampoColeta> get _camposSms => _campos
      .where((campo) => campo.codigo == 'pessoa.celular.sms')
      .toList();

  List<CampoColeta> get _camposOutros => _campos
      .where(
        (campo) =>
            !campo.oculto &&
            !_camposTelefone.contains(campo) &&
            !_camposSms.contains(campo),
      )
      .toList();

  void _adicionarTelefone() {
    final ddd = _somenteDigitos(_valor('pessoa.telefones.ddd'));
    final numero = _somenteDigitos(_valor('pessoa.telefones.numero'));
    final tipo = _valor('pessoa.telefones.tipo');
    if (ddd.isEmpty || numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha DDD e Número.')),
      );
      return;
    }
    setState(() {
      _telefones = [
        (
          ddd: ddd,
          numero: numero,
          tipo: tipo.isEmpty ? 'CELULAR' : tipo,
        ),
      ];
      _controllers['pessoa.celular.sms']?.text = '$ddd$numero';
    });
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final propostas = context.read<PropostaService>();
      final coletaService = context.read<ColetaService>();
      final proposta = await propostas.buscar(widget.propostaId);
      final etapa = proposta.etapaAtual;
      final produtoId = proposta.produtoId;
      final etapaId = etapa.id;
      final perfilId = etapa.coleta;
      final configuracao = etapa.configuracao;
      if (produtoId == null ||
          etapaId == null ||
          perfilId == null ||
          configuracao == null) {
        throw Exception('Configuração da etapa não encontrada.');
      }

      final anteriores = await coletaService.respostasPorCodigos(
        widget.propostaId,
        const [
          'pessoa.telefones.ddd',
          'pessoa.telefones.numero',
          'pessoa.celular.sms',
        ],
      );

      final campos = proposta.status.toUpperCase() == 'REPROVADO' ||
              proposta.status.toUpperCase() == 'APROVADO' ||
              proposta.status.toUpperCase() == 'EXPIRADO'
          ? <CampoColeta>[]
          : await coletaService.coletaProposta(
              propostaId: widget.propostaId,
              produtoId: produtoId,
              etapaId: etapaId,
              etapaConfiguracaoId: configuracao,
              perfilId: perfilId,
            );

      if (!mounted) return;
      setState(() {
        _proposta = proposta;
        _campos = campos;
        _valoresAnteriores
          ..clear()
          ..addAll(anteriores);
        _montarControllers(campos);
        _carregando = false;
        if (_isSmsStep) {
          for (final controller in _otpControllers) {
            controller.clear();
          }
        }
      });

      if (_isSmsStep && !_finalizada) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarContagem());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
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
      final inicial = campo.codigo == 'termo.aceite.token.sms'
          ? ''
          : campo.valorInicial.isNotEmpty
              ? campo.valorInicial
              : _valoresAnteriores[campo.codigo] ?? '';
      final controller = TextEditingController(text: inicial);
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
    final proposta = _proposta;
    final etapa = _etapa;
    if (proposta == null || etapa == null) return;
    if (_camposTelefone.isNotEmpty && _telefones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos 1 telefone.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final respostas = <Map<String, dynamic>>[];
    for (final campo in _campos) {
      final data = _datas[campo.codigo];
      final valor = data != null
          ? DateFormat('yyyy-MM-dd').format(data)
          : _normalizarValor(
              campo,
              _controllers[campo.codigo]?.text.trim() ?? '',
            );
      if (valor.isEmpty) continue;
      respostas.add({
        if (campo.id != null) 'campoId': campo.id,
        'campoCodigo': campo.codigo,
        'valor': valor,
        'ordem': '0',
      });
    }

    setState(() => _enviando = true);
    try {
      await context.read<PropostaService>().enviarColeta({
        'propostaId': proposta.id,
        'etapaId': etapa.id,
        'respostas': respostas,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etapa enviada com sucesso.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarToken() async {
    final proposta = _proposta;
    final etapa = _etapa;
    if (proposta == null || etapa == null) return;
    final ddd = _somenteDigitos(_valor('pessoa.telefones.ddd'));
    final numero = _somenteDigitos(_valor('pessoa.telefones.numero'));
    final celular = _somenteDigitos(_valor('pessoa.celular.sms'));
    final telefone = celular.isNotEmpty
        ? celular
        : ddd.isNotEmpty && numero.isNotEmpty
            ? '$ddd$numero'
            : '';
    final uuid = proposta.uuid;
    if (telefone.isEmpty || uuid == null) return;
    try {
      await context.read<PropostaService>().enviarTokenSms(
            phoneNumber: telefone,
            propostaId: proposta.id,
            propostaUUID: uuid,
            stepName: etapa.nome,
          );
      if (!mounted) return;
      _iniciarContagem();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token enviado por SMS.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _reenviarTokenResultado() async {
    final proposta = _proposta;
    if (proposta == null) return;
    try {
      await context.read<PropostaService>().reenviarSms(proposta.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token reenviado por SMS.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _iniciarContagem() {
    _timer?.cancel();
    setState(() => _segundosReenvio = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_segundosReenvio > 0) _segundosReenvio--;
        if (_segundosReenvio <= 0) timer.cancel();
      });
    });
  }

  String _valor(String codigo) {
    final controller = _controllers[codigo];
    if (controller != null && controller.text.trim().isNotEmpty) {
      return controller.text.trim();
    }
    return _valoresAnteriores[codigo]?.trim() ?? '';
  }

  String _normalizarValor(CampoColeta campo, String valor) {
    final codigo = campo.codigo;
    final numerico = campo.isNumeric ||
        codigo.contains('cpf') ||
        codigo.contains('cnpj') ||
        codigo.contains('telefone') ||
        codigo.contains('celular') ||
        codigo.contains('numero');
    return numerico ? _somenteDigitos(valor) : valor;
  }

  String _somenteDigitos(String valor) =>
      valor.replaceAll(RegExp(r'\D'), '');

  String _resolverPlaceholders(String texto) {
    var resultado = texto;
    for (final entry in _controllers.entries) {
      resultado = resultado.replaceAll(
        '{{${entry.key}}}',
        entry.value.text,
      );
    }
    for (final entry in _valoresAnteriores.entries) {
      resultado = resultado.replaceAll(
        '{{${entry.key}}}',
        entry.value,
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

  @override
  Widget build(BuildContext context) {
    final etapa = _etapa;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proposta ${widget.propostaId}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (etapa != null && etapa.nome.isNotEmpty)
              Text(
                etapa.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _erroWidget()
              : _finalizada
                  ? _resultado()
                  : _isSmsStep
                      ? _formularioSms()
                      : _formulario(),
    );
  }

  Widget _formulario() {
    final proposta = _proposta;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            const BrandMark(size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Proposta - ${proposta?.cliente.nome ?? ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isSmsStep) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Token SMS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Digite o token recebido por SMS para concluir a proposta.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _enviando ? null : _enviarToken,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate,
                  ),
                  child: const Text('Reenviar Token'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_camposTelefone.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Informe seu telefone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(),
                if (_telefones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.red,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Preencha no mínimo 1 item',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._camposTelefone.map(_campo),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _adicionarTelefone,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      minimumSize: const Size(140, 48),
                    ),
                    child: const Text('Adicionar'),
                  ),
                ),
                const SizedBox(height: 16),
                _tabelaTelefones(),
                const SizedBox(height: 20),
              ],
              ..._camposSms.map(_campo),
              ..._camposOutros.map(_campo),
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
    );
  }

  Widget _tabelaTelefones() {
    return Column(
      children: [
        const Row(
          children: [
            SizedBox(width: 64, child: Text('DDD')),
            SizedBox(width: 160, child: Text('Número')),
            Expanded(child: Text('Tipo')),
            SizedBox(width: 48),
          ],
        ),
        const Divider(),
        if (_telefones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum item adicionado',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          )
        else
          ..._telefones.map(
            (telefone) => Row(
              children: [
                SizedBox(width: 64, child: Text(telefone.ddd)),
                SizedBox(
                  width: 160,
                  child: Text(_formatarNumero(telefone.numero)),
                ),
                Expanded(
                  child: Text(
                    telefone.tipo == 'CELULAR'
                        ? 'Celular'
                        : telefone.tipo,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _telefones = [];
                    _controllers['pessoa.celular.sms']?.clear();
                  }),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _limparTermo(String texto) {
    var resultado = texto.replaceAllMapped(
      RegExp(
        r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) => '"${match[1]}" ${match[2]}',
    );
    resultado = resultado.replaceAll(RegExp(r'<[^>]+>'), '');
    resultado = resultado.replaceAll('\r\n', '\n');
    resultado = resultado.replaceAll(RegExp(r'[ \t]+'), ' ');
    resultado = resultado.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return resultado.trim();
  }

  String _formatarNumero(String digits) {
    if (digits.length > 4) {
      final corte = digits.length - 4;
      return '${digits.substring(0, corte)}-${digits.substring(corte)}';
    }
    return digits;
  }

  Widget _formularioSms() {
    final proposta = _proposta;
    final termoCampos = _campos
        .where((campo) => campo.codigo == 'descricao.termo.aceite.sms')
        .toList();
    final termo = termoCampos.isEmpty ? '' : termoCampos.first.descricao;
    final ddd = _somenteDigitos(_valor('pessoa.telefones.ddd'));
    final numero = _somenteDigitos(_valor('pessoa.telefones.numero'));
    final celular = _somenteDigitos(_valor('pessoa.celular.sms'));
    final telefone = celular.isNotEmpty ? celular : '$ddd$numero';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            const BrandMark(size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Proposta - ${proposta?.cliente.nome ?? ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Termo de Aceite - Token SMS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 8),
        if (telefone.isNotEmpty)
          Text(
            'Token enviado para ${_formatarTelefone(telefone)} *',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.red,
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 46,
              height: 54,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocus[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.red),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.red),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocus[index + 1].requestFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    _otpFocus[index - 1].requestFocus();
                  }
                  setState(() {});
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _segundosReenvio > 0 || _enviando ? null : _enviarToken,
            child: Text(
              _segundosReenvio > 0
                  ? 'Reenviar Token (${_segundosReenvio}s)'
                  : 'Reenviar Token',
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TERMO DE ACEITE',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _limparTermo(termo),
          style: const TextStyle(fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _enviando ? null : _enviarSms,
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
    );
  }

  Future<void> _enviarSms() async {
    final proposta = _proposta;
    final etapa = _etapa;
    if (proposta == null || etapa == null) return;
    final token = _otpControllers.map((controller) => controller.text).join();
    if (token.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o token de 6 dígitos.')),
      );
      return;
    }
    final tokenCampos = _campos
        .where((campo) => campo.codigo == 'termo.aceite.token.sms')
        .toList();
    final tokenCampo = tokenCampos.isEmpty ? null : tokenCampos.first;
    final respostas = [
      {
        if (tokenCampo?.id != null) 'campoId': tokenCampo!.id,
        'campoCodigo': 'termo.aceite.token.sms',
        'valor': token,
        'ordem': '0',
      },
    ];
    setState(() => _enviando = true);
    try {
      await context.read<PropostaService>().enviarColeta({
        'propostaId': proposta.id,
        'etapaId': etapa.id,
        'respostas': respostas,
      });
      if (!mounted) return;
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _formatarTelefone(String digits) {
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) '
          '${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) '
          '${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return digits;
  }

  Widget _resultado() {
    final proposta = _proposta!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge.forLabel(proposta.statusLabel),
            const SizedBox(height: 16),
            Text(
              proposta.cliente.nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(_formatDocumento(proposta.cliente.documento)),
            if (proposta.motivoReprovacao.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Motivo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                proposta.motivoReprovacao,
                textAlign: TextAlign.center,
              ),
            ],
            if (proposta.status.toUpperCase() == 'EXPIRADO') ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reenviarTokenResultado,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Reenviar token'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _erroWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
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

  String _formatDocumento(String documento) {
    final digits = documento.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return digits.replaceFirstMapped(
        RegExp(r'(\d{3})(\d{3})(\d{3})(\d{2})'),
        (m) => '${m[1]}.${m[2]}.${m[3]}-${m[4]}',
      );
    }
    if (digits.length == 14) {
      return digits.replaceFirstMapped(
        RegExp(r'(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})'),
        (m) => '${m[1]}.${m[2]}.${m[3]}/${m[4]}-${m[5]}',
      );
    }
    return documento;
  }
}
