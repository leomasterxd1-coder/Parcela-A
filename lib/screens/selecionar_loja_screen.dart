import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalogo_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class SelecionarLojaScreen extends StatefulWidget {
  const SelecionarLojaScreen({super.key});

  @override
  State<SelecionarLojaScreen> createState() => _SelecionarLojaScreenState();
}

class _SelecionarLojaScreenState extends State<SelecionarLojaScreen> {
  List<OrigemComercial> _lojas = [];
  OrigemComercial? _selecionada;
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final catalogo = context.read<CatalogoService>();
      final auth = context.read<AuthProvider>();
      final resultado = await catalogo.minhasLojas();
      if (resultado.usuarioId != null) {
        await auth.definirUsuarioId(resultado.usuarioId!);
      }
      if (!mounted) return;
      setState(() {
        _lojas = resultado.lojas;
        _selecionada =
            resultado.lojas.length == 1 ? resultado.lojas.first : null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _selecionar() async {
    final loja = _selecionada;
    if (loja == null) return;
    setState(() => _salvando = true);
    await context.read<AuthProvider>().selecionarOrigem(loja);
    if (mounted) setState(() => _salvando = false);
  }

  Future<void> _abrirSelecao() async {
    final loja = await showModalBottomSheet<OrigemComercial>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LojaPicker(
        lojas: _lojas,
        selecionada: _selecionada,
      ),
    );
    if (loja != null) setState(() => _selecionada = loja);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/login_logo.png',
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Onde estou?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_erro != null)
                      _erroWidget()
                    else if (_lojas.isEmpty)
                      const Text('Nenhuma origem comercial vinculada.')
                    else ...[
                      InkWell(
                        onTap: _abrirSelecao,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selecionada?.label ?? 'Origem Comercial',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selecionada == null
                                        ? AppColors.muted
                                        : AppColors.text,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  context.read<AuthProvider>().logout(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.pink,
                                minimumSize: const Size(0, 52),
                                side: const BorderSide(color: AppColors.pink),
                              ),
                              child: const Text('Sair'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _selecionada == null || _salvando
                                      ? null
                                      : _selecionar,
                              child: _salvando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Selecionar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _erroWidget() {
    return Column(
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
    );
  }
}

class _LojaPicker extends StatefulWidget {
  final List<OrigemComercial> lojas;
  final OrigemComercial? selecionada;

  const _LojaPicker({required this.lojas, this.selecionada});

  @override
  State<_LojaPicker> createState() => _LojaPickerState();
}

class _LojaPickerState extends State<_LojaPicker> {
  final _busca = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.lojas
        .where(
          (loja) => loja.label.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Selecione a loja',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _busca,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar loja',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: filtradas
                    .map(
                      (loja) => ListTile(
                        title: Text(loja.label),
                        trailing: loja.id == widget.selecionada?.id
                            ? const Icon(
                                Icons.check,
                                color: AppColors.pink,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(loja),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
