import 'dart:io';

import '../core/supabase_client.dart';
import '../models/user_profile.dart';

/// Resultado de operações de perfil
class ProfileResult {
  final bool success;
  final String message;
  final UserProfile? profile;

  ProfileResult({
    required this.success,
    required this.message,
    this.profile,
  });

  factory ProfileResult.success(String message, [UserProfile? profile]) {
    return ProfileResult(success: true, message: message, profile: profile);
  }

  factory ProfileResult.error(String message) {
    return ProfileResult(success: false, message: message);
  }
}

/// Serviço para gerenciamento de perfil do usuário
class ProfileService {
  /// Busca o perfil do usuário atual
  Future<UserProfile?> fetchCurrentProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Cria perfil se não existir
        final user = supabase.auth.currentUser!;
        final newProfile = {
          'id': userId,
          'email': user.email,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        await supabase.from('profiles').insert(newProfile);
        
        return UserProfile(
          id: userId,
          email: user.email ?? '',
        );
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      // Se a tabela não existir, retorna perfil básico
      final user = supabase.auth.currentUser;
      if (user != null) {
        return UserProfile(
          id: user.id,
          email: user.email ?? '',
        );
      }
      return null;
    }
  }

  /// Atualiza o perfil do usuário
  Future<ProfileResult> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return ProfileResult.error('Usuário não autenticado');
    }

    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      // Só faz upsert se houver campos para atualizar
      if (updates.isNotEmpty) {
        // Tenta com updated_at primeiro
        try {
          await supabase.from('profiles').upsert({
            'id': userId,
            'email': supabase.auth.currentUser?.email,
            'updated_at': DateTime.now().toIso8601String(),
            ...updates,
          });
        } catch (e) {
          // Se falhar por causa do updated_at, tenta sem ele
          if (e.toString().contains('updated_at')) {
            await supabase.from('profiles').upsert({
              'id': userId,
              'email': supabase.auth.currentUser?.email,
              ...updates,
            });
          } else {
            rethrow;
          }
        }
      }

      // Tenta atualizar phone separadamente (pode não existir a coluna)
      if (phone != null) {
        try {
          await supabase.from('profiles').update({
            'phone': phone,
          }).eq('id', userId);
        } catch (_) {
          // Coluna phone pode não existir ainda - ignora silenciosamente
        }
      }

      final updatedProfile = await fetchCurrentProfile();
      return ProfileResult.success('Perfil atualizado!', updatedProfile);
    } catch (e) {
      // Mensagens de erro mais amigáveis
      final errorMessage = _parseError(e.toString());
      return ProfileResult.error(errorMessage);
    }
  }

  /// Converte erros técnicos em mensagens amigáveis
  String _parseError(String error) {
    if (error.contains('schema cache') || error.contains('column')) {
      return 'Erro de configuração do banco de dados. Por favor, contate o suporte.';
    }
    if (error.contains('network') || error.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }
    if (error.contains('permission') || error.contains('policy')) {
      return 'Você não tem permissão para esta ação.';
    }
    if (error.contains('timeout')) {
      return 'A operação demorou muito. Tente novamente.';
    }
    return 'Não foi possível salvar as alterações. Tente novamente.';
  }

  /// Faz upload de imagem de avatar
  Future<String?> uploadAvatar(String filePath) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final fileExt = filePath.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final file = File(filePath);

      await supabase.storage.from('avatars').upload(
        fileName,
        file,
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}
