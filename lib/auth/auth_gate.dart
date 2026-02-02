import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../home/home_page.dart';
import 'register_student_page.dart' show pendingRegistrationRoleKey;
import 'welcome_page.dart';

/// Widget que gerencia a navegação baseada no estado de autenticação
///
/// Verifica se existe uma sessão ativa E se o usuário tem perfil cadastrado:
/// - Se sim: mostra HomePage
/// - Se não tem sessão: mostra WelcomePage
/// - Se tem sessão mas não tem perfil: mostra erro e faz logout
///
/// Escuta mudanças de estado (login/logout) em tempo real
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;
  bool _hasProfile = false;
  bool _showAccessDenied = false; // Mostra tela de acesso negado
  bool _isProcessing = false; // Evita processamento duplo
  bool _hasInitError = false; // Erro de inicialização do Supabase
  String _errorMessage = '';
  Session? _session;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    try {
      // Primeiro registra o listener para mudanças de autenticação
      supabase.auth.onAuthStateChange.listen((data) async {
        if (!mounted) return;
        
        final newSession = data.session;
        
        if (newSession != null) {
          // Nova sessão detectada (login via OAuth redirect)
          await _checkSessionProfile(newSession);
        } else {
          // Logout
          if (mounted) {
            setState(() {
              _session = null;
              _hasProfile = false;
              _showAccessDenied = false;
              _isLoading = false;
            });
            if (!_animationController.isCompleted) {
              _animationController.forward();
            }
          }
        }
      });

      // Depois verifica a sessão atual (pode já existir se o app foi reaberto)
      final session = supabase.auth.currentSession;
      
      if (session != null) {
        await _checkSessionProfile(session);
      } else {
        // Sem sessão - mostra welcome page após pequeno delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _isLoading = false);
          _animationController.forward();
        }
      }
    } catch (e) {
      // Erro ao inicializar - mostra tela de erro
      if (mounted) {
        setState(() {
          _hasInitError = true;
          _errorMessage = 'Erro ao conectar com o servidor.\nVerifique sua conexão.';
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  /// Verifica se a sessão tem perfil cadastrado
  Future<void> _checkSessionProfile(Session session) async {
    // Evita processamento duplo
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      final userEmail = session.user.email;
      final userId = session.user.id;
      
      if (userEmail == null || userEmail.isEmpty) {
        await supabase.auth.signOut();
        if (mounted) {
          setState(() => _isLoading = false);
          if (!_animationController.isCompleted) {
            _animationController.forward();
          }
        }
        return;
      }
      
      // Verifica se tem perfil cadastrado
      var hasProfile = await _checkUserProfileByEmail(userEmail);
      
      if (!hasProfile) {
        // Verifica se há um cadastro pendente (vindo das telas de registro)
        final prefs = await SharedPreferences.getInstance();
        final pendingRole = prefs.getString(pendingRegistrationRoleKey);
        
        if (pendingRole != null) {
          // Há um cadastro pendente - cria o perfil automaticamente
          final created = await _createProfile(userId, userEmail, pendingRole, null);
          
          // Limpa o pending role
          await prefs.remove(pendingRegistrationRoleKey);
          
          if (created) {
            hasProfile = true;
          }
        }
      }
      
      if (!hasProfile) {
        // Verifica se há um convite de admin pendente para este email
        final invite = await _checkAdminInvite(userEmail);
        
        if (invite != null) {
          // Há um convite de admin - cria o perfil como admin
          final businessId = invite['business_id'] as String;
          final created = await _createProfile(userId, userEmail, 'admin', businessId);
          
          if (created) {
            // Remove o convite após criar o perfil
            await _deleteAdminInvite(invite['id'] as String);
            hasProfile = true;
          }
        }
      }
      
      if (!hasProfile && mounted) {
        // Não tem perfil e não havia cadastro pendente - mostra tela de acesso negado
        setState(() {
          _showAccessDenied = true;
          _isLoading = false;
        });
        if (!_animationController.isCompleted) {
          _animationController.forward();
        }
        return;
      }
      
      // Tem perfil - permite acesso
      if (mounted) {
        setState(() {
          _session = session;
          _hasProfile = true;
          _isLoading = false;
        });
        if (!_animationController.isCompleted) {
          _animationController.forward();
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Verifica se existe um convite de admin para o email
  Future<Map<String, dynamic>?> _checkAdminInvite(String email) async {
    try {
      final response = await supabase
          .from('admin_invites')
          .select()
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Deleta um convite de admin após ser usado
  Future<void> _deleteAdminInvite(String inviteId) async {
    try {
      await supabase.from('admin_invites').delete().eq('id', inviteId);
    } catch (e) {
      // Ignora erro - o convite será deletado eventualmente
    }
  }

  /// Cria um novo perfil na tabela profiles
  Future<bool> _createProfile(String userId, String email, String role, String? businessId) async {
    try {
      final data = {
        'id': userId,
        'email': email.toLowerCase().trim(),
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      if (businessId != null) {
        data['business_id'] = businessId;
      }
      
      await supabase.from('profiles').insert(data);
      return true;
    } catch (e) {
      // Se já existe um perfil (conflito de id), tenta atualizar
      try {
        await supabase.from('profiles').upsert({
          'id': userId,
          'email': email.toLowerCase().trim(),
          'role': role,
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Faz logout e volta para welcome
  Future<void> _handleLogoutFromAccessDenied() async {
    await supabase.auth.signOut();
    if (mounted) {
      setState(() {
        _showAccessDenied = false;
        _session = null;
        _hasProfile = false;
      });
    }
  }

  /// Verifica se existe um perfil cadastrado na tabela profiles pelo EMAIL
  Future<bool> _checkUserProfileByEmail(String email) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      // Em caso de erro, tenta buscar sem lowercase (caso exato)
      try {
        final response = await supabase
            .from('profiles')
            .select('id')
            .eq('email', email.trim())
            .maybeSingle();
        
        return response != null;
      } catch (_) {
        // Em caso de erro, assume que não tem perfil por segurança
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSplashScreen(context);
    }

    // Mostra tela de erro de inicialização
    if (_hasInitError) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildErrorScreen(context),
      );
    }

    // Mostra tela de acesso negado se não tem perfil
    if (_showAccessDenied) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildAccessDeniedScreen(context),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: (_session != null && _hasProfile) ? const HomePage() : const WelcomePage(),
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone de erro
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Título
                Text(
                  'Erro de Conexão',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Mensagem
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Botão de tentar novamente
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasInitError = false;
                      });
                      _initializeAuth();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Tentar Novamente',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

  Widget _buildAccessDeniedScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone de acesso negado
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.no_accounts_rounded,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Título
                Text(
                  'Acesso Não Autorizado',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Mensagem
                Text(
                  'Você ainda não possui cadastro no sistema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Card de informação
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Entre em contato com a administração para solicitar seu cadastro.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                // Botão de voltar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _handleLogoutFromAccessDenied,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text(
                      'Voltar ao Início',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

  Widget _buildSplashScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.pool,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Trainly',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
