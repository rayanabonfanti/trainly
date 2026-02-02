import 'package:flutter/material.dart';

import '../auth/setup_business_page.dart';
import '../core/theme_provider.dart';
import '../classes/classes_list_page.dart';
import '../models/business.dart';
import '../services/admin_service.dart';
import '../services/business_service.dart';
import '../services/classes_service.dart';
import '../services/membership_service.dart';
import 'dashboard_page.dart';
import 'manage_admins_page.dart';
import 'manage_members_page.dart';

/// Painel de Administração - Hub Central
///
/// Dashboard administrativo com acesso rápido às funcionalidades de gestão.
/// Esta tela só deve ser acessada por usuários autenticados com role 'admin'.
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _adminService = AdminService();
  final _classesService = ClassesService();
  final _businessService = BusinessService();
  final _membershipService = MembershipService();

  bool _isCheckingAccess = true;
  bool _hasAccess = false;
  bool _hasBusinessConfigured = false;
  Business? _business;
  int _totalClasses = 0;
  int _totalAdmins = 0;
  int _pendingMembers = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();

    if (mounted) {
      setState(() {
        _hasAccess = isAdmin;
        _isCheckingAccess = false;
      });

      if (isAdmin) {
        await _checkBusiness();
        _loadStats();
      }
    }
  }

  Future<void> _checkBusiness() async {
    final business = await _businessService.getMyBusiness();
    if (mounted) {
      setState(() {
        _business = business;
        _hasBusinessConfigured = business != null;
      });
    }
  }

  Future<void> _setupBusiness() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const SetupBusinessPage(),
      ),
    );

    if (result == true) {
      _checkBusiness();
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final results = await Future.wait([
        _classesService.fetchMyBusinessClasses(),
        _adminService.listAdmins(),
        _membershipService.countPendingRequests(),
      ]);

      if (mounted) {
        setState(() {
          _totalClasses = (results[0] as List).length;
          _totalAdmins = (results[1] as List).length;
          _pendingMembers = results[2] as int;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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

    if (!_hasAccess) {
      return _buildAccessDenied();
    }

    if (!_hasBusinessConfigured) {
      return _buildSetupBusinessPrompt();
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildSectionTitle('Gerenciamento'),
            const SizedBox(height: 16),
            _buildManagementCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupBusinessPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business,
                size: 60,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Configure sua Academia',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Antes de começar, você precisa configurar\nos dados da sua academia.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _setupBusiness,
              icon: const Icon(Icons.add_business),
              label: const Text('Configurar Academia'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 60,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Acesso Negado',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Você não tem permissão para acessar\no painel administrativo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _business?.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _business!.logoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.business,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _business?.name ?? 'Sua Academia',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gerencie aulas, membros e administradores',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_note,
            label: 'Aulas',
            value: _isLoadingStats ? '...' : '$_totalClasses',
            color: AppColors.cyanDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            label: 'Admins',
            value: _isLoadingStats ? '...' : '$_totalAdmins',
            color: AppColors.cyanPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.person_add,
            label: 'Pendentes',
            value: _isLoadingStats ? '...' : '$_pendingMembers',
            color: _pendingMembers > 0 ? Colors.orange : Colors.grey,
            badge: _pendingMembers > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool badge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 28),
              if (badge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildManagementCards() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.dashboard,
          title: 'Dashboard',
          description: 'Estatísticas de ocupação e frequência',
          color: AppColors.tealAccent,
          onTap: () => _navigateToDashboard(),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.event_note,
          title: 'Gerenciar Aulas',
          description: 'Criar aulas, tipos de aula e gerenciar treinos',
          color: AppColors.cyanDark,
          onTap: () => _navigateToClasses(),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.group,
          title: 'Gerenciar Membros',
          description: 'Aprovar alunos e gerenciar associações',
          color: Colors.green,
          onTap: () => _navigateToManageMembers(),
          badge: _pendingMembers > 0 ? '$_pendingMembers' : null,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.admin_panel_settings,
          title: 'Gerenciar Administradores',
          description: 'Promover usuários e visualizar admins',
          color: AppColors.cyanPrimary,
          onTap: () => _navigateToManageAdmins(),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 28,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DashboardPage(),
      ),
    );
    _loadStats();
  }

  void _navigateToClasses() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ClassesListPage(),
      ),
    );
    _loadStats();
  }

  void _navigateToManageMembers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ManageMembersPage(),
      ),
    );
    _loadStats();
  }

  void _navigateToManageAdmins() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ManageAdminsPage(),
      ),
    );
    _loadStats();
  }
}
