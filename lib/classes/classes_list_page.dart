import 'package:flutter/material.dart';

import '../admin/check_in_page.dart';
import '../core/supabase_client.dart';
import '../core/theme_provider.dart';
import '../models/booking.dart';
import '../models/class_type.dart';
import '../models/swim_class.dart';
import '../services/admin_service.dart';
import '../services/booking_service.dart';
import '../services/classes_service.dart';
import '../services/settings_service.dart';
import '../widgets/skeleton_loading.dart';
import 'class_form_page.dart';

/// Tela de listagem de aulas - Design moderno
///
/// - Admins: veem quem reservou cada aula + gerenciam aulas
/// - Alunos: podem visualizar e reservar aulas disponíveis
class ClassesListPage extends StatefulWidget {
  const ClassesListPage({super.key});

  @override
  State<ClassesListPage> createState() => _ClassesListPageState();
}

class _ClassesListPageState extends State<ClassesListPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _classesService = ClassesService();
  final _adminService = AdminService();
  final _bookingService = BookingService();
  final _settingsService = SettingsService();

  List<SwimClassWithAvailability>? _classes;
  Map<String, List<Map<String, dynamic>>> _bookingsByClass = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;
  Set<String> _loadingBookings = {};
  List<ClassType> _classTypes = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _bookingService.fetchAvailableClasses(),
        _adminService.isCurrentUserAdmin(),
      ]);

      final classes = results[0] as List<SwimClassWithAvailability>;
      final isAdmin = results[1] as bool;

      // Se admin, busca quem reservou cada aula
      Map<String, List<Map<String, dynamic>>> bookingsByClass = {};
      if (isAdmin && classes.isNotEmpty) {
        final classIds = classes.map((c) => c.swimClass.id).toList();
        bookingsByClass = await _bookingService.fetchAllBookingsByClass(classIds);
      }

      // Se admin, carrega tipos de aula
      List<ClassType> classTypes = [];
      if (isAdmin) {
        try {
          final settings = await _settingsService.getSettings();
          classTypes = settings.classTypes;
        } catch (_) {
          classTypes = ClassType.defaults;
        }
      }

      if (mounted) {
        setState(() {
          _classes = classes;
          _isAdmin = isAdmin;
          _bookingsByClass = bookingsByClass;
          _classTypes = classTypes;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar aulas: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToForm([SwimClass? swimClass]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ClassFormPage(swimClass: swimClass),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _navigateToCheckIn(SwimClass swimClass) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckInPage(swimClass: swimClass),
      ),
    );
    _loadData();
  }

  Future<void> _confirmDelete(SwimClass swimClass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir a aula "${swimClass.title}"?\n\n'
          'Esta ação não pode ser desfeita.',
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteClass(swimClass);
    }
  }

  Future<void> _deleteClass(SwimClass swimClass) async {
    final result = await _classesService.deleteClass(swimClass.id);

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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.08),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(context, colorScheme),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nova Aula'),
            )
          : null,
    );
  }

  Widget _buildCustomAppBar(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _isAdmin ? 'Gerenciar Aulas' : 'Aulas Disponíveis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (_isAdmin)
            IconButton(
              onPressed: _showManageClassTypesDialog,
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Tipos de Aula',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageClassTypesDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassTypesBottomSheet(
        classTypes: _classTypes,
        settingsService: _settingsService,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const ClassesListSkeleton();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_classes == null || _classes!.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildClassesList(),
    );
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
            Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Nenhuma aula disponível',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'Clique no botão "+" para criar a primeira aula.'
                  : 'Não há aulas disponíveis para agendamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList() {
    // Agrupa aulas por data
    final groupedClasses = <String, List<SwimClassWithAvailability>>{};
    for (final classWithAvailability in _classes!) {
      final dateKey = classWithAvailability.swimClass.formattedDate;
      groupedClasses.putIfAbsent(dateKey, () => []);
      groupedClasses[dateKey]!.add(classWithAvailability);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 100,
        ),
        itemCount: groupedClasses.length,
        itemBuilder: (context, index) {
          final dateKey = groupedClasses.keys.elementAt(index);
          final classes = groupedClasses[dateKey]!;
          return _buildDateSection(dateKey, classes);
        },
      ),
    );
  }

  Widget _buildDateSection(String date, List<SwimClassWithAvailability> classes) {
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
                      color: Theme.of(context).colorScheme.primary,
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
    final bookings = _bookingsByClass[swimClass.id] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _isAdmin ? () => _navigateToForm(swimClass) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isClass
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isClass ? Icons.school : Icons.fitness_center,
                      color: isClass
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          swimClass.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              swimClass.formattedTime,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _navigateToForm(swimClass),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      onPressed: () => _confirmDelete(swimClass),
                      tooltip: 'Excluir',
                    ),
                  ],
                ],
              ),
              if (swimClass.description != null &&
                  swimClass.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  swimClass.description!,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAvailabilityChip(classWithAvailability),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.view_week,
                    '${swimClass.lanes} vagas',
                  ),
                  const Spacer(),
                  // Aluno: botão de reservar
                  if (!_isAdmin) _buildBookingButton(classWithAvailability, isLoading),
                ],
              ),
              // Admin: lista de quem reservou
              if (_isAdmin && bookings.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildBookingsList(bookings),
              ],
              // Admin: mensagem quando ninguém reservou
              if (_isAdmin && bookings.isEmpty && classWithAvailability.bookedCount == 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Nenhuma reserva ainda',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Admin: botão de check-in
              if (_isAdmin && bookings.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToCheckIn(swimClass),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Fazer Check-in'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              'Alunos Inscritos (${bookings.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bookings.map((booking) {
            final profile = booking['profiles'] as Map<String, dynamic>?;
            final email = profile?['email'] as String? ?? 'Email desconhecido';
            final name = profile?['name'] as String?;
            final displayName = name ?? email.split('@')[0];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cyanLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyanLight.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.cyanPrimary,
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.cyanDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAvailabilityChip(SwimClassWithAvailability classWithAvailability) {
    final isFull = classWithAvailability.isFull;
    final isBooked = classWithAvailability.isBookedByCurrentUser;
    final bookedCount = classWithAvailability.bookedCount;
    final availableSpots = classWithAvailability.availableSpots;

    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    if (_isAdmin) {
      // Para admin, mostra reservas e restantes
      if (isFull) {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.block;
        text = 'Lotada ($bookedCount/${classWithAvailability.swimClass.capacity})';
      } else if (bookedCount > 0) {
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.people;
        text = '$bookedCount reserva${bookedCount != 1 ? 's' : ''} • $availableSpots restante${availableSpots != 1 ? 's' : ''}';
      } else {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.event_available;
        text = '$availableSpots vagas disponíveis';
      }
    } else {
      // Para aluno
      if (isBooked) {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        text = 'Reservado';
      } else if (isFull) {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.block;
        text = 'Lotada';
      } else {
        bgColor = AppColors.cyanLight.withValues(alpha: 0.2);
        textColor = AppColors.cyanDark;
        icon = Icons.people;
        // Mostra reservas e restantes quando há reservas
        if (bookedCount > 0) {
          text = '$bookedCount reserva${bookedCount != 1 ? 's' : ''} • $availableSpots restante${availableSpots != 1 ? 's' : ''}';
        } else {
          text = classWithAvailability.availabilityText;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelBooking(SwimClassWithAvailability classWithAvailability) async {
    final swimClass = classWithAvailability.swimClass;

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
      // Busca o booking do usuário para esta aula
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
        height: 36,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : () => _confirmCancelBooking(classWithAvailability),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red.shade400,
                  ),
                )
              : const Icon(Icons.close, size: 16),
          label: Text(isLoading ? 'Cancelando...' : 'Cancelar'),
        ),
      );
    }

    if (classWithAvailability.isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Lotada',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: isLoading ? null : () => _bookClass(classWithAvailability),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Reservar'),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet para gerenciar tipos de aula
class _ClassTypesBottomSheet extends StatefulWidget {
  final List<ClassType> classTypes;
  final SettingsService settingsService;

  const _ClassTypesBottomSheet({
    required this.classTypes,
    required this.settingsService,
  });

  @override
  State<_ClassTypesBottomSheet> createState() => _ClassTypesBottomSheetState();
}

class _ClassTypesBottomSheetState extends State<_ClassTypesBottomSheet> {
  late List<ClassType> _classTypes;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _classTypes = List.from(widget.classTypes);
  }

  void _addClassType() async {
    final result = await showDialog<ClassType>(
      context: context,
      builder: (context) => const _ClassTypeDialog(),
    );

    if (result != null) {
      if (_classTypes.any((t) => t.id == result.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Já existe um tipo com esse identificador'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() {
        _classTypes.add(result);
        _hasChanges = true;
      });
    }
  }

  void _editClassType(int index) async {
    final result = await showDialog<ClassType>(
      context: context,
      builder: (context) => _ClassTypeDialog(classType: _classTypes[index]),
    );

    if (result != null) {
      setState(() {
        _classTypes[index] = result;
        _hasChanges = true;
      });
    }
  }

  void _removeClassType(int index) async {
    if (_classTypes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário ter pelo menos um tipo de aula'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, size: 48, color: Colors.red),
        title: const Text('Remover Tipo'),
        content: Text(
          'Tem certeza que deseja remover "${_classTypes[index].name}"?\n\n'
          'Aulas existentes com este tipo não serão afetadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _classTypes.removeAt(index);
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final settings = await widget.settingsService.getSettings();
      final newSettings = settings.copyWith(classTypes: _classTypes);
      final result = await widget.settingsService.updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (result.success) {
          Navigator.of(context).pop(true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyanPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.category,
                    color: AppColors.cyanPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tipos de Aula',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Gerencie os tipos disponíveis',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: _classTypes.length,
              itemBuilder: (context, index) {
                final classType = _classTypes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cyanPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        classType.iconData,
                        color: AppColors.cyanPrimary,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      classType.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'ID: ${classType.id}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editClassType(index),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: _classTypes.length > 1 ? Colors.red : Colors.grey,
                          ),
                          onPressed: _classTypes.length > 1
                              ? () => _removeClassType(index)
                              : null,
                          tooltip: 'Remover',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addClassType,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Tipo'),
                  ),
                ),
                if (_hasChanges) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Dialog para adicionar/editar tipo de aula
class _ClassTypeDialog extends StatefulWidget {
  final ClassType? classType;

  const _ClassTypeDialog({this.classType});

  @override
  State<_ClassTypeDialog> createState() => _ClassTypeDialogState();
}

class _ClassTypeDialogState extends State<_ClassTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  String _selectedIcon = 'school';

  bool get _isEditing => widget.classType != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.classType?.id ?? '');
    _nameController = TextEditingController(text: widget.classType?.name ?? '');
    _selectedIcon = widget.classType?.icon ?? 'school';
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final classType = ClassType(
      id: _idController.text.trim().toLowerCase().replaceAll(' ', '_'),
      name: _nameController.text.trim(),
      icon: _selectedIcon,
    );

    Navigator.of(context).pop(classType);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Tipo' : 'Novo Tipo de Aula'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'Ex: Hidroginástica',
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  if (value.trim().length > 50) {
                    return 'Máximo 50 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idController,
                enabled: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'Identificador *',
                  hintText: 'Ex: hidroginastica',
                  prefixIcon: const Icon(Icons.key),
                  helperText: _isEditing ? 'Não pode ser alterado' : 'Sem espaços ou acentos',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Identificador é obrigatório';
                  }
                  if (value.contains(' ') ||
                      !RegExp(r'^[a-z0-9_]+$').hasMatch(value.trim().toLowerCase())) {
                    return 'Use apenas letras minúsculas, números e _';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Ícone',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ClassTypeIcons.availableIcons.map((iconData) {
                  final iconName = iconData['name'] as String;
                  final isSelected = _selectedIcon == iconName;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = iconName;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        ClassTypeIcons.getIconData(iconName),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[700],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}
