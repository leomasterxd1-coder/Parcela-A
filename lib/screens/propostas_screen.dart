import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/proposta.dart';
import '../services/catalogo_service.dart';
import '../services/proposta_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/status_badge.dart';
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
  final _dataInicialController = TextEditingController();
  final _dataFinalController = TextEditingController();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<Proposta> _propostas = [];
  bool _minhas = true;
  bool _loading = true;
  String? _erro;
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _documentoController.dispose();
    _idController.dispose();
    _dataInicialController.dispose();
    _dataFinalController.dispose();
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
        id: _idController.text,
        documento: _documentoController.text,
        status: _status,
        dataInicial: _dataInicial,
        dataFinal: _dataFinal,
        size: 50,
      );
      if (!mounted) return;
      setState(() {
        _propostas = lista;
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

  void _limpar() {
    _documentoController.clear();
    _idController.clear();
    _dataInicialController.clear();
    _dataFinalController.clear();
    setState(() {
      _dataInicial = null;
      _dataFinal = null;
      _status = '';
      _minhas = true;
    });
    _carregar();
  }

  Future<void> _selecionarData({required bool inicial}) async {
    final atual = inicial ? _dataInicial : _dataFinal;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (inicial) {
        _dataInicial = picked;
        _dataInicialController.text = _dateFormat.format(picked);
      } else {
        _dataFinal = picked;
        _dataFinalController.text = _dateFormat.format(picked);
      }
    });
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
                Text(_formatDocumento(proposta.cliente.documento)),
                const SizedBox(height: 12),
                _linha('ID', proposta.id.toString()),
                _linha(
                  'Data',
                  proposta.data == null
                      ? '-'
                      : _dateTimeFormat.format(proposta.data!),
                ),
                _linha(
                  'Origem comercial',
                  proposta.origem.nome.isEmpty ? '-' : proposta.origem.nome,
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
            const BrandTitle(fontSize: 18),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirNovaProposta,
        backgroundColor: AppColors.yellow,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _filtros(),
            const SizedBox(height: 12),
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

  Widget _filtros() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ID'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _documentoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Documento'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'EM_ANDAMENTO',
                  child: Text('Em andamento'),
                ),
                DropdownMenuItem(
                  value: 'REPROVADO',
                  child: Text('Proposta reprovada'),
                ),
                DropdownMenuItem(
                  value: 'APROVADO',
                  child: Text('Proposta aprovada'),
                ),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dataInicialController,
                    readOnly: true,
                    onTap: () => _selecionarData(inicial: true),
                    decoration: const InputDecoration(
                      labelText: 'Data Inicial',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _dataFinalController,
                    readOnly: true,
                    onTap: () => _selecionarData(inicial: false),
                    decoration: const InputDecoration(
                      labelText: 'Data Final',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _minhas,
                  onChanged: (value) => setState(() => _minhas = value ?? true),
                ),
                const Text('Minhas'),
                const SizedBox(width: 12),
                Radio<bool>(
                  value: false,
                  groupValue: _minhas,
                  onChanged: (value) =>
                      setState(() => _minhas = value ?? false),
                ),
                const Text('Todas'),
                const Spacer(),
                FilledButton(
                  onPressed: _carregar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(110, 44),
                  ),
                  child: const Text('Pesquisar'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _limpar, child: const Text('Limpar')),
              ],
            ),
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
                  Text(
                    _formatDocumento(proposta.cliente.documento),
                    style: const TextStyle(fontSize: 13),
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
                          proposta.origem.nome.isEmpty
                              ? '-'
                              : proposta.origem.nome,
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
                Row(
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
                const SizedBox(height: 40),
                InkWell(
                  onTap: () => _mostrarDetalhes(proposta),
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
