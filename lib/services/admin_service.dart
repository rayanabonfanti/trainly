import '../core/input_validator.dart';
import '../core/security_helpers.dart';
import '../core/supabase_client.dart';

/// Representa um perfil de usuário
class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String role;

  UserProfile({
    required this.id,
    required this.email,
    this.name,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      role: json['role'] as String? ?? 'student',
    );
  }

  bool get isAdmin => role == 'admin';
}

/// Resultado de uma operação de promoção
class PromotionResult {
  final bool success;
  final String message;
  final UserProfile? profile;

  PromotionResult({
    required this.success,
    required this.message,
    this.profile,
  });

  factory PromotionResult.success(UserProfile profile) {
    return PromotionResult(
      success: true,
      message: 'Usuário promovido para admin com sucesso!',
      profile: profile,
    );
  }

  factory PromotionResult.userNotFound(String email) {
    return PromotionResult(
      success: false,
      message: 'Usuário não encontrado',
    );
  }

  factory PromotionResult.alreadyAdmin(String email) {
    return PromotionResult(
      success: false,
      message: 'Este usuário já é um administrador',
    );
  }

  factory PromotionResult.permissionDenied() {
    return PromotionResult(
      success: false,
      message: 'Você não tem permissão para realizar esta ação',
    );
  }

  factory PromotionResult.error(String error) {
    // SEGURANÇA: Não expõe detalhes técnicos
    return PromotionResult(
      success: false,
      message: 'Não foi possível promover o usuário. Tente novamente',
    );
  }

  factory PromotionResult.searchError(String error) {
    // SEGURANÇA: Não expõe detalhes técnicos
    return PromotionResult(
      success: false,
      message: 'Erro ao buscar usuário. Tente novamente',
    );
  }

  factory PromotionResult.invalidEmail() {
    return PromotionResult(
      success: false,
      message: 'Email inválido',
    );
  }
}

/// Serviço para operações administrativas
class AdminService {
  /// Busca o perfil do usuário atual
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se o usuário atual é admin
  Future<bool> isCurrentUserAdmin() async {
    return SecurityHelpers.isCurrentUserAdmin();
  }

  /// Busca um perfil por email
  /// REQUER: Usuário autenticado como admin
  /// Retorna o perfil ou null se não encontrado
  Future<UserProfile?> getProfileByEmail(String email) async {
    // Validação de email
    final emailError = InputValidator.validateEmail(email);
    if (emailError != null) {
      return null;
    }

    // SEGURANÇA: Apenas admins podem buscar perfis por email
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return null;
    }

    final normalizedEmail = email.trim().toLowerCase();
    
    final response = await supabase
        .from('profiles')
        .select()
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (response == null) return null;

    return UserProfile.fromJson(response);
  }

  /// Promove um usuário para admin usando o email
  /// REQUER: Usuário autenticado como admin
  /// 
  /// Retorna um [PromotionResult] indicando sucesso ou falha com mensagem
  Future<PromotionResult> promoteToAdmin(String email) async {
    // Validação de email
    final emailError = InputValidator.validateEmail(email);
    if (emailError != null) {
      return PromotionResult.invalidEmail();
    }

    final normalizedEmail = email.trim().toLowerCase();
    
    try {
      // 1. Verifica se o usuário atual é admin
      final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
      if (!isAdmin) {
        return PromotionResult.permissionDenied();
      }

      // 2. Busca o perfil pelo email
      UserProfile? profile;
      try {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('email', normalizedEmail)
            .maybeSingle();

        if (response != null) {
          profile = UserProfile.fromJson(response);
        }
      } catch (e) {
        return PromotionResult.searchError(e.toString());
      }
      
      if (profile == null) {
        return PromotionResult.userNotFound(normalizedEmail);
      }

      // 3. Verifica se já é admin
      if (profile.isAdmin) {
        return PromotionResult.alreadyAdmin(normalizedEmail);
      }

      // 4. Atualiza o role para admin
      await supabase
          .from('profiles')
          .update({'role': 'admin'})
          .eq('id', profile.id);

      // 5. Retorna o perfil atualizado
      final updatedProfile = UserProfile(
        id: profile.id,
        email: profile.email,
        name: profile.name,
        role: 'admin',
      );

      return PromotionResult.success(updatedProfile);
    } catch (e) {
      // SEGURANÇA: Verifica se é erro de permissão do RLS
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') || 
          errorMessage.contains('policy') ||
          errorMessage.contains('denied')) {
        return PromotionResult.permissionDenied();
      }
      return PromotionResult.error(e.toString());
    }
  }

  /// Lista todos os administradores
  /// REQUER: Usuário autenticado como admin
  Future<List<UserProfile>> listAdmins() async {
    // SEGURANÇA: Apenas admins podem listar outros admins
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return [];
    }

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('role', 'admin')
          .order('email');

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
