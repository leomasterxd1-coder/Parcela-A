import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class FiltrosProposta {
  final String id;
  final String documento;
  final String status;
  final DateTime? dataInicial;
  final DateTime? dataFinal;
  final bool minhas;

  const FiltrosProposta({
    this.id = '',
    this.documento = '',
    this.status = '',
    this.dataInicial,
    this.dataFinal,
    this.minhas = true,
  });
}

class FiltrosScreen extends StatefulWidget {
  final FiltrosProposta inicial;

  const FiltrosScreen({super.key, required this.inicial});

  @override
  State<FiltrosScreen> createState() => _FiltrosScreenState();
}

class _FiltrosScreenState extends State<FiltrosScreen> {
  final _idController = TextEditingController();
  final _documentoController = TextEditingController();
  final _dataInicialController = TextEditingController();
  final _dataFinalController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  String _status = '';
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  bool _minhas = true;

  @override
  void initState() {
    super.initState();
    _idController.text = widget.inicial.id;
    _documentoController.text = widget.inicial.documento;
    _status = widget.inicial.status;
    _dataInicial = widget.inicial.dataInicial;
    _dataFinal = widget.inicial.dataFinal;
    _minhas = widget.inicial.minhas;
    if (_dataInicial != null) {
      _dataInicialController.text = _dateFormat.format(_dataInicial!);
    }
    if (_dataFinal != null) {
      _dataFinalController.text = _dateFormat.format(_dataFinal!);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _documentoController.dispose();
    _dataInicialController.dispose();
    _dataFinalController.dispose();
    super.dispose();
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

  void _limpar() {
    setState(() {
      _idController.clear();
      _documentoController.clear();
      _dataInicialController.clear();
      _dataFinalController.clear();
      _status = '';
      _dataInicial = null;
      _dataFinal = null;
      _minhas = true;
    });
  }

  void _pesquisar() {
    Navigator.of(context).pop(
      FiltrosProposta(
        id: _idController.text.trim(),
        documento: _documentoController.text.trim(),
        status: _status,
        dataInicial: _dataInicial,
        dataFinal: _dataFinal,
        minhas: _minhas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Filtros',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          TextField(
            controller: _idController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ID',
              border: UnderlineInputBorder(),
              filled: false,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _documentoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Documento',
              border: UnderlineInputBorder(),
              filled: false,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: UnderlineInputBorder(),
              filled: false,
            ),
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
          const SizedBox(height: 24),
          TextField(
            controller: _dataInicialController,
            readOnly: true,
            onTap: () => _selecionarData(inicial: true),
            decoration: const InputDecoration(
              labelText: 'Data Inicial',
              border: UnderlineInputBorder(),
              filled: false,
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _dataFinalController,
            readOnly: true,
            onTap: () => _selecionarData(inicial: false),
            decoration: const InputDecoration(
              labelText: 'Data Final',
              border: UnderlineInputBorder(),
              filled: false,
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _minhas,
                activeColor: AppColors.yellow,
                onChanged: (value) => setState(() => _minhas = value ?? true),
              ),
              const Text('Minhas', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              Radio<bool>(
                value: false,
                groupValue: _minhas,
                activeColor: AppColors.yellow,
                onChanged: (value) => setState(() => _minhas = value ?? false),
              ),
              const Text('Todas', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _pesquisar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(140, 52),
                ),
                child: const Text('Pesquisar'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _limpar,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                ),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
