import 'package:flutter/material.dart';

import '../admin/admin_panel_page.dart';
import '../admin/class_detail_page.dart';
import '../attendance/attendance_history_page.dart';
import '../auth/select_business_page.dart';
import '../bookings/my_bookings_page.dart';
import '../calendar/calendar_page.dart';
import '../classes/classes_list_page.dart';
import '../core/booking_rules.dart';
import '../core/supabase_client.dart';
import '../core/theme_provider.dart';
import '../main.dart';
import '../models/booking.dart';
import '../models/business_membership.dart';
import '../models/swim_class.dart';
import '../profile/my_memberships_page.dart';
import '../profile/profile_page.dart';
import '../services/admin_service.dart';
import '../services/booking_service.dart';
import '../services/membership_service.dart';
import '../widgets/skeleton_loading.dart';

/// Tela Home - exibe aulas do dia seguinte com opção de reserva
/// Redesenhada com Bottom Navigation Bar para melhor UX
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _bookingService = BookingService();
  final _adminService = AdminService();

  List<SwimClassWithAvailability>? _classes;
  List<ClassWithBookingsInfo>? _adminClasses;
  String? _error;
  bool _isLoading = true;
  bool _isAdmin = false;
  Set<String> _loadingBookings = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      
      if (isAdmin) {
        // Admin: carrega aulas com contagem de reservas
        final classesWithBookings = await _bookingService.fetchClassesWithBookings();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _adminClasses = classesWithBookings;
            _isLoading = false;
          });
        }
      } else {
        // Aluno: carrega aulas do dia seguinte
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final classes = await _bookingService.fetchClassesByDateWithAvailability(tomorrow);
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _classes = classes;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar dados: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _bookClass(SwimClassWithAvailability classWithAvailability) async {
    final classId = classWithAvailability.swimClass.id;

    setState(() {
      _loadingBookings.add(classId);
    });

    try {
      final result = await _bookingService.createBooking(classId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );

        if (result.success) {
          _loadData();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingBookings.remove(classId);
        });
      }
    }
  }

  void _onNavTap(int index) {
    if (_isAdmin) {
      // Navegação para admin - layout simplificado
      switch (index) {
        case 0:
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            _loadData(); // Recarrega ao voltar para home
          }
          break;
        case 1:
          _navigateToCalendar(context);
          break;
        case 2:
          _navigateToAdminPanel(context);
          break;
        case 3:
          _navigateToProfile(context);
          break;
      }
    } else {
      // Navegação para aluno - layout simplificado e intuitivo
      switch (index) {
        case 0:
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            _loadData(); // Recarrega ao voltar para home
          }
          break;
        case 1:
          _navigateToCalendar(context);
          break;
        case 2:
          _navigateToMyBookings(context);
          break;
        case 3:
          _navigateToProfile(context);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Email não disponível';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernHeader(userEmail, tomorrow, colorScheme),
            _buildQuickActions(colorScheme),
            if (!_isAdmin && !_isLoading) _buildStudentQuickActionsRow(colorScheme),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(colorScheme),
    );
  }

  Widget _buildModernHeader(String userEmail, DateTime date, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _extractName(userEmail),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          _buildNotificationButton(colorScheme),
          const SizedBox(width: 8),
          _buildAvatarButton(userEmail, colorScheme),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  Widget _buildNotificationButton(ColorScheme colorScheme) {
    return IconButton(
      onPressed: _loadData,
      icon: const Icon(Icons.refresh_rounded),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAvatarButton(String userEmail, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showProfileMenu(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _extractName(userEmail)[0].toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Header do menu com info do usuário
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _extractName(userEmail)[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _extractName(userEmail),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isAdmin 
                                ? Colors.orange.withOpacity(0.2)
                                : colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isAdmin ? 'Administrador' : 'Aluno',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isAdmin 
                                  ? Colors.orange.shade700
                                  : colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuOption(
              icon: Icons.person_outline,
              title: 'Meu Perfil',
              subtitle: 'Editar dados e configurações',
              onTap: () {
                Navigator.pop(context);
                _navigateToProfile(context);
              },
              colorScheme: colorScheme,
            ),
            if (!_isAdmin) ...[
              _buildMenuOption(
                icon: Icons.history,
                title: 'Histórico de Frequência',
                subtitle: 'Ver aulas anteriores',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAttendance(context);
                },
                colorScheme: colorScheme,
              ),
              _buildMenuOption(
                icon: Icons.business_rounded,
                title: 'Minhas Academias',
                subtitle: 'Gerenciar associações',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToMemberships(context);
                },
                colorScheme: colorScheme,
              ),
            ],
            if (_isAdmin)
              _buildMenuOption(
                icon: Icons.dashboard_rounded,
                title: 'Painel de Gestão',
                subtitle: 'Administrar sua academia',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAdminPanel(context);
                },
                colorScheme: colorScheme,
                isHighlighted: true,
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildMenuOption(
              icon: Icons.logout,
              title: 'Sair da Conta',
              subtitle: 'Encerrar sessão',
              onTap: () {
                Navigator.pop(context);
                _confirmSignOut(context);
              },
              colorScheme: colorScheme,
              isDestructive: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.logout,
            size: 32,
            color: Colors.red.shade600,
          ),
        ),
        title: const Text('Sair da Conta'),
        content: const Text(
          'Tem certeza que deseja sair?\nVocê precisará fazer login novamente.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _signOut(context);
    }
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isDestructive = false,
    bool isHighlighted = false,
  }) {
    final color = isDestructive
        ? Colors.red
        : isHighlighted
            ? colorScheme.primary
            : colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: color.withOpacity(0.5),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isAdmin ? Icons.people : Icons.pool,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin ? 'Reservas dos Alunos' : 'Aulas de Amanhã',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAdmin
                        ? '${_getTotalBookings()} reserva(s) em ${_adminClasses?.length ?? 0} aula(s)'
                        : _formatDateBR(tomorrow),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                onPressed: () => _navigateToCalendar(context),
                icon: const Icon(Icons.calendar_today, size: 18),
                color: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cards de ação rápida para alunos - guia o usuário sobre o que pode fazer
  Widget _buildStudentQuickActionsRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionChip(
              icon: Icons.calendar_month,
              label: 'Agendar',
              onTap: () => _navigateToCalendar(context),
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionChip(
              icon: Icons.bookmark_outlined,
              label: 'Minhas Reservas',
              onTap: () => _navigateToMyBookings(context),
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionChip(
              icon: Icons.business_rounded,
              label: 'Academias',
              onTap: () => _navigateToSelectBusiness(context),
              colorScheme: colorScheme,
              isSecondary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isSecondary = false,
  }) {
    return Material(
      color: isSecondary 
          ? colorScheme.surfaceContainerHighest 
          : colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSecondary 
                    ? colorScheme.onSurface.withOpacity(0.7)
                    : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSecondary 
                        ? colorScheme.onSurface.withOpacity(0.7)
                        : colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Início', colorScheme),
              _buildNavItem(1, Icons.calendar_month_rounded, 'Calendário', colorScheme),
              _buildNavItem(
                2,
                _isAdmin ? Icons.dashboard_rounded : Icons.bookmark_rounded,
                _isAdmin ? 'Gestão' : 'Reservas',
                colorScheme,
              ),
              _buildNavItem(3, Icons.person_rounded, 'Perfil', colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ColorScheme colorScheme) {
    final isSelected = index == _currentIndex;
    
    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userEmail, DateTime date) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá, ${_extractName(userEmail)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _isAdmin 
                ? 'Reservas dos alunos'
                : 'Aulas de amanhã (${_formatDateBR(date)})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const ClassesListSkeleton();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    // Admin: mostra lista de aulas com reservas
    if (_isAdmin) {
      if (_adminClasses == null || _adminClasses!.isEmpty) {
        return _buildAdminEmptyState();
      }
      return _buildAdminClassesList();
    }

    // Aluno: mostra aulas disponíveis
    if (_classes == null || _classes!.isEmpty) {
      return _buildEmptyState();
    }

    return _buildClassesList();
  }

  int _getTotalBookings() {
    if (_adminClasses == null) return 0;
    return _adminClasses!.fold(0, (sum, c) => sum + c.bookedCount);
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 48,
                color: colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma aula amanhã',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use o calendário para encontrar e agendar\naulas em outros dias',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _navigateToCalendar(context),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Abrir Calendário'),
            ),
            const SizedBox(height: 16),
            // Dica adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dica: No calendário você pode ver todas as aulas disponíveis e fazer reservas com um toque!',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 48,
                color: colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma reserva ainda',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quando alunos fizerem reservas,\nelas aparecerão aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _navigateToAdminPanel(context),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Painel de Gestão'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Dica para admins
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Próximos passos:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem('1. Crie aulas no Painel de Gestão', colorScheme),
                  _buildTipItem('2. Convide alunos para sua academia', colorScheme),
                  _buildTipItem('3. Acompanhe reservas aqui', colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminClassesList() {
    // Agrupa por data
    final groupedByDate = <String, List<ClassWithBookingsInfo>>{};
    for (final classInfo in _adminClasses!) {
      final dateKey = classInfo.formattedDate;
      groupedByDate.putIfAbsent(dateKey, () => []);
      groupedByDate[dateKey]!.add(classInfo);
    }

    final dates = groupedByDate.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final classes = groupedByDate[date]!;
          return _buildAdminDateSection(date, classes);
        },
      ),
    );
  }

  Widget _buildAdminDateSection(String date, List<ClassWithBookingsInfo> classes) {
    final totalBookings = classes.fold(0, (sum, c) => sum + c.bookedCount);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${classes.length} aula${classes.length > 1 ? 's' : ''} • $totalBookings reserva${totalBookings != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...classes.map(_buildAdminClassCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAdminClassCard(ClassWithBookingsInfo classInfo) {
    final isClass = classInfo.classType == 'class';
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToClassDetail(classInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícone da aula
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isClass
                          ? colorScheme.primaryContainer
                          : colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isClass ? Icons.school : Icons.pool,
                      color: isClass
                          ? colorScheme.primary
                          : colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Informações da aula
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classInfo.classTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              classInfo.formattedTime,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Ícone de seta indicando que é clicável
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Badges de reservas e vagas
              Row(
                children: [
                  _buildStatBadge(
                    icon: Icons.people,
                    label: '${classInfo.bookedCount} reserva${classInfo.bookedCount != 1 ? 's' : ''}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    icon: Icons.event_available,
                    label: '${classInfo.availableSpots} restante${classInfo.availableSpots != 1 ? 's' : ''}',
                    color: classInfo.availableSpots > 0 ? Colors.green : Colors.red,
                  ),
                  if (classInfo.checkedInCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      icon: Icons.check_circle,
                      label: '${classInfo.checkedInCount} presente${classInfo.checkedInCount != 1 ? 's' : ''}',
                      color: Colors.teal,
                    ),
                  ],
                ],
              ),
              // Preview dos alunos
              if (classInfo.students.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Avatares empilhados dos primeiros 3 alunos
                    SizedBox(
                      width: 60,
                      height: 28,
                      child: Stack(
                        children: [
                          for (int i = 0; i < classInfo.students.length.clamp(0, 3); i++)
                            Positioned(
                              left: i * 16.0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: classInfo.students[i].checkedIn
                                      ? Colors.green
                                      : colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: classInfo.students[i].checkedIn
                                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                                      : Text(
                                          classInfo.students[i].studentName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        classInfo.students.length > 3
                            ? '${classInfo.students.take(3).map((s) => s.studentName.split(' ').first).join(', ')} e +${classInfo.students.length - 3}'
                            : classInfo.students.map((s) => s.studentName.split(' ').first).join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Ver todos',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToClassDetail(ClassWithBookingsInfo classInfo) async {
    // Cria um SwimClass a partir do ClassWithBookingsInfo
    final swimClass = SwimClass(
      id: classInfo.classId,
      title: classInfo.classTitle,
      type: classInfo.classType == 'class' 
          ? SwimClassType.classType 
          : SwimClassType.free,
      startTime: classInfo.classStartTime,
      endTime: classInfo.classEndTime,
      capacity: classInfo.capacity,
      lanes: 1, // Valor padrão
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassDetailPage(
          swimClass: swimClass,
          bookedCount: classInfo.bookedCount,
        ),
      ),
    );
    _loadData();
  }

  Widget _buildClassesList() {
    // Agrupa aulas por tipo
    final groupedClasses = <SwimClassType, List<SwimClassWithAvailability>>{};
    for (final classWithAvailability in _classes!) {
      final type = classWithAvailability.swimClass.type;
      groupedClasses.putIfAbsent(type, () => []);
      groupedClasses[type]!.add(classWithAvailability);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: groupedClasses.length,
        itemBuilder: (context, index) {
          final type = groupedClasses.keys.elementAt(index);
          final classes = groupedClasses[type]!;
          return _buildTypeSection(type, classes);
        },
      ),
    );
  }

  Widget _buildTypeSection(
    SwimClassType type,
    List<SwimClassWithAvailability> classes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                type == SwimClassType.classType ? Icons.school : Icons.pool,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                type.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ...classes.map(_buildClassCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildClassCard(SwimClassWithAvailability classWithAvailability) {
    final swimClass = classWithAvailability.swimClass;
    final isClass = swimClass.type == SwimClassType.classType;
    final isLoading = _loadingBookings.contains(swimClass.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isClass
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isClass ? Icons.school : Icons.pool,
                color: isClass
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    swimClass.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    swimClass.formattedTime,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  _buildAvailabilityBadge(classWithAvailability),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!_isAdmin) _buildBookingButton(classWithAvailability, isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(SwimClassWithAvailability classWithAvailability) {
    final isFull = classWithAvailability.isFull;
    final isBooked = classWithAvailability.isBookedByCurrentUser;
    final bookedCount = classWithAvailability.bookedCount;
    final availableSpots = classWithAvailability.availableSpots;

    Color bgColor;
    Color textColor;
    String text;

    if (isBooked) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      text = 'Reservado';
    } else if (isFull) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      text = 'Lotada';
    } else {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      // Mostra reservas e restantes quando há reservas
      if (bookedCount > 0) {
        text = '$bookedCount reserva${bookedCount != 1 ? 's' : ''} • $availableSpots restante${availableSpots != 1 ? 's' : ''}';
      } else {
        text = classWithAvailability.availabilityText;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking(SwimClassWithAvailability classWithAvailability) async {
    final swimClass = classWithAvailability.swimClass;
    
    // Verifica se pode cancelar pelo deadline
    if (!BookingRules.canCancelBooking(swimClass.startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(BookingRules.cancellationDeadlineMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final remainingTime = BookingRules.timeUntilCancellationDeadline(swimClass.startTime);
    final remainingText = remainingTime != null 
        ? BookingRules.formatRemainingTime(remainingTime)
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: Colors.orange.shade600,
          ),
        ),
        title: const Text('Cancelar Reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tem certeza que deseja cancelar sua reserva?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    swimClass.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${swimClass.formattedDate} • ${swimClass.formattedTime}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            if (remainingText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Tempo restante: $remainingText',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelBookingForClass(classWithAvailability);
    }
  }

  Future<void> _cancelBookingForClass(SwimClassWithAvailability classWithAvailability) async {
    final classId = classWithAvailability.swimClass.id;

    setState(() {
      _loadingBookings.add(classId);
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final bookingResponse = await supabase
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('class_id', classId)
          .maybeSingle();

      if (bookingResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reserva não encontrada'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final bookingId = bookingResponse['id'] as String;
      final result = await _bookingService.cancelBooking(bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (result.success) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingBookings.remove(classId);
        });
      }
    }
  }

  Widget _buildBookingButton(
    SwimClassWithAvailability classWithAvailability,
    bool isLoading,
  ) {
    if (classWithAvailability.isBookedByCurrentUser) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: isLoading ? null : () => _confirmCancelBooking(classWithAvailability),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: isLoading
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red.shade400,
                  ),
                )
              : const Text('Cancelar'),
        ),
      );
    }

    if (classWithAvailability.isFull) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.block, color: Colors.grey.shade400, size: 20),
      );
    }

    return SizedBox(
      width: 80,
      height: 32,
      child: FilledButton(
        onPressed: isLoading ? null : () => _bookClass(classWithAvailability),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Reservar'),
      ),
    );
  }

  String _extractName(String email) {
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final name = parts[0].replaceAll('.', ' ');
      return name.split(' ').map((s) => _capitalize(s)).join(' ');
    }
    return email;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _formatDateBR(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await supabase.auth.signOut();
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

  void _navigateToAdminPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminPanelPage(),
      ),
    );
  }

  void _navigateToClasses(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ClassesListPage(),
      ),
    );
    _loadData();
  }

  void _navigateToMyBookings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MyBookingsPage(),
      ),
    );
    _loadData();
  }

  void _navigateToCalendar(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalendarPage(),
      ),
    );
    _loadData();
  }

  void _navigateToAttendance(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AttendanceHistoryPage(),
      ),
    );
  }

  void _navigateToMemberships(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MyMembershipsPage(),
      ),
    );
    _loadData();
  }

  void _navigateToProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfilePage(themeProvider: themeProvider),
      ),
    );
  }

  void _navigateToSelectBusiness(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectBusinessPage(),
      ),
    );
    _loadData();
  }
}
