import 'package:flutter/material.dart';

import '../services/admin_service.dart';

/// Painel de Administração
/// 
/// Permite que usuários com role = 'admin' promovam outros usuários para admin.
/// Esta tela só deve ser acessada por usuários autenticados com role 'admin'.
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _adminService = AdminService();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isCheckingAccess = true;
  bool _hasAccess = false;
  List<UserProfile> _admins = [];

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Verifica se o usuário atual tem acesso ao painel
  Future<void> _checkAccess() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();
    
    if (mounted) {
      setState(() {
        _hasAccess = isAdmin;
        _isCheckingAccess = false;
      });

      if (isAdmin) {
        _loadAdmins();
      }
    }
  }

  /// Carrega a lista de administradores
  Future<void> _loadAdmins() async {
    final admins = await _adminService.listAdmins();
    if (mounted) {
      setState(() {
        _admins = admins;
      });
    }
  }

  /// Mostra diálogo de confirmação antes de promover
  Future<bool> _showConfirmDialog(String email) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Promoção'),
        content: Text(
          'Tem certeza que deseja promover "$email" para administrador?\n\n'
          'Esta ação dará ao usuário acesso completo ao painel administrativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Promover'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Promove o usuário para admin
  Future<void> _promoteToAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    // Mostra diálogo de confirmação
    final confirmed = await _showConfirmDialog(email);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adminService.promoteToAdmin(email);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Mostra mensagem de resultado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (result.success) {
          _emailController.clear();
          _loadAdmins(); // Recarrega lista de admins
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Admin'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading inicial (verificando acesso)
    if (_isCheckingAccess) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando permissões...'),
          ],
        ),
      );
    }

    // Sem acesso
    if (!_hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Você não tem permissão para acessar esta área.\n'
                'Apenas administradores podem acessar o painel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    // Painel admin
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPromotionCard(),
          const SizedBox(height: 24),
          _buildAdminsListCard(),
        ],
      ),
    );
  }

  Widget _buildPromotionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Promover Usuário',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Digite o email do usuário que deseja promover para administrador.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Email do usuário',
                  hintText: 'usuario@exemplo.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, digite um email';
                  }
                  if (!_isValidEmail(value.trim())) {
                    return 'Por favor, digite um email válido';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_isLoading) {
                    _promoteToAdmin();
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _promoteToAdmin,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upgrade),
                  label: Text(
                    _isLoading ? 'Promovendo...' : 'Promover para Admin',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminsListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Administradores',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAdmins,
                  tooltip: 'Atualizar lista',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_admins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Nenhum administrador encontrado',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        admin.email[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(admin.name ?? admin.email),
                    subtitle: admin.name != null ? Text(admin.email) : null,
                    trailing: Chip(
                      label: const Text('Admin'),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
