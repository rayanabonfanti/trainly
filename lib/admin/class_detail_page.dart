import 'package:flutter/material.dart';

import '../core/supabase_client.dart';
import '../core/theme_provider.dart';
import '../models/swim_class.dart';
import '../services/booking_service.dart';

/// Página de detalhes da aula para Admin
///
/// Mostra lista de alunos que reservaram e permite fazer check-in
/// clicando em cada aluno
class ClassDetailPage extends StatefulWidget {
  final SwimClass swimClass;
  final int bookedCount;

  const ClassDetailPage({
    super.key,
    required this.swimClass,
    required this.bookedCount,
  });

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  final _bookingService = BookingService();

  List<Map<String, dynamic>>? _bookings;
  Set<String> _checkedInIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  int get _availableSpots => widget.swimClass.capacity - (_bookings?.length ?? widget.bookedCount);
  int get _bookedCount => _bookings?.length ?? widget.bookedCount;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.fetchBookingsForClass(widget.swimClass.id);

      // Carrega status de check-in
      final checkedIn = <String>{};
      for (final booking in bookings) {
        if (booking['checked_in'] == true) {
          checkedIn.add(booking['id'] as String);
        }
      }

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _checkedInIds = checkedIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar alunos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleCheckIn(String bookingId) async {
    final isCheckedIn = _checkedInIds.contains(bookingId);

    // Atualiza UI otimisticamente
    setState(() {
      if (isCheckedIn) {
        _checkedInIds.remove(bookingId);
      } else {
        _checkedInIds.add(bookingId);
      }
    });

    try {
      await supabase
          .from('bookings')
          .update({'checked_in': !isCheckedIn})
          .eq('id', bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !isCheckedIn ? 'Check-in realizado!' : 'Check-in removido',
            ),
            backgroundColor: !isCheckedIn ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Reverte em caso de erro
      if (mounted) {
        setState(() {
          if (isCheckedIn) {
            _checkedInIds.add(bookingId);
          } else {
            _checkedInIds.remove(bookingId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar check-in: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _checkInAll() async {
    if (_bookings == null) return;

    setState(() => _isSaving = true);

    try {
      final bookingIds = _bookings!.map((b) => b['id'] as String).toList();

      await supabase
          .from('bookings')
          .update({'checked_in': true})
          .inFilter('id', bookingIds);

      setState(() {
        _checkedInIds = bookingIds.toSet();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos marcados como presentes!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
              colorScheme.primary.withOpacity(0.1),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, colorScheme),
              _buildClassHeader(colorScheme),
              _buildAvailabilityInfo(colorScheme),
              const Divider(height: 1),
              Expanded(child: _buildBody(colorScheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
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
              'Detalhes da Aula',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (_bookings != null && _bookings!.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _checkInAll,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Todos'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassHeader(ColorScheme colorScheme) {
    final swimClass = widget.swimClass;
    final isClass = swimClass.type == SwimClassType.classType;
    final presentCount = _checkedInIds.length;
    final totalCount = _bookings?.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isClass
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isClass ? Icons.school : Icons.fitness_center,
              color: isClass
                  ? colorScheme.primary
                  : colorScheme.secondary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  swimClass.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      swimClass.formattedDate,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
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
          if (totalCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, size: 18, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '$presentCount/$totalCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'presentes',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityInfo(ColorScheme colorScheme) {
    final capacity = widget.swimClass.capacity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              icon: Icons.people,
              label: 'Reservas',
              value: '$_bookedCount',
              color: AppColors.cyanPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.event_available,
              label: 'Vagas Restantes',
              value: '$_availableSpots',
              color: _availableSpots > 0 ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.groups,
              label: 'Capacidade',
              value: '$capacity',
              color: AppColors.cyanPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_bookings == null || _bookings!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma reserva',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ainda não há alunos inscritos nesta aula',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.people, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Alunos Inscritos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cyanLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_bookings!.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyanDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Toque em um aluno para marcar presença',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _bookings!.length,
              itemBuilder: (context, index) {
                final booking = _bookings![index];
                return _buildStudentCard(booking, colorScheme);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> booking, ColorScheme colorScheme) {
    final bookingId = booking['id'] as String;
    final profile = booking['profiles'] as Map<String, dynamic>?;
    final email = profile?['email'] as String? ?? 'Email desconhecido';
    final name = profile?['name'] as String?;
    final displayName = name ?? _formatDisplayName(email.split('@')[0]);
    final isCheckedIn = _checkedInIds.contains(bookingId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCheckedIn ? Colors.green.shade50 : null,
      elevation: isCheckedIn ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCheckedIn ? Colors.green.shade200 : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleCheckIn(bookingId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar com animação
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.green
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isCheckedIn
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : Center(
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // Informações do aluno
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isCheckedIn ? Colors.green.shade700 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: isCheckedIn
                            ? Colors.green.shade600
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.green
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCheckedIn ? Icons.check : Icons.radio_button_unchecked,
                      size: 14,
                      color: isCheckedIn ? Colors.white : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCheckedIn ? 'Presente' : 'Ausente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCheckedIn ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDisplayName(String name) {
    return name.split(' ').map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }).join(' ');
  }
}
