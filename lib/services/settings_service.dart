import '../core/supabase_client.dart';
import '../models/business_settings.dart';

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
        // Cria configurações padrão se não existir
        final defaults = BusinessSettings.defaults();
        await _createDefaultSettings(defaults);
        _cachedSettings = defaults;
        return defaults;
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
          'Execute o script migration_admin_features.sql no Supabase Dashboard.'
        );
      }
      
      // Para outros erros, retorna padrão
      _cachedSettings = BusinessSettings.defaults();
      return _cachedSettings!;
    }
  }

  /// Cria configurações padrão no banco
  Future<void> _createDefaultSettings(BusinessSettings settings) async {
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
  Future<SettingsResult> updateSettings(BusinessSettings settings) async {
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
      final errorMessage = e.toString().toLowerCase();
      
      // Se a tabela não existe
      if (errorMessage.contains('could not find the table') ||
          errorMessage.contains('relation') && errorMessage.contains('does not exist') ||
          errorMessage.contains('pgrst205')) {
        return SettingsResult.error(
          'Tabela de configurações não encontrada. '
          'Execute o script migration_admin_features.sql no Supabase Dashboard.'
        );
      }
      
      // Se é erro de permissão
      if (errorMessage.contains('permission') || 
          errorMessage.contains('policy') ||
          errorMessage.contains('denied') ||
          errorMessage.contains('rls')) {
        return SettingsResult.error(
          'Sem permissão para salvar. Verifique se você é administrador.'
        );
      }
      
      return SettingsResult.error('Erro ao salvar configurações: $e');
    }
  }

  /// Limpa o cache para forçar reload
  void clearCache() {
    _cachedSettings = null;
  }

  /// Retorna as configurações do cache (síncrono)
  /// Use apenas quando tiver certeza que já foi carregado
  BusinessSettings get cachedSettings {
    return _cachedSettings ?? BusinessSettings.defaults();
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
