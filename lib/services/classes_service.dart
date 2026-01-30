import '../core/supabase_client.dart';
import '../models/swim_class.dart';

/// Resultado de uma operação no serviço de aulas
class ClassOperationResult {
  final bool success;
  final String message;
  final SwimClass? swimClass;

  ClassOperationResult({
    required this.success,
    required this.message,
    this.swimClass,
  });

  factory ClassOperationResult.success(String message, [SwimClass? swimClass]) {
    return ClassOperationResult(
      success: true,
      message: message,
      swimClass: swimClass,
    );
  }

  factory ClassOperationResult.error(String message) {
    return ClassOperationResult(
      success: false,
      message: message,
    );
  }
}

/// Serviço para gerenciamento de aulas (CRUD)
class ClassesService {
  /// Busca todas as aulas ordenadas por start_time
  Future<List<SwimClass>> fetchClasses() async {
    final response = await supabase
        .from('classes')
        .select()
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => SwimClass.fromJson(json))
        .toList();
  }

  /// Busca aulas de uma data específica
  Future<List<SwimClass>> fetchClassesByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await supabase
        .from('classes')
        .select()
        .gte('start_time', startOfDay.toIso8601String())
        .lt('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => SwimClass.fromJson(json))
        .toList();
  }

  /// Cria uma nova aula
  /// Retorna [ClassOperationResult] indicando sucesso ou falha
  Future<ClassOperationResult> createClass(SwimClass swimClass) async {
    try {
      // Validações
      final validationError = _validateClass(swimClass);
      if (validationError != null) {
        return ClassOperationResult.error(validationError);
      }

      final response = await supabase
          .from('classes')
          .insert(swimClass.toJson())
          .select()
          .single();

      final createdClass = SwimClass.fromJson(response);
      return ClassOperationResult.success(
        'Aula "${createdClass.title}" criada com sucesso!',
        createdClass,
      );
    } catch (e) {
      return _handleError(e, 'criar aula');
    }
  }

  /// Atualiza uma aula existente
  /// Retorna [ClassOperationResult] indicando sucesso ou falha
  Future<ClassOperationResult> updateClass(SwimClass swimClass) async {
    try {
      // Validações
      final validationError = _validateClass(swimClass);
      if (validationError != null) {
        return ClassOperationResult.error(validationError);
      }

      final response = await supabase
          .from('classes')
          .update(swimClass.toJson())
          .eq('id', swimClass.id)
          .select()
          .single();

      final updatedClass = SwimClass.fromJson(response);
      return ClassOperationResult.success(
        'Aula "${updatedClass.title}" atualizada com sucesso!',
        updatedClass,
      );
    } catch (e) {
      return _handleError(e, 'atualizar aula');
    }
  }

  /// Exclui uma aula
  /// Retorna [ClassOperationResult] indicando sucesso ou falha
  Future<ClassOperationResult> deleteClass(String classId) async {
    try {
      await supabase.from('classes').delete().eq('id', classId);

      return ClassOperationResult.success('Aula excluída com sucesso!');
    } catch (e) {
      return _handleError(e, 'excluir aula');
    }
  }

  /// Valida os dados da aula
  String? _validateClass(SwimClass swimClass) {
    if (swimClass.title.trim().isEmpty) {
      return 'O título é obrigatório';
    }

    if (swimClass.endTime.isBefore(swimClass.startTime) ||
        swimClass.endTime.isAtSameMomentAs(swimClass.startTime)) {
      return 'O horário de término deve ser posterior ao horário de início';
    }

    if (swimClass.capacity <= 0) {
      return 'A capacidade deve ser maior que zero';
    }

    if (swimClass.lanes <= 0) {
      return 'O número de raias deve ser maior que zero';
    }

    return null;
  }

  /// Trata erros e retorna mensagem apropriada
  ClassOperationResult _handleError(Object e, String operation) {
    final errorMessage = e.toString().toLowerCase();

    if (errorMessage.contains('permission') ||
        errorMessage.contains('policy') ||
        errorMessage.contains('denied') ||
        errorMessage.contains('rls')) {
      return ClassOperationResult.error(
        'Você não tem permissão para $operation',
      );
    }

    if (errorMessage.contains('classes_time_check')) {
      return ClassOperationResult.error(
        'O horário de término deve ser posterior ao horário de início',
      );
    }

    return ClassOperationResult.error('Erro ao $operation: $e');
  }
}
