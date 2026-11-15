import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/proposta.dart';
import '../services/catalogo_service.dart';
import '../services/proposta_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/status_badge.dart';
import 'filtros_screen.dart';
import 'preenchimento_proposta_screen.dart';
import 'nova_proposta_screen.dart';

class PropostasScreen extends StatefulWidget {
  final OrigemComercial origem;

  const PropostasScreen({super.key, required this.origem});

  @override
  State<PropostasScreen> createState() => _PropostasScreenState();
}

class _PropostasScreenState extends State<PropostasScreen> {
  final _documentoController = TextEditingController();
  final _idController = TextEditingController();
  final _scrollController = ScrollController();
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<Proposta> _propostas = [];
  Map<int, String> _nomesOrigem = {};
  bool _minhas = true;
  bool _loading = true;
  bool _showScrollTop = false;
  String? _erro;
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  void _onScroll() {
    final mostrar = _scrollController.offset > 120;
    if (mostrar != _showScrollTop) {
      setState(() => _showScrollTop = mostrar);
    }
  }

  void _voltarAoTopo() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _documentoController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final lista = await context.read<PropostaService>().listar(
        minhas: _minhas,
        origemComercialId: widget.origem.id,
        usuarioId: context.read<AuthProvider>().usuarioId,
        id: _idController.text,
        documento: _documentoController.text,
        status: _status,
        dataInicial: _dataInicial,
        dataFinal: _dataFinal,
        size: 200,
      );
      final ids = lista
          .map((proposta) => proposta.origem.id)
          .whereType<int>()
          .toSet()
          .toList();
      var nomes = <int, String>{};
      if (ids.isNotEmpty) {
        try {
          nomes = await context.read<CatalogoService>().nomesOrigens(ids);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _propostas = lista;
        _nomesOrigem = nomes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _abrirFiltros() async {
    final resultado = await Navigator.of(context).push<FiltrosProposta>(
      MaterialPageRoute(
        builder: (_) => FiltrosScreen(
          inicial: FiltrosProposta(
            id: _idController.text,
            documento: _documentoController.text,
            status: _status,
            dataInicial: _dataInicial,
            dataFinal: _dataFinal,
            minhas: _minhas,
          ),
        ),
      ),
    );
    if (resultado == null) return;
    setState(() {
      _idController.text = resultado.id;
      _documentoController.text = resultado.documento;
      _status = resultado.status;
      _dataInicial = resultado.dataInicial;
      _dataFinal = resultado.dataFinal;
      _minhas = resultado.minhas;
    });
    _carregar();
  }

  Future<void> _abrirNovaProposta() async {
    final criada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovaPropostaScreen(
          origens: [widget.origem],
          origemSelecionada: widget.origem,
        ),
      ),
    );
    if (criada == true) {
      _carregar();
    }
  }

  Future<void> _reenviarToken(Proposta proposta) async {
    try {
      await context.read<PropostaService>().reenviarSms(proposta.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token reenviado por SMS.')),
      );
      _carregar();
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

  Future<void> _abrirPreenchimento(Proposta proposta) async {
    if (!proposta.isAguardandoPreenchimento) {
      _mostrarDetalhes(proposta);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreenchimentoPropostaScreen(
          propostaId: proposta.id,
        ),
      ),
    );
    if (mounted) _carregar();
  }

  void _mostrarDetalhes(Proposta proposta) {
    final motivo = proposta.motivoReprovacao;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge.forLabel(proposta.statusLabel),
                const SizedBox(height: 16),
                Text(
                  proposta.cliente.nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _copiar(
                    proposta.cliente.documento,
                    'CPF copiado',
                  ),
                  child: Text(_formatDocumento(proposta.cliente.documento)),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _copiar(
                    proposta.id.toString(),
                    'Número da proposta copiado',
                  ),
                  child: _linha('ID', proposta.id.toString()),
                ),
                _linha(
                  'Data',
                  proposta.data == null
                      ? '-'
                      : _dateTimeFormat.format(proposta.data!),
                ),
                _linha(
                  'Origem comercial',
                  _nomeOrigem(proposta),
                ),
                _linha(
                  'Etapa atual',
                  proposta.etapaAtual.nome.isEmpty
                      ? '-'
                      : proposta.etapaAtual.nome,
                ),
                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Motivo da reprovação',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(motivo),
                ],
                if (proposta.status.toUpperCase() == 'EXPIRADO') ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _reenviarToken(proposta);
                    },
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Reenviar token'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/login_logo.png',
              height: 26,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
            Text(
              widget.origem.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          IconButton(
            tooltip: 'Trocar loja',
            onPressed: () => context.read<AuthProvider>().trocarLoja(),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollTop) ...[
            FloatingActionButton.small(
              heroTag: 'voltar-ao-topo',
              onPressed: _voltarAoTopo,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.slate,
              child: const Icon(Icons.keyboard_arrow_up),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: 'nova-proposta',
            onPressed: _abrirNovaProposta,
            backgroundColor: AppColors.yellow,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erro != null)
              _mensagemErro()
            else if (_propostas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('Nenhuma proposta encontrada.')),
              )
            else
              ..._propostas.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _mensagemErro() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            _erro ?? 'Erro ao carregar propostas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _carregar,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _card(Proposta proposta) {
    final aprovada = proposta.isAprovada;
    final reprovada = proposta.isReprovada;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandMark(size: 96),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge.forLabel(proposta.statusLabel),
                  const SizedBox(height: 8),
                  Text(
                    proposta.cliente.nome.isEmpty ? '-' : proposta.cliente.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _copiar(
                      proposta.cliente.documento,
                      'CPF copiado',
                    ),
                    child: Text(
                      _formatDocumento(proposta.cliente.documento),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        proposta.data == null
                            ? '-'
                            : _dateTimeFormat.format(proposta.data!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _nomeOrigem(proposta),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _copiar(
                    proposta.id.toString(),
                    'Número da proposta copiado',
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.key_outlined,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        proposta.id.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                InkWell(
                  onTap: () => _abrirPreenchimento(proposta),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: reprovada
                          ? AppColors.yellow
                          : aprovada
                          ? AppColors.green
                          : AppColors.yellow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      reprovada ? Icons.info_outline : Icons.edit_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copiar(String texto, String mensagem) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  String _nomeOrigem(Proposta proposta) {
    if (proposta.origem.nome.isNotEmpty) return proposta.origem.nome;
    final id = proposta.origem.id;
    if (id != null && _nomesOrigem[id] != null) {
      return _nomesOrigem[id]!;
    }
    return widget.origem.nome.isEmpty ? '-' : widget.origem.nome;
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
