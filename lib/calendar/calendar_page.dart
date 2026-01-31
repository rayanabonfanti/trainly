import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/supabase_client.dart';
import '../models/booking.dart';
import '../models/swim_class.dart';
import '../services/admin_service.dart';
import '../services/booking_service.dart';
import '../widgets/skeleton_loading.dart';

/// Página de Calendário - visualização de aulas em formato calendário
/// Design moderno com animações
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _bookingService = BookingService();
  final _adminService = AdminService();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  Map<DateTime, List<SwimClassWithAvailability>> _events = {};
  List<SwimClassWithAvailability>? _selectedDayClasses;
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;
  Set<String> _loadingBookings = {};

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
    _selectedDay = DateTime.now();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

      // Agrupa aulas por data
      final events = <DateTime, List<SwimClassWithAvailability>>{};
      for (final c in classes) {
        final date = _normalizeDate(c.swimClass.startTime);
        events.putIfAbsent(date, () => []);
        events[date]!.add(c);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _isAdmin = isAdmin;
          _isLoading = false;
          _updateSelectedDayClasses();
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

  void _updateSelectedDayClasses() {
    if (_selectedDay != null) {
      final normalizedDay = _normalizeDate(_selectedDay!);
      _selectedDayClasses = _events[normalizedDay];
    }
  }

  List<SwimClassWithAvailability> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
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
              Expanded(
                child: _isLoading
                    ? const ClassesListSkeleton()
                    : _error != null
                        ? _buildErrorState()
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildCalendarView(),
                          ),
              ),
            ],
          ),
        ),
      ),
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
              'Calendário',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
                _updateSelectedDayClasses();
              });
            },
            icon: const Icon(Icons.today_rounded),
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

  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildCalendar(),
        const Divider(height: 1),
        Expanded(child: _buildDayClasses()),
      ],
    );
  }

  Widget _buildCalendar() {
    return TableCalendar<SwimClassWithAvailability>(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      locale: 'pt_BR',
      calendarStyle: CalendarStyle(
        markersMaxCount: 3,
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        formatButtonTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _updateSelectedDayClasses();
          });
        }
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
    );
  }

  Widget _buildDayClasses() {
    if (_selectedDayClasses == null || _selectedDayClasses!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aula neste dia',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _selectedDayClasses!.length,
        itemBuilder: (context, index) {
          return _buildClassCard(_selectedDayClasses![index]);
        },
      ),
    );
  }

  Widget _buildClassCard(SwimClassWithAvailability classWithAvailability) {
    final swimClass = classWithAvailability.swimClass;
    final isClass = swimClass.type == SwimClassType.classType;
    final isLoading = _loadingBookings.contains(swimClass.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                isClass ? Icons.school : Icons.pool,
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
}
