import '../core/input_validator.dart';
import '../core/security_helpers.dart';
import '../core/supabase_client.dart';
import '../models/swim_class.dart';
import 'business_service.dart';

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
  final BusinessService _businessService = BusinessService();

  /// Busca todas as aulas ordenadas por start_time
  /// Se businessId for fornecido, filtra por empresa
  Future<List<SwimClass>> fetchClasses({String? businessId}) async {
    final baseQuery = supabase.from('classes').select();
    
    final response = businessId != null
        ? await baseQuery
            .eq('business_id', businessId)
            .order('start_time', ascending: true)
        : await baseQuery
            .order('start_time', ascending: true);

    return (response as List)
        .map((json) => SwimClass.fromJson(json))
        .toList();
  }

  /// Busca aulas de uma empresa específica
  Future<List<SwimClass>> fetchClassesByBusiness(String businessId) async {
    return fetchClasses(businessId: businessId);
  }

  /// Busca aulas de uma data específica
  /// Se businessId for fornecido, filtra por empresa
  Future<List<SwimClass>> fetchClassesByDate(
    DateTime date, {
    String? businessId,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final baseQuery = supabase
        .from('classes')
        .select()
        .gte('start_time', startOfDay.toIso8601String())
        .lt('start_time', endOfDay.toIso8601String());

    final response = businessId != null
        ? await baseQuery
            .eq('business_id', businessId)
            .order('start_time', ascending: true)
        : await baseQuery
            .order('start_time', ascending: true);

    return (response as List)
        .map((json) => SwimClass.fromJson(json))
        .toList();
  }

  /// Cria uma nova aula
  /// Retorna [ClassOperationResult] indicando sucesso ou falha
  /// REQUER: Usuário autenticado como admin
  /// A aula é automaticamente vinculada à empresa do admin
  Future<ClassOperationResult> createClass(SwimClass swimClass) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return ClassOperationResult.error('Você não tem permissão para criar aulas');
    }

    try {
      // Validações
      final validationError = _validateClass(swimClass);
      if (validationError != null) {
        return ClassOperationResult.error(validationError);
      }

      // Busca a empresa do admin
      final business = await _businessService.getMyBusiness();
      if (business == null) {
        return ClassOperationResult.error(
          'Você precisa ter uma empresa cadastrada para criar aulas',
        );
      }

      // Adiciona o business_id à aula
      final classWithBusiness = swimClass.copyWith(businessId: business.id);

      final response = await supabase
          .from('classes')
          .insert(classWithBusiness.toJson())
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

  /// Busca aulas da empresa do admin atual
  /// REQUER: Usuário autenticado como admin
  Future<List<SwimClass>> fetchMyBusinessClasses() async {
    final business = await _businessService.getMyBusiness();
    if (business == null) return [];

    return fetchClasses(businessId: business.id);
  }

  /// Busca aulas de uma data específica da empresa do admin atual
  /// REQUER: Usuário autenticado como admin
  Future<List<SwimClass>> fetchMyBusinessClassesByDate(DateTime date) async {
    final business = await _businessService.getMyBusiness();
    if (business == null) return [];

    return fetchClassesByDate(date, businessId: business.id);
  }

  /// Atualiza uma aula existente
  /// Retorna [ClassOperationResult] indicando sucesso ou falha
  /// REQUER: Usuário autenticado como admin da empresa dona da aula
  Future<ClassOperationResult> updateClass(SwimClass swimClass) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return ClassOperationResult.error('Você não tem permissão para editar aulas');
    }

    // Validação de ID
    final idError = InputValidator.validateId(swimClass.id, 'ID da aula');
    if (idError != null) {
      return ClassOperationResult.error(idError);
    }

    try {
      // Validações
      final validationError = _validateClass(swimClass);
      if (validationError != null) {
        return ClassOperationResult.error(validationError);
      }

      // Verifica se a aula pertence à empresa do admin
      final business = await _businessService.getMyBusiness();
      if (business == null) {
        return ClassOperationResult.error(
          'Você precisa ter uma empresa cadastrada para editar aulas',
        );
      }

      // Busca a aula para verificar ownership
      final existingClass = await supabase
          .from('classes')
          .select('business_id')
          .eq('id', swimClass.id)
          .maybeSingle();

      if (existingClass == null) {
        return ClassOperationResult.error('Aula não encontrada');
      }

      if (existingClass['business_id'] != business.id) {
        return ClassOperationResult.error(
          'Você só pode editar aulas da sua empresa',
        );
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
  /// REQUER: Usuário autenticado como admin da empresa dona da aula
  Future<ClassOperationResult> deleteClass(String classId) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return ClassOperationResult.error('Você não tem permissão para excluir aulas');
    }

    // Validação de ID
    final idError = InputValidator.validateId(classId, 'ID da aula');
    if (idError != null) {
      return ClassOperationResult.error(idError);
    }

    try {
      // Verifica se a aula pertence à empresa do admin
      final business = await _businessService.getMyBusiness();
      if (business == null) {
        return ClassOperationResult.error(
          'Você precisa ter uma empresa cadastrada para excluir aulas',
        );
      }

      // Busca a aula para verificar ownership
      final existingClass = await supabase
          .from('classes')
          .select('business_id')
          .eq('id', classId)
          .maybeSingle();

      if (existingClass == null) {
        return ClassOperationResult.error('Aula não encontrada');
      }

      if (existingClass['business_id'] != business.id) {
        return ClassOperationResult.error(
          'Você só pode excluir aulas da sua empresa',
        );
      }

      await supabase.from('classes').delete().eq('id', classId);

      return ClassOperationResult.success('Aula excluída com sucesso!');
    } catch (e) {
      return _handleError(e, 'excluir aula');
    }
  }

  /// Valida os dados da aula
  String? _validateClass(SwimClass swimClass) {
    // Validação de título
    final titleError = InputValidator.validateTitle(swimClass.title);
    if (titleError != null) {
      return titleError;
    }

    if (swimClass.endTime.isBefore(swimClass.startTime) ||
        swimClass.endTime.isAtSameMomentAs(swimClass.startTime)) {
      return 'O horário de término deve ser posterior ao horário de início';
    }

    if (swimClass.capacity <= 0) {
      return 'A capacidade deve ser maior que zero';
    }

    if (swimClass.capacity > 1000) {
      return 'Capacidade máxima excedida';
    }

    if (swimClass.lanes <= 0) {
      return 'O número de vagas deve ser maior que zero';
    }

    if (swimClass.lanes > 50) {
      return 'Número máximo de vagas excedido';
    }

    return null;
  }

  /// Trata erros e retorna mensagem apropriada
  /// SEGURANÇA: Não expõe detalhes técnicos
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

    // SEGURANÇA: Mensagem genérica sem expor detalhes técnicos
    return ClassOperationResult.error('Não foi possível $operation. Tente novamente');
  }
}
