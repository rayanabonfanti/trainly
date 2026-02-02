import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/input_validator.dart';
import '../core/security_helpers.dart';
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
  /// Retorna null se o usuário não tiver perfil cadastrado
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
        // Usuário não tem perfil cadastrado - não cria automaticamente
        // O cadastro deve ser feito pela administração
        return null;
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      // Em caso de erro, retorna null por segurança
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

    // Validação de inputs
    final nameError = InputValidator.validateName(name);
    if (nameError != null) {
      return ProfileResult.error(nameError);
    }

    final phoneError = InputValidator.validatePhone(phone);
    if (phoneError != null) {
      return ProfileResult.error(phoneError);
    }

    final urlError = InputValidator.validateUrl(avatarUrl);
    if (urlError != null) {
      return ProfileResult.error(urlError);
    }

    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name.trim();
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl.trim();

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
            'phone': phone.trim(),
          }).eq('id', userId);
        } catch (_) {
          // Coluna phone pode não existir ainda - ignora silenciosamente
        }
      }

      final updatedProfile = await fetchCurrentProfile();
      return ProfileResult.success('Perfil atualizado!', updatedProfile);
    } catch (e) {
      // SEGURANÇA: Mensagens de erro genéricas
      return ProfileResult.error(SecurityHelpers.sanitizeErrorMessage(e.toString()));
    }
  }

  /// Faz upload de imagem de avatar
  /// SEGURANÇA: Valida tipo, tamanho e sanitiza nome do arquivo
  Future<String?> uploadAvatar(String filePath) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // Validação de extensão do arquivo
    final extensionError = InputValidator.validateAvatarExtension(filePath);
    if (extensionError != null) {
      throw Exception(extensionError);
    }

    try {
      final file = File(filePath);

      // Validação de existência do arquivo
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado');
      }

      // Validação de tamanho do arquivo
      final fileSize = await file.length();
      final sizeError = InputValidator.validateFileSize(
        fileSize,
        InputValidator.maxAvatarSizeBytes,
      );
      if (sizeError != null) {
        throw Exception(sizeError);
      }

      // SEGURANÇA: Extrai e valida extensão de forma segura
      final pathParts = filePath.split('/').last.split('.');
      if (pathParts.length < 2) {
        throw Exception('Arquivo sem extensão válida');
      }
      final fileExt = pathParts.last.toLowerCase();

      // Valida novamente a extensão após extração
      if (!InputValidator.allowedAvatarExtensions.contains(fileExt)) {
        throw Exception('Tipo de arquivo não permitido');
      }

      // SEGURANÇA: Nome de arquivo seguro (userId + timestamp + extensão válida)
      final safeFileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').upload(
        safeFileName,
        file,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(safeFileName);
      return publicUrl;
    } catch (e) {
      // Propaga exceções de validação, sanitiza outras
      if (e.toString().contains('Tipo de arquivo') ||
          e.toString().contains('Arquivo') ||
          e.toString().contains('MB')) {
        rethrow;
      }
      throw Exception('Não foi possível fazer upload da imagem');
    }
  }
}
