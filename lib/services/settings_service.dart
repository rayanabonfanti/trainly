import '../core/security_helpers.dart';
import '../core/supabase_client.dart';
import '../models/business_settings.dart';
import '../models/class_type.dart';

/// Cache local das configurações
BusinessSettings? _cachedSettings;

/// Serviço para gerenciamento de configurações de negócio
class SettingsService {
  /// Busca as configurações atuais
  /// Usa cache para evitar múltiplas chamadas
  Future<BusinessSettings> getSettings({bool forceRefresh = false}) async {
    if (_cachedSettings != null && !forceRefresh) {
      return _cachedSettings!;
    }

    try {
      final response = await supabase
          .from('business_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (response == null) {
        // Retorna configurações padrão sem criar no banco
        // Apenas admins devem criar configurações
        _cachedSettings = BusinessSettings.defaults();
        return _cachedSettings!;
      }

      _cachedSettings = BusinessSettings.fromJson(response);
      return _cachedSettings!;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      
      // Se a tabela não existe, lança erro específico para guiar o usuário
      if (errorMessage.contains('could not find the table') ||
          errorMessage.contains('relation') && errorMessage.contains('does not exist') ||
          errorMessage.contains('pgrst205')) {
        throw Exception(
          'Tabela de configurações não encontrada. '
          'Entre em contato com o administrador.'
        );
      }
      
      // Para outros erros, retorna padrão
      _cachedSettings = BusinessSettings.defaults();
      return _cachedSettings!;
    }
  }

  /// Cria configurações padrão no banco
  /// REQUER: Usuário autenticado como admin
  Future<void> _createDefaultSettings(BusinessSettings settings) async {
    // SEGURANÇA: Verifica se é admin antes de criar configurações
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return;
    }

    try {
      await supabase.from('business_settings').insert({
        'id': 'default',
        ...settings.toJson(),
      });
    } catch (e) {
      // Ignora erro se já existe ou tabela não existe
    }
  }

  /// Atualiza as configurações
  /// REQUER: Usuário autenticado como admin
  Future<SettingsResult> updateSettings(BusinessSettings settings) async {
    // SEGURANÇA: Verifica se é admin antes de atualizar
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return SettingsResult.error('Você não tem permissão para alterar configurações');
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      
      await supabase.from('business_settings').upsert({
        'id': 'default',
        ...settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': userId,
      });

      // Atualiza cache
      _cachedSettings = settings.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      return SettingsResult.success('Configurações salvas com sucesso!');
    } catch (e) {
      // SEGURANÇA: Mensagens de erro genéricas
      return SettingsResult.error(SecurityHelpers.sanitizeErrorMessage(e.toString()));
    }
  }

  /// Limpa o cache para forçar reload
  void clearCache() {
    _cachedSettings = null;
  }

  /// Limpa cache de admin ao deslogar
  void clearAllCaches() {
    _cachedSettings = null;
    SecurityHelpers.clearAdminCache();
  }

  /// Retorna as configurações do cache (síncrono)
  /// Use apenas quando tiver certeza que já foi carregado
  BusinessSettings get cachedSettings {
    return _cachedSettings ?? BusinessSettings.defaults();
  }

  /// Retorna os tipos de aula configurados
  List<ClassType> get classTypes {
    return cachedSettings.classTypes;
  }

  /// Busca o nome do tipo de aula pelo ID
  /// Retorna o ID se não encontrar
  String getClassTypeName(String typeId) {
    final classType = classTypes.firstWhere(
      (t) => t.id == typeId,
      orElse: () => ClassType(id: typeId, name: typeId),
    );
    return classType.name;
  }

  /// Busca o ClassType pelo ID
  ClassType? getClassTypeById(String typeId) {
    try {
      return classTypes.firstWhere((t) => t.id == typeId);
    } catch (e) {
      return null;
    }
  }
}

/// Resultado de operação de configurações
class SettingsResult {
  final bool success;
  final String message;

  SettingsResult({
    required this.success,
    required this.message,
  });

  factory SettingsResult.success(String message) {
    return SettingsResult(success: true, message: message);
  }

  factory SettingsResult.error(String message) {
    return SettingsResult(success: false, message: message);
  }
}
