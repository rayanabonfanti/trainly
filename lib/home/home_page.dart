import 'package:flutter/material.dart';

import '../admin/admin_panel_page.dart';
import '../attendance/attendance_history_page.dart';
import '../bookings/my_bookings_page.dart';
import '../calendar/calendar_page.dart';
import '../classes/classes_list_page.dart';
import '../core/booking_rules.dart';
import '../core/supabase_client.dart';
import '../main.dart';
import '../models/booking.dart';
import '../models/swim_class.dart';
import '../profile/profile_page.dart';
import '../services/admin_service.dart';
import '../services/booking_service.dart';
import '../widgets/skeleton_loading.dart';

/// Tela Home - exibe aulas do dia seguinte com opção de reserva
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _bookingService = BookingService();
  final _adminService = AdminService();

  List<SwimClassWithAvailability>? _classes;
  List<StudentBookingInfo>? _adminBookings;
  String? _error;
  bool _isLoading = true;
  bool _isAdmin = false;
  Set<String> _loadingBookings = {};

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
        // Admin: carrega lista de reservas com info do aluno
        final bookings = await _bookingService.fetchAllBookingsWithStudentInfo();
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _adminBookings = bookings;
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

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Email não disponível';
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainly'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _navigateToCalendar(context),
            tooltip: 'Calendário',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: _buildDrawer(userEmail),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(userEmail, tomorrow),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDrawer(String userEmail) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    _extractName(userEmail)[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _extractName(userEmail),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendário'),
            onTap: () {
              Navigator.pop(context);
              _navigateToCalendar(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.pool),
            title: const Text('Todas as Aulas'),
            onTap: () {
              Navigator.pop(context);
              _navigateToClasses(context);
            },
          ),
          if (!_isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Minhas Reservas'),
              onTap: () {
                Navigator.pop(context);
                _navigateToMyBookings(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico de Frequência'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAttendance(context);
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Meu Perfil'),
            onTap: () {
              Navigator.pop(context);
              _navigateToProfile(context);
            },
          ),
          if (_isAdmin) ...[
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Painel Admin',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToAdminPanel(context);
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _signOut(context);
            },
          ),
        ],
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

    // Admin: mostra lista de reservas
    if (_isAdmin) {
      if (_adminBookings == null || _adminBookings!.isEmpty) {
        return _buildAdminEmptyState();
      }
      return _buildAdminBookingsList();
    }

    // Aluno: mostra aulas disponíveis
    if (_classes == null || _classes!.isEmpty) {
      return _buildEmptyState();
    }

    return _buildClassesList();
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aula disponível para amanhã',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _navigateToClasses(context),
              icon: const Icon(Icons.pool),
              label: const Text('Ver todas as aulas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEmptyState() {
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
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma reserva',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não há reservas futuras no momento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _navigateToAdminPanel(context),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Ir para Painel Admin'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminBookingsList() {
    // Agrupa por data
    final groupedByDate = <String, List<StudentBookingInfo>>{};
    for (final booking in _adminBookings!) {
      final dateKey = booking.formattedDate;
      groupedByDate.putIfAbsent(dateKey, () => []);
      groupedByDate[dateKey]!.add(booking);
    }

    final dates = groupedByDate.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final bookings = groupedByDate[date]!;
          return _buildAdminDateSection(date, bookings);
        },
      ),
    );
  }

  Widget _buildAdminDateSection(String date, List<StudentBookingInfo> bookings) {
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
                  '${bookings.length} reserva${bookings.length > 1 ? 's' : ''}',
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
        ...bookings.map(_buildAdminBookingCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAdminBookingCard(StudentBookingInfo booking) {
    final isClass = booking.classType == 'class';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar do aluno
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                booking.studentName.isNotEmpty 
                    ? booking.studentName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Informações
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isClass ? Icons.school : Icons.pool,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${booking.classTitle} • ${booking.formattedTime}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge de reservas restantes
            _buildRemainingBadge(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingBadge(StudentBookingInfo booking) {
    Color bgColor;
    Color textColor;
    
    if (booking.remainingBookings < 0) {
      // Sem limite
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
    } else if (booking.remainingBookings == 0) {
      // Limite atingido
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else if (booking.remainingBookings == 1) {
      // Quase no limite
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    } else {
      // Várias restantes
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            booking.remainingBookings < 0 
                ? '∞' 
                : '${booking.remainingBookings}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            'restante${booking.remainingBookings != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 9,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

    Color bgColor;
    Color textColor;

    if (isBooked) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (isFull) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isBooked ? 'Reservado' : classWithAvailability.availabilityText,
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

  void _navigateToProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfilePage(themeProvider: themeProvider),
      ),
    );
  }
}
