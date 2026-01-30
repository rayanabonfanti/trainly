import 'package:flutter/material.dart';

import '../core/supabase_client.dart';
import '../models/swim_class.dart';
import '../services/booking_service.dart';
import '../services/classes_service.dart';

/// Página de Check-in para Admin
/// 
/// Permite ao admin marcar quem compareceu na aula
class CheckInPage extends StatefulWidget {
  final SwimClass swimClass;

  const CheckInPage({
    super.key,
    required this.swimClass,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _bookingService = BookingService();

  List<Map<String, dynamic>>? _bookings;
  Set<String> _checkedInIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_bookings != null && _bookings!.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _checkInAll,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marcar Todos'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildClassHeader(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildClassHeader() {
    final swimClass = widget.swimClass;
    final isClass = swimClass.type == SwimClassType.classType;
    final presentCount = _checkedInIds.length;
    final totalCount = _bookings?.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
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
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  swimClass.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${swimClass.formattedDate} • ${swimClass.formattedTime}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '$presentCount/$totalCount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma reserva para esta aula',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings!.length,
      itemBuilder: (context, index) {
        final booking = _bookings![index];
        return _buildStudentCard(booking);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> booking) {
    final bookingId = booking['id'] as String;
    final profile = booking['profiles'] as Map<String, dynamic>?;
    final email = profile?['email'] as String? ?? 'Email desconhecido';
    final name = profile?['name'] as String?;
    final displayName = name ?? email.split('@')[0];
    final isCheckedIn = _checkedInIds.contains(bookingId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCheckedIn
          ? Colors.green.shade50
          : null,
      child: InkWell(
        onTap: () => _toggleCheckIn(bookingId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isCheckedIn
                    ? Colors.green.shade200
                    : Theme.of(context).colorScheme.primaryContainer,
                child: isCheckedIn
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text(
                        displayName[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayName(displayName),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? Colors.green
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCheckedIn ? Icons.check : Icons.remove,
                  color: isCheckedIn ? Colors.white : Colors.grey[500],
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
