import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  // Garante que os bindings do Flutter estão inicializados
  // Necessário antes de chamar código assíncrono no main
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase com as configurações do projeto
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const TrainlyApp());
}

class TrainlyApp extends StatelessWidget {
  const TrainlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trainly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // AuthGate decide qual tela mostrar baseado no estado de autenticação
      home: const AuthGate(),
    );
  }
}

/// Widget que gerencia a navegação baseada no estado de autenticação
/// 
/// Verifica se existe uma sessão ativa:
/// - Se sim: mostra HomeScreen
/// - Se não: mostra LoginScreen
/// 
/// Também escuta mudanças de estado (login/logout) em tempo real
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  /// Inicializa o estado de autenticação
  Future<void> _initializeAuth() async {
    // Obtém a sessão atual (pode existir se o usuário já estava logado)
    final session = Supabase.instance.client.auth.currentSession;

    // Escuta mudanças no estado de autenticação
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _session = data.session;
        });
      }
    });

    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostra loading enquanto verifica a sessão
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando...'),
            ],
          ),
        ),
      );
    }

    // Navega baseado no estado da sessão
    if (_session != null) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
