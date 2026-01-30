import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tela de Login com Google
/// 
/// Usa signInWithOAuth - o Supabase gerencia toda a comunicação com o Google
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  final _supabase = Supabase.instance.client;

  /// Realiza login com Google via OAuth
  /// 
  /// Fluxo:
  /// 1. Supabase abre browser com página de login do Google
  /// 2. Usuário autentica no Google
  /// 3. Google redireciona para o Supabase
  /// 4. Supabase valida e redireciona de volta ao app via deep link
  /// 5. Sessão é criada automaticamente
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Iniciando login com Google...');
      debugPrint('Plataforma Web: $kIsWeb');
      
      if (kIsWeb) {
        // Na web, não precisa de redirectTo - o Supabase usa a URL atual
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
        );
      } else {
        // Em mobile (Android/iOS), usa deep link
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.trainly://login-callback',
        );
      }
      
      debugPrint('signInWithOAuth chamado com sucesso');
      
      // Nota: a navegação para Home acontece automaticamente
      // via AuthGate quando a sessão é detectada
    } on AuthException catch (e) {
      debugPrint('AuthException: ${e.message}');
      setState(() {
        _errorMessage = 'Erro de autenticação: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro genérico: $e');
      setState(() {
        _errorMessage = 'Erro ao fazer login: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Título do app
                const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'Trainly',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seu app de treinos',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Mensagem de erro, se houver
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Botão de login com Google
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata,
                              color: Colors.red,
                            ),
                          ),
                    label: Text(
                      _isLoading ? 'Entrando...' : 'Entrar com Google',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
