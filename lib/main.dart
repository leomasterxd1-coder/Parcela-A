import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'screens/login_screen.dart';
import 'screens/propostas_screen.dart';
import 'screens/selecionar_loja_screen.dart';
import 'services/auth_service.dart';
import 'services/catalogo_service.dart';
import 'services/coleta_service.dart';
import 'services/proposta_service.dart';
import 'state/auth_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_mark.dart';

void main() {
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authProvider = AuthProvider(
    authService: AuthService(apiClient),
    storage: tokenStorage,
  );
  authProvider.init();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<CatalogoService>(
          create: (_) => CatalogoService(apiClient),
        ),
        Provider<PropostaService>(
          create: (_) => PropostaService(apiClient),
        ),
        Provider<ColetaService>(
          create: (_) => ColetaService(apiClient),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const ParcelaAApp(),
    ),
  );
}

class ParcelaAApp extends StatelessWidget {
  const ParcelaAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcela A',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.initializing) {
      return const Scaffold(
        body: Center(child: BrandMark(size: 88)),
      );
    }
    if (auth.authenticated) {
      if (auth.origemSelecionada == null) {
        return const SelecionarLojaScreen();
      }
      return PropostasScreen(origem: auth.origemSelecionada!);
    }
    return const LoginScreen();
  }
}
