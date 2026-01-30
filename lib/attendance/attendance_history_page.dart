import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/swim_class.dart';
import '../services/booking_service.dart';
import '../widgets/skeleton_loading.dart';

/// Página de Histórico de Frequência
/// 
/// Exibe as aulas que o usuário participou (check-in confirmado)
class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final _bookingService = BookingService();

  List<Booking>? _attendedClasses;
  bool _isLoading = true;
  String? _error;

  // Estatísticas
  int _totalAttended = 0;
  int _classesThisMonth = 0;
  int _classesThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.fetchMyBookings();
      
      // Filtra apenas aulas passadas (com check-in ou que já aconteceram)
      final now = DateTime.now();
      final attendedClasses = bookings.where((b) {
        if (b.swimClass == null) return false;
        return b.swimClass!.startTime.isBefore(now);
      }).toList();

      // Ordena por data mais recente primeiro
      attendedClasses.sort((a, b) => 
        b.swimClass!.startTime.compareTo(a.swimClass!.startTime));

      // Calcula estatísticas
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      int thisMonth = 0;
      int thisWeek = 0;

      for (final booking in attendedClasses) {
        final classDate = booking.swimClass!.startTime;
        if (classDate.isAfter(startOfMonth)) {
          thisMonth++;
        }
        if (classDate.isAfter(startOfWeek)) {
          thisWeek++;
        }
      }

      if (mounted) {
        setState(() {
          _attendedClasses = attendedClasses;
          _totalAttended = attendedClasses.length;
          _classesThisMonth = thisMonth;
          _classesThisWeek = thisWeek;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar histórico: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Frequência'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const ClassesListSkeleton();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildHistoryList(),
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
              onPressed: _loadAttendance,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.pool,
            label: 'Total',
            value: '$_totalAttended',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_month,
            label: 'Este mês',
            value: '$_classesThisMonth',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            label: 'Esta semana',
            value: '$_classesThisWeek',
            color: Colors.orange,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_attendedClasses == null || _attendedClasses!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nenhuma aula frequentada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Faça reservas e participe das aulas para ver seu histórico.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Agrupa por mês
    final groupedByMonth = <String, List<Booking>>{};
    for (final booking in _attendedClasses!) {
      final monthKey = _formatMonthYear(booking.swimClass!.startTime);
      groupedByMonth.putIfAbsent(monthKey, () => []);
      groupedByMonth[monthKey]!.add(booking);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedByMonth.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            ...entry.value.map(_buildAttendanceCard),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceCard(Booking booking) {
    final swimClass = booking.swimClass!;
    final isClass = swimClass.type == SwimClassType.classType;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade700,
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
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        swimClass.formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        swimClass.formattedTime,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(isClass ? 'Aula' : 'Nado Livre'),
              backgroundColor: isClass
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: isClass
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                fontSize: 11,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
