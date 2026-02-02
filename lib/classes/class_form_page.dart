import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/class_type.dart';
import '../models/swim_class.dart';
import '../services/admin_service.dart';
import '../services/classes_service.dart';
import '../services/settings_service.dart';

/// Tela de formulário para criar/editar aulas
///
/// Acessível apenas por administradores.
class ClassFormPage extends StatefulWidget {
  /// Aula a ser editada (null para criar nova)
  final SwimClass? swimClass;

  const ClassFormPage({super.key, this.swimClass});

  @override
  State<ClassFormPage> createState() => _ClassFormPageState();
}

class _ClassFormPageState extends State<ClassFormPage> {
  final _classesService = ClassesService();
  final _adminService = AdminService();
  final _settingsService = SettingsService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  final _lanesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  
  // Tipos de aula dinâmicos
  List<ClassType> _classTypes = ClassType.defaults;
  ClassType? _selectedClassType;

  bool _isLoading = false;
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  bool get _isEditing => widget.swimClass != null;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadClassTypes();
    _initializeForm();
  }

  Future<void> _loadClassTypes() async {
    try {
      final settings = await _settingsService.getSettings();
      if (mounted) {
        setState(() {
          _classTypes = settings.classTypes;
          // Se editando, encontra o tipo correspondente
          if (widget.swimClass != null) {
            _selectedClassType = _classTypes.firstWhere(
              (t) => t.id == widget.swimClass!.type.value,
              orElse: () => _classTypes.first,
            );
          } else {
            _selectedClassType = _classTypes.isNotEmpty ? _classTypes.first : null;
          }
        });
      }
    } catch (e) {
      // Usa tipos padrão se falhar
      if (mounted) {
        setState(() {
          _classTypes = ClassType.defaults;
          _selectedClassType = _classTypes.first;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _lanesController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.swimClass != null) {
      final swimClass = widget.swimClass!;
      _titleController.text = swimClass.title;
      _descriptionController.text = swimClass.description ?? '';
      _capacityController.text = swimClass.capacity.toString();
      _lanesController.text = swimClass.lanes.toString();
      _selectedDate = swimClass.startTime;
      _startTime = TimeOfDay.fromDateTime(swimClass.startTime);
      _endTime = TimeOfDay.fromDateTime(swimClass.endTime);
    } else {
      _capacityController.text = '6';
      _lanesController.text = '3';
    }
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();

    if (mounted) {
      setState(() {
        _hasAccess = isAdmin;
        _isCheckingAccess = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Ajusta automaticamente o horário de término se necessário
        if (_timeToMinutes(picked) >= _timeToMinutes(_endTime)) {
          _endTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação de horário
    if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O horário de término deve ser posterior ao horário de início',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Converte ClassType para SwimClassType
      final swimClassType = _selectedClassType != null
          ? SwimClassType.fromString(_selectedClassType!.id)
          : SwimClassType.classType;

      final swimClass = SwimClass(
        id: widget.swimClass?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: _combineDateAndTime(_selectedDate, _startTime),
        endTime: _combineDateAndTime(_selectedDate, _endTime),
        capacity: int.parse(_capacityController.text),
        lanes: int.parse(_lanesController.text),
        type: swimClassType,
      );

      final result = _isEditing
          ? await _classesService.updateClass(swimClass)
          : await _classesService.createClass(swimClass);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Aula' : 'Nova Aula'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingAccess) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando permissões...'),
          ],
        ),
      );
    }

    if (!_hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas administradores podem criar ou editar aulas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Ex: Treino Funcional',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O título é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Descrição opcional da aula',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Data
            _buildDateSelector(),
            const SizedBox(height: 16),

            // Horários
            Row(
              children: [
                Expanded(child: _buildStartTimeSelector()),
                const SizedBox(width: 16),
                Expanded(child: _buildEndTimeSelector()),
              ],
            ),
            const SizedBox(height: 16),

            // Capacidade e Raias
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Capacidade *',
                      hintText: 'Ex: 6',
                      prefixIcon: Icon(Icons.people),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obrigatório';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Deve ser > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lanesController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Vagas *',
                      hintText: 'Ex: 3',
                      prefixIcon: Icon(Icons.view_week),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obrigatório';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Deve ser > 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tipo
            _buildTypeSelector(),
            const SizedBox(height: 32),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveClass,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading
                        ? 'Salvando...'
                        : (_isEditing ? 'Atualizar' : 'Criar Aula')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _isLoading ? null : _selectDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data *',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Text(
          '${_selectedDate.day.toString().padLeft(2, '0')}/'
          '${_selectedDate.month.toString().padLeft(2, '0')}/'
          '${_selectedDate.year}',
        ),
      ),
    );
  }

  Widget _buildStartTimeSelector() {
    return InkWell(
      onTap: _isLoading ? null : _selectStartTime,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Início *',
          prefixIcon: Icon(Icons.access_time),
          border: OutlineInputBorder(),
        ),
        child: Text(
          '${_startTime.hour.toString().padLeft(2, '0')}:'
          '${_startTime.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  Widget _buildEndTimeSelector() {
    return InkWell(
      onTap: _isLoading ? null : _selectEndTime,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Término *',
          prefixIcon: Icon(Icons.access_time_filled),
          border: OutlineInputBorder(),
        ),
        child: Text(
          '${_endTime.hour.toString().padLeft(2, '0')}:'
          '${_endTime.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    if (_classTypes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tipo *',
        prefixIcon: Icon(Icons.category),
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClassType>(
          value: _selectedClassType,
          isExpanded: true,
          onChanged: _isLoading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _selectedClassType = value;
                    });
                  }
                },
          items: _classTypes.map((classType) {
            return DropdownMenuItem(
              value: classType,
              child: Row(
                children: [
                  Icon(
                    classType.iconData,
                    size: 20,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Text(classType.name),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

}
