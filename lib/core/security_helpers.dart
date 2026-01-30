import '../core/supabase_client.dart';

/// Helper para verificações de segurança centralizadas
class SecurityHelpers {
  /// Cache do status de admin do usuário atual
  static bool? _isAdminCached;
  static String? _cachedUserId;

  /// Retorna o ID do usuário atual ou null se não autenticado
  static String? get currentUserId => supabase.auth.currentUser?.id;

  /// Verifica se o usuário está autenticado
  static bool get isAuthenticated => currentUserId != null;

  /// Verifica se o usuário atual é admin
  /// Usa cache para evitar múltiplas chamadas ao banco
  static Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final userId = currentUserId;
    if (userId == null) return false;

    // Retorna cache se válido
    if (!forceRefresh && _isAdminCached != null && _cachedUserId == userId) {
      return _isAdminCached!;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      final isAdmin = response?['role'] == 'admin';
      
      // Atualiza cache
      _isAdminCached = isAdmin;
      _cachedUserId = userId;

      return isAdmin;
    } catch (e) {
      return false;
    }
  }

  /// Limpa o cache de admin (chamar em logout)
  static void clearAdminCache() {
    _isAdminCached = null;
    _cachedUserId = null;
  }

  /// Verifica se um recurso pertence ao usuário atual
  static Future<bool> isResourceOwner(
    String tableName,
    String resourceId,
    String userIdColumn,
  ) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final response = await supabase
          .from(tableName)
          .select(userIdColumn)
          .eq('id', resourceId)
          .maybeSingle();

      return response?[userIdColumn] == userId;
    } catch (e) {
      return false;
    }
  }

  /// Sanitiza mensagens de erro para não expor detalhes internos
  static String sanitizeErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    // Erros de permissão
    if (lowerError.contains('permission') ||
        lowerError.contains('policy') ||
        lowerError.contains('denied') ||
        lowerError.contains('rls')) {
      return 'Você não tem permissão para realizar esta ação';
    }

    // Erros de conexão
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('socket') ||
        lowerError.contains('timeout')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente';
    }

    // Erros de banco de dados
    if (lowerError.contains('relation') ||
        lowerError.contains('column') ||
        lowerError.contains('table') ||
        lowerError.contains('schema')) {
      return 'Erro de configuração do sistema. Contate o suporte';
    }

    // Erros de duplicação
    if (lowerError.contains('duplicate') || lowerError.contains('unique')) {
      return 'Este registro já existe';
    }

    // Erro genérico para outros casos
    return 'Ocorreu um erro. Tente novamente';
  }
}
