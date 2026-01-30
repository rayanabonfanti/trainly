import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../home/home_page.dart';
import 'login_page.dart';

/// Widget que gerencia a navegação baseada no estado de autenticação
///
/// Verifica se existe uma sessão ativa:
/// - Se sim: mostra HomePage
/// - Se não: mostra LoginPage
///
/// Escuta mudanças de estado (login/logout) em tempo real
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

  Future<void> _initializeAuth() async {
    final session = supabase.auth.currentSession;

    supabase.auth.onAuthStateChange.listen((data) {
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_session != null) {
      return const HomePage();
    }

    return const LoginPage();
  }
}
