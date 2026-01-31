import 'package:flutter/material.dart';

import '../core/booking_rules.dart';
import '../models/business_settings.dart';
import '../models/class_type.dart';
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

  // Tipos de aula
  List<ClassType> _classTypes = [];

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
    _classTypes = List.from(settings.classTypes);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação lógica adicional
    final maxCancellations = int.tryParse(_maxCancellationsController.text) ?? 0;
    final maxBookings = int.tryParse(_maxBookingsController.text) ?? 0;

    if (_cancellationLimitEnabled && maxCancellations < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O limite de cancelamentos deve ser pelo menos 1 quando habilitado'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_bookingLimitEnabled && maxBookings < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O limite de reservas deve ser pelo menos 1 quando habilitado'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_classTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário ter pelo menos um tipo de aula'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newSettings = BusinessSettings(
        cancellationDeadlineHours: int.parse(_cancellationDeadlineController.text),
        maxCancellationsPerMonth: maxCancellations,
        cancellationLimitEnabled: _cancellationLimitEnabled,
        maxBookingsPerWeek: maxBookings,
        bookingLimitEnabled: _bookingLimitEnabled,
        minBookingAdvanceHours: int.parse(_minAdvanceController.text),
        defaultClassCapacity: int.parse(_defaultCapacityController.text),
        defaultLanes: int.parse(_defaultLanesController.text),
        classTypes: _classTypes,
      );

      final result = await _settingsService.updateSettings(newSettings);

      if (result.success) {
        // IMPORTANTE: Atualiza o cache global das regras de negócio
        // para que as novas configurações sejam aplicadas imediatamente
        await BookingRules.refresh();
      }

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
            _settings = newSettings.copyWith(updatedAt: DateTime.now());
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

  void _addClassType() async {
    final result = await showDialog<ClassType>(
      context: context,
      builder: (context) => _ClassTypeDialog(),
    );

    if (result != null) {
      // Verifica se já existe um tipo com esse ID
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
      });
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
          const SizedBox(height: 32),
          _buildSectionHeader(
            'Tipos de Aula',
            Icons.category_outlined,
            Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildClassTypesSection(),
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

  Widget _buildClassTypesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gerencie os tipos de aula disponíveis para criação',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ..._classTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final classType = entry.value;
              return _buildClassTypeItem(classType, index);
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addClassType,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Tipo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassTypeItem(ClassType classType, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(classType.iconData, color: Colors.purple, size: 24),
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
              onPressed: _classTypes.length > 1 ? () => _removeClassType(index) : null,
              tooltip: 'Remover',
            ),
          ],
        ),
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
                enabled: !_isEditing, // Não permite editar ID
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
                  if (value.contains(' ') || !RegExp(r'^[a-z0-9_]+$').hasMatch(value.trim().toLowerCase())) {
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
