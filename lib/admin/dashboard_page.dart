import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/supabase_client.dart';
import '../services/booking_service.dart';
import '../services/classes_service.dart';
import '../widgets/skeleton_loading.dart';

/// Dashboard com estatísticas para Admin
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _classesService = ClassesService();
  final _bookingService = BookingService();

  bool _isLoading = true;
  String? _error;

  // Estatísticas
  int _totalClasses = 0;
  int _totalBookings = 0;
  int _totalCheckIns = 0;
  double _occupancyRate = 0.0;
  List<DayOccupancy> _weeklyOccupancy = [];
  List<ClassTypeStats> _classTypeStats = [];
  List<Map<String, dynamic>> _popularClasses = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Busca todas as aulas
      final classes = await _classesService.fetchClasses();
      
      // Cria um mapa de classes por ID para lookup rápido
      final classesMap = <String, dynamic>{};
      for (final c in classes) {
        classesMap[c.id] = {
          'id': c.id,
          'title': c.title,
          'start_time': c.startTime.toIso8601String(),
          'end_time': c.endTime.toIso8601String(),
          'type': c.type.value,
          'capacity': c.capacity,
        };
      }
      
      // Busca todas as reservas (sem join)
      final bookingsResponse = await supabase
          .from('bookings')
          .select('*');

      // Adiciona os dados da classe a cada booking
      final bookings = (bookingsResponse as List).map((b) {
        return {
          ...b,
          'classes': classesMap[b['class_id']],
        };
      }).toList();

      // Conta check-ins
      int checkIns = 0;
      for (final booking in bookings) {
        if (booking['checked_in'] == true) {
          checkIns++;
        }
      }

      // Calcula taxa de ocupação
      int totalCapacity = 0;
      for (final c in classes) {
        totalCapacity += c.capacity;
      }
      final occupancy = totalCapacity > 0 
          ? (bookings.length / totalCapacity) * 100 
          : 0.0;

      // Calcula ocupação semanal
      final weeklyOccupancy = _calculateWeeklyOccupancy(classes, bookings);

      // Calcula estatísticas por tipo
      final classTypeStats = _calculateTypeStats(classes, bookings);

      // Aulas mais populares
      final popularClasses = _calculatePopularClasses(classes, bookings);

      if (mounted) {
        setState(() {
          _totalClasses = classes.length;
          _totalBookings = bookings.length;
          _totalCheckIns = checkIns;
          _occupancyRate = occupancy;
          _weeklyOccupancy = weeklyOccupancy;
          _classTypeStats = classTypeStats;
          _popularClasses = popularClasses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar estatísticas: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<DayOccupancy> _calculateWeeklyOccupancy(
    List classes,
    List bookings,
  ) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final result = <DayOccupancy>[];

    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int dayCapacity = 0;
      int dayBookings = 0;

      for (final c in classes) {
        if (c.startTime.isAfter(dayStart) && c.startTime.isBefore(dayEnd)) {
          dayCapacity += (c.capacity as num).toInt();
        }
      }

      for (final b in bookings) {
        final classData = b['classes'];
        if (classData != null) {
          final startTime = DateTime.parse(classData['start_time']);
          if (startTime.isAfter(dayStart) && startTime.isBefore(dayEnd)) {
            dayBookings++;
          }
        }
      }

      final occupancy = dayCapacity > 0 
          ? (dayBookings / dayCapacity) * 100 
          : 0.0;

      result.add(DayOccupancy(
        day: days[i],
        occupancy: occupancy.clamp(0, 100),
        bookings: dayBookings,
      ));
    }

    return result;
  }

  List<ClassTypeStats> _calculateTypeStats(List classes, List bookings) {
    int classCount = 0;
    int freeCount = 0;
    int classBookings = 0;
    int freeBookings = 0;

    for (final c in classes) {
      if (c.type.value == 'class') {
        classCount++;
      } else {
        freeCount++;
      }
    }

    for (final b in bookings) {
      final classData = b['classes'];
      if (classData != null) {
        if (classData['type'] == 'class') {
          classBookings++;
        } else {
          freeBookings++;
        }
      }
    }

    return [
      ClassTypeStats(
        type: 'Aulas',
        count: classCount,
        bookings: classBookings,
        color: Colors.blue,
      ),
      ClassTypeStats(
        type: 'Nado Livre',
        count: freeCount,
        bookings: freeBookings,
        color: Colors.teal,
      ),
    ];
  }

  List<Map<String, dynamic>> _calculatePopularClasses(
    List classes,
    List bookings,
  ) {
    final bookingCount = <String, int>{};
    
    for (final b in bookings) {
      final classId = b['class_id'] as String;
      bookingCount[classId] = (bookingCount[classId] ?? 0) + 1;
    }

    final popular = <Map<String, dynamic>>[];
    for (final c in classes) {
      final count = bookingCount[c.id] ?? 0;
      if (count > 0) {
        popular.add({
          'title': c.title,
          'date': c.formattedDate,
          'bookings': count,
          'capacity': c.capacity,
          'occupancy': (count / c.capacity * 100).clamp(0, 100),
        });
      }
    }

    popular.sort((a, b) => (b['bookings'] as int).compareTo(a['bookings'] as int));
    return popular.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Expanded(child: StatCardSkeleton()),
                SizedBox(width: 16),
                Expanded(child: StatCardSkeleton()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: StatCardSkeleton()),
                SizedBox(width: 16),
                Expanded(child: StatCardSkeleton()),
              ],
            ),
          ],
        ),
      );
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
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildSectionTitle('Ocupação Semanal'),
            const SizedBox(height: 16),
            _buildWeeklyChart(),
            const SizedBox(height: 24),
            _buildSectionTitle('Distribuição por Tipo'),
            const SizedBox(height: 16),
            _buildTypeChart(),
            const SizedBox(height: 24),
            _buildSectionTitle('Aulas Mais Populares'),
            const SizedBox(height: 16),
            _buildPopularClasses(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.pool,
                label: 'Total de Aulas',
                value: '$_totalClasses',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_month,
                label: 'Reservas',
                value: '$_totalBookings',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'Check-ins',
                value: '$_totalCheckIns',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pie_chart,
                label: 'Ocupação',
                value: '${_occupancyRate.toStringAsFixed(1)}%',
                color: Colors.purple,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyOccupancy.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Sem dados disponíveis'),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = _weeklyOccupancy[group.x.toInt()];
                return BarTooltipItem(
                  '${day.day}\n${day.occupancy.toStringAsFixed(1)}%\n${day.bookings} reservas',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < _weeklyOccupancy.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _weeklyOccupancy[value.toInt()].day,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 25,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          barGroups: _weeklyOccupancy.asMap().entries.map((entry) {
            final color = entry.value.occupancy > 70
                ? Colors.green
                : entry.value.occupancy > 40
                    ? Colors.orange
                    : Colors.red;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.occupancy,
                  color: color,
                  width: 24,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTypeChart() {
    if (_classTypeStats.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Sem dados disponíveis'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 120,
            width: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: _classTypeStats.map((stat) {
                  final total = _classTypeStats.fold<int>(
                    0,
                    (sum, s) => sum + s.bookings,
                  );
                  final percentage = total > 0 
                      ? (stat.bookings / total * 100) 
                      : 0.0;
                  return PieChartSectionData(
                    color: stat.color,
                    value: stat.bookings.toDouble(),
                    title: '${percentage.toStringAsFixed(0)}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _classTypeStats.map((stat) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: stat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stat.type,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${stat.bookings} reservas',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularClasses() {
    if (_popularClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Nenhuma reserva ainda'),
        ),
      );
    }

    return Column(
      children: _popularClasses.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: index == 0
                      ? Colors.amber
                      : index == 1
                          ? Colors.grey[400]
                          : index == 2
                              ? Colors.brown[300]
                              : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: index < 3 ? Colors.white : Colors.grey[600],
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
                      c['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      c['date'] as String,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${c['bookings']}/${c['capacity']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (c['occupancy'] as double) > 80
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(c['occupancy'] as double).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (c['occupancy'] as double) > 80
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class DayOccupancy {
  final String day;
  final double occupancy;
  final int bookings;

  DayOccupancy({
    required this.day,
    required this.occupancy,
    required this.bookings,
  });
}

class ClassTypeStats {
  final String type;
  final int count;
  final int bookings;
  final Color color;

  ClassTypeStats({
    required this.type,
    required this.count,
    required this.bookings,
    required this.color,
  });
}
