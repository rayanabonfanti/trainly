import '../core/input_validator.dart';
import '../core/security_helpers.dart';
import '../core/supabase_client.dart';
import '../models/business.dart';

/// Resultado de uma operação no serviço de empresas
class BusinessResult {
  final bool success;
  final String message;
  final Business? business;

  BusinessResult({
    required this.success,
    required this.message,
    this.business,
  });

  factory BusinessResult.success(String message, [Business? business]) {
    return BusinessResult(
      success: true,
      message: message,
      business: business,
    );
  }

  factory BusinessResult.error(String message) {
    return BusinessResult(
      success: false,
      message: message,
    );
  }
}

/// Cache local da empresa do usuário admin
Business? _cachedBusiness;

/// Serviço para gerenciamento de empresas/academias
class BusinessService {
  /// Cria uma nova empresa
  /// Também atualiza o perfil do usuário para vincular à empresa
  Future<BusinessResult> createBusiness({
    required String name,
    String? description,
    String? address,
    String? phone,
    String? email,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return BusinessResult.error('Usuário não autenticado');
    }

    // Validações
    final nameError = InputValidator.validateTitle(name);
    if (nameError != null) {
      return BusinessResult.error(nameError);
    }

    try {
      final slug = Business.generateSlug(name);

      // Verifica se slug já existe
      final existingSlug = await supabase
          .from('businesses')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();

      if (existingSlug != null) {
        return BusinessResult.error(
          'Já existe uma empresa com nome similar. Tente um nome diferente.',
        );
      }

      // Cria a empresa
      final response = await supabase
          .from('businesses')
          .insert({
            'name': name,
            'slug': slug,
            'description': description,
            'address': address,
            'phone': phone,
            'email': email,
            'owner_id': userId,
            'is_active': true,
          })
          .select()
          .single();

      final business = Business.fromJson(response);

      // Atualiza o perfil do usuário para ser admin e vincular à empresa
      await supabase.from('profiles').update({
        'role': 'admin',
        'business_id': business.id,
      }).eq('id', userId);

      _cachedBusiness = business;

      return BusinessResult.success(
        'Empresa "${business.name}" criada com sucesso!',
        business,
      );
    } catch (e) {
      return _handleError(e, 'criar empresa');
    }
  }

  /// Busca a empresa do usuário admin atual
  Future<Business?> getMyBusiness() async {
    if (_cachedBusiness != null) {
      return _cachedBusiness;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // Busca o perfil do usuário para pegar o business_id
      final profileResponse = await supabase
          .from('profiles')
          .select('business_id')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse == null || profileResponse['business_id'] == null) {
        return null;
      }

      final businessId = profileResponse['business_id'] as String;

      // Busca a empresa
      final businessResponse = await supabase
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();

      if (businessResponse == null) return null;

      _cachedBusiness = Business.fromJson(businessResponse);
      return _cachedBusiness;
    } catch (e) {
      return null;
    }
  }

  /// Busca uma empresa pelo slug (para alunos buscarem academias)
  Future<Business?> getBusinessBySlug(String slug) async {
    if (slug.isEmpty) return null;

    try {
      final response = await supabase
          .from('businesses')
          .select()
          .eq('slug', slug.toLowerCase())
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      return Business.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Busca uma empresa pelo ID
  Future<Business?> getBusinessById(String businessId) async {
    if (businessId.isEmpty) return null;

    try {
      final response = await supabase
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();

      if (response == null) return null;

      return Business.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Busca empresas por nome (para alunos pesquisarem)
  Future<List<Business>> searchBusinesses(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      final response = await supabase
          .from('businesses')
          .select()
          .eq('is_active', true)
          .ilike('name', '%$query%')
          .order('name')
          .limit(20);

      return (response as List)
          .map((json) => Business.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Lista todas as empresas ativas (para alunos escolherem)
  Future<List<Business>> listActiveBusinesses() async {
    try {
      final response = await supabase
          .from('businesses')
          .select()
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => Business.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Atualiza uma empresa
  /// REQUER: Usuário autenticado como admin da empresa
  Future<BusinessResult> updateBusiness(Business business) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return BusinessResult.error('Você não tem permissão para editar a empresa');
    }

    // Validação de ID
    final idError = InputValidator.validateId(business.id, 'ID da empresa');
    if (idError != null) {
      return BusinessResult.error(idError);
    }

    // Validação de nome
    final nameError = InputValidator.validateTitle(business.name);
    if (nameError != null) {
      return BusinessResult.error(nameError);
    }

    try {
      // Verifica se o usuário é dono da empresa
      final myBusiness = await getMyBusiness();
      if (myBusiness == null || myBusiness.id != business.id) {
        return BusinessResult.error('Você só pode editar sua própria empresa');
      }

      final response = await supabase
          .from('businesses')
          .update({
            'name': business.name,
            'description': business.description,
            'address': business.address,
            'phone': business.phone,
            'email': business.email,
            'logo_url': business.logoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', business.id)
          .select()
          .single();

      final updatedBusiness = Business.fromJson(response);
      _cachedBusiness = updatedBusiness;

      return BusinessResult.success(
        'Empresa atualizada com sucesso!',
        updatedBusiness,
      );
    } catch (e) {
      return _handleError(e, 'atualizar empresa');
    }
  }

  /// Limpa o cache
  void clearCache() {
    _cachedBusiness = null;
  }

  /// Retorna a empresa do cache (síncrono)
  Business? get cachedBusiness => _cachedBusiness;

  /// Trata erros e retorna mensagem apropriada
  BusinessResult _handleError(Object e, String operation) {
    final errorMessage = e.toString().toLowerCase();

    if (errorMessage.contains('permission') ||
        errorMessage.contains('policy') ||
        errorMessage.contains('denied') ||
        errorMessage.contains('rls')) {
      return BusinessResult.error(
        'Você não tem permissão para $operation',
      );
    }

    if (errorMessage.contains('unique') || errorMessage.contains('duplicate')) {
      return BusinessResult.error(
        'Já existe uma empresa com esse nome ou dados',
      );
    }

    return BusinessResult.error('Não foi possível $operation. Tente novamente');
  }
}
