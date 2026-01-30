import 'package:flutter/material.dart';

import '../admin/admin_panel_page.dart';
import '../core/supabase_client.dart';
import '../models/class_item.dart';
import '../services/admin_service.dart';
import '../services/supabase_service.dart';

/// Tela Home - exibe aulas do dia seguinte
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabaseService = SupabaseService();
  final _adminService = AdminService();

  List<ClassItem>? _classes;
  String? _error;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final classes = await _supabaseService.getClassesByDate(tomorrow);

      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar aulas: $e';
        _isLoading = false;
      });
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
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => _navigateToAdminPanel(context),
              tooltip: 'Painel Admin',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(userEmail, tomorrow),
          Expanded(child: _buildBody()),
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
            'Aulas de amanhã (${_formatDateBR(date)})',
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

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
              onPressed: _loadClasses,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhuma aula disponível para amanhã',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList() {
    // Agrupa aulas por tipo de treino
    final groupedClasses = <String, List<ClassItem>>{};
    for (final classItem in _classes!) {
      final typeName = classItem.trainingType.name;
      groupedClasses.putIfAbsent(typeName, () => []);
      groupedClasses[typeName]!.add(classItem);
    }

    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groupedClasses.length,
        itemBuilder: (context, index) {
          final typeName = groupedClasses.keys.elementAt(index);
          final classes = groupedClasses[typeName]!;
          return _buildTrainingTypeSection(typeName, classes);
        },
      ),
    );
  }

  Widget _buildTrainingTypeSection(String typeName, List<ClassItem> classes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            typeName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...classes.map(_buildClassCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildClassCard(ClassItem classItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fitness_center,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(classItem.timeSlot.formattedTime),
        subtitle: Text('Capacidade: ${classItem.capacity} vagas'),
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
}
