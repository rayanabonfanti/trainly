import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../services/settings_service.dart';

/// Página de Configurações do Sistema
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService();
  final _formKey = GlobalKey<FormState>();

  BusinessSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Controllers
  late TextEditingController _cancellationDeadlineController;
  late TextEditingController _maxCancellationsController;
  late TextEditingController _maxBookingsController;
  late TextEditingController _minAdvanceController;
  late TextEditingController _defaultCapacityController;
  late TextEditingController _defaultLanesController;

  // Toggles
  bool _cancellationLimitEnabled = true;
  bool _bookingLimitEnabled = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSettings();
  }

  void _initControllers() {
    _cancellationDeadlineController = TextEditingController();
    _maxCancellationsController = TextEditingController();
    _maxBookingsController = TextEditingController();
    _minAdvanceController = TextEditingController();
    _defaultCapacityController = TextEditingController();
    _defaultLanesController = TextEditingController();
  }

  @override
  void dispose() {
    _cancellationDeadlineController.dispose();
    _maxCancellationsController.dispose();
    _maxBookingsController.dispose();
    _minAdvanceController.dispose();
    _defaultCapacityController.dispose();
    _defaultLanesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await _settingsService.getSettings(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _settings = settings;
          _populateForm(settings);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar configurações: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _populateForm(BusinessSettings settings) {
    _cancellationDeadlineController.text = settings.cancellationDeadlineHours.toString();
    _maxCancellationsController.text = settings.maxCancellationsPerMonth.toString();
    _maxBookingsController.text = settings.maxBookingsPerWeek.toString();
    _minAdvanceController.text = settings.minBookingAdvanceHours.toString();
    _defaultCapacityController.text = settings.defaultClassCapacity.toString();
    _defaultLanesController.text = settings.defaultLanes.toString();
    _cancellationLimitEnabled = settings.cancellationLimitEnabled;
    _bookingLimitEnabled = settings.bookingLimitEnabled;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newSettings = BusinessSettings(
        cancellationDeadlineHours: int.parse(_cancellationDeadlineController.text),
        maxCancellationsPerMonth: int.parse(_maxCancellationsController.text),
        cancellationLimitEnabled: _cancellationLimitEnabled,
        maxBookingsPerWeek: int.parse(_maxBookingsController.text),
        bookingLimitEnabled: _bookingLimitEnabled,
        minBookingAdvanceHours: int.parse(_minAdvanceController.text),
        defaultClassCapacity: int.parse(_defaultCapacityController.text),
        defaultLanes: int.parse(_defaultLanesController.text),
      );

      final result = await _settingsService.updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (result.success) {
          setState(() {
            _settings = newSettings;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.restore,
          size: 48,
          color: Colors.orange.shade600,
        ),
        title: const Text('Restaurar Padrões'),
        content: const Text(
          'Tem certeza que deseja restaurar todas as configurações para os valores padrão?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _populateForm(BusinessSettings.defaults());
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Restaurar padrões',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final isMigrationError = _error!.contains('migration_admin_features');
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMigrationError ? Icons.build_outlined : Icons.error_outline,
                size: 64,
                color: isMigrationError ? Colors.orange : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                isMigrationError ? 'Configuração Necessária' : 'Erro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMigrationError ? Colors.grey[700] : Colors.red,
                ),
              ),
              if (isMigrationError) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Como resolver:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Acesse o Supabase Dashboard\n'
                        '2. Vá em SQL Editor\n'
                        '3. Execute o script migration_admin_features.sql\n'
                        '4. Volte aqui e clique em "Tentar novamente"',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            'Regras de Cancelamento',
            Icons.cancel_outlined,
            Colors.red,
          ),
          const SizedBox(height: 16),
          _buildCancellationSettings(),
          const SizedBox(height: 32),
          _buildSectionHeader(
            'Regras de Reserva',
            Icons.bookmark_add_outlined,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildBookingSettings(),
          const SizedBox(height: 32),
          _buildSectionHeader(
            'Padrões para Novas Aulas',
            Icons.pool_outlined,
            Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildClassDefaults(),
          const SizedBox(height: 24),
          if (_settings?.updatedAt != null) _buildLastUpdated(),
          const SizedBox(height: 100), // Espaço para o botão
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCancellationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNumberField(
              controller: _cancellationDeadlineController,
              label: 'Deadline de cancelamento',
              suffix: 'horas antes da aula',
              hint: 'Ex: 2 = pode cancelar até 2h antes',
              icon: Icons.timer_outlined,
              min: 0,
              max: 72,
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              label: 'Limite de cancelamentos por mês',
              value: _cancellationLimitEnabled,
              onChanged: (value) {
                setState(() => _cancellationLimitEnabled = value);
              },
            ),
            if (_cancellationLimitEnabled) ...[
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _maxCancellationsController,
                label: 'Máximo de cancelamentos',
                suffix: 'por mês',
                hint: 'Ex: 2 = máximo 2 cancelamentos/mês',
                icon: Icons.block,
                min: 1,
                max: 30,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNumberField(
              controller: _minAdvanceController,
              label: 'Antecedência mínima para reservar',
              suffix: 'horas',
              hint: 'Ex: 24 = precisa reservar 1 dia antes. 0 = sem restrição',
              icon: Icons.schedule,
              min: 0,
              max: 168,
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              label: 'Limite de reservas por semana',
              value: _bookingLimitEnabled,
              onChanged: (value) {
                setState(() => _bookingLimitEnabled = value);
              },
            ),
            if (_bookingLimitEnabled) ...[
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _maxBookingsController,
                label: 'Máximo de reservas',
                suffix: 'por semana',
                hint: 'Ex: 3 = máximo 3 reservas ativas/semana',
                icon: Icons.calendar_today,
                min: 1,
                max: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassDefaults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNumberField(
              controller: _defaultCapacityController,
              label: 'Capacidade padrão',
              suffix: 'alunos',
              hint: 'Valor padrão ao criar novas aulas',
              icon: Icons.people,
              min: 1,
              max: 100,
            ),
            const SizedBox(height: 20),
            _buildNumberField(
              controller: _defaultLanesController,
              label: 'Número de raias padrão',
              suffix: 'raias',
              hint: 'Valor padrão ao criar novas aulas',
              icon: Icons.view_column,
              min: 1,
              max: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required String hint,
    required IconData icon,
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Obrigatório';
                  }
                  final number = int.tryParse(value);
                  if (number == null) {
                    return 'Inválido';
                  }
                  if (number < min || number > max) {
                    return '$min-$max';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suffix,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: value
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    final date = _settings!.updatedAt!;
    final formatted = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Última atualização: $formatted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
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
            label: Text(_isSaving ? 'Salvando...' : 'Salvar Configurações'),
          ),
        ),
      ),
    );
  }
}
