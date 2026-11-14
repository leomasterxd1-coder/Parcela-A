import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscure = true;
  bool _salvarCredenciais = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarCredenciais());
  }

  Future<void> _carregarCredenciais() async {
    if (!mounted) return;
    final credenciais =
        await context.read<AuthProvider>().lerCredenciaisSalvas();
    if (!mounted || credenciais == null) return;
    setState(() {
      _loginController.text = credenciais['login'] ?? '';
      _senhaController.text = credenciais['senha'] ?? '';
      _salvarCredenciais = true;
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final login = _loginController.text.trim();
    final senha = _senhaController.text;
    final ok = await auth.login(login, senha);
    if (ok) {
      if (_salvarCredenciais) {
        await auth.salvarCredenciais(login, senha);
      } else {
        await auth.limparCredenciais();
      }
    }
    if (!mounted) return;
    if (!ok && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(auth.error!),
        ),
      );
    }
  }

  void _recuperar(String titulo) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: const Text(
          'A recuperação está disponível no site do Crediário Americanas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/login_logo.png',
                        width: 320,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 48),
                      TextFormField(
                        controller: _loginController,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'Digite seu login',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o login';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          hintText: 'Digite sua senha',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe a senha';
                          }
                          return null;
                        },
                      ),
                      CheckboxListTile(
                        value: _salvarCredenciais,
                        onChanged: (value) => setState(
                          () => _salvarCredenciais = value ?? false,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text(
                          'Salvar credenciais',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : _entrar,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.slate,
                            minimumSize: const Size(0, 56),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Acessar'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => _recuperar('Recuperar senha'),
                        child: const Text('Recuperar senha'),
                      ),
                      TextButton(
                        onPressed: () => _recuperar('Recuperar login'),
                        child: const Text('Recuperar login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
