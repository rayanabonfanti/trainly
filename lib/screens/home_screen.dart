import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

/// Tela Home - exibida após login bem-sucedido
/// 
/// Mostra informações do usuário logado e permite logout
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    // Extrai informações do usuário
    final userEmail = user?.email ?? 'Email não disponível';
    final userName = user?.userMetadata?['full_name'] as String? ?? 
                     user?.userMetadata?['name'] as String? ?? 
                     'Usuário';
    final userAvatar = user?.userMetadata?['avatar_url'] as String? ??
                       user?.userMetadata?['picture'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainly'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Indicador de autenticação
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Autenticado com sucesso!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Avatar do usuário
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepPurple[100],
                backgroundImage: userAvatar != null 
                    ? NetworkImage(userAvatar) 
                    : null,
                child: userAvatar == null 
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(height: 16),
              
              // Nome do usuário
              Text(
                userName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Email do usuário
              Text(
                userEmail,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Informações adicionais da sessão
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações da Sessão',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('User ID', user?.id ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Provider', 
                        user?.appMetadata['provider'] as String? ?? 'google',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Criado em',
                        user?.createdAt != null 
                            ? _formatDate(user!.createdAt)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botão de logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  /// Realiza logout do usuário
  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      
      if (context.mounted) {
        // Navega de volta para a tela de login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
