import '../core/input_validator.dart';
import '../core/security_helpers.dart';
import '../core/supabase_client.dart';
import '../models/business_membership.dart';

/// Resultado de uma operação no serviço de associações
class MembershipResult {
  final bool success;
  final String message;
  final BusinessMembership? membership;

  MembershipResult({
    required this.success,
    required this.message,
    this.membership,
  });

  factory MembershipResult.success(String message, [BusinessMembership? membership]) {
    return MembershipResult(
      success: true,
      message: message,
      membership: membership,
    );
  }

  factory MembershipResult.error(String message) {
    return MembershipResult(
      success: false,
      message: message,
    );
  }
}

/// Serviço para gerenciamento de associações usuário-empresa
class MembershipService {
  /// Solicita associação a uma empresa (aluno se cadastrando em uma academia)
  Future<MembershipResult> requestMembership(String businessId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return MembershipResult.error('Usuário não autenticado');
    }

    // Validação de ID
    final idError = InputValidator.validateId(businessId, 'ID da empresa');
    if (idError != null) {
      return MembershipResult.error(idError);
    }

    try {
      // Verifica se já existe uma associação
      final existing = await supabase
          .from('business_memberships')
          .select('id, status')
          .eq('user_id', userId)
          .eq('business_id', businessId)
          .maybeSingle();

      if (existing != null) {
        final status = MembershipStatus.fromString(existing['status'] as String);
        if (status.isApproved) {
          return MembershipResult.error('Você já é membro desta academia');
        }
        if (status.isPending) {
          return MembershipResult.error('Você já tem uma solicitação pendente para esta academia');
        }
        if (status.isRejected) {
          // Permite reenviar solicitação se foi rejeitada
          await supabase
              .from('business_memberships')
              .update({
                'status': 'pending',
                'requested_at': DateTime.now().toIso8601String(),
                'rejection_reason': null,
                'rejected_at': null,
              })
              .eq('id', existing['id']);

          return MembershipResult.success(
            'Solicitação reenviada com sucesso! Aguarde a aprovação.',
          );
        }
      }

      // Cria nova solicitação
      final response = await supabase
          .from('business_memberships')
          .insert({
            'user_id': userId,
            'business_id': businessId,
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final membership = BusinessMembership.fromJson(response);

      return MembershipResult.success(
        'Solicitação enviada com sucesso! Aguarde a aprovação da academia.',
        membership,
      );
    } catch (e) {
      return _handleError(e, 'solicitar associação');
    }
  }

  /// Aprova uma solicitação de associação
  /// REQUER: Usuário autenticado como admin da empresa
  Future<MembershipResult> approveMembership(String membershipId) async {
    return _updateMembershipStatus(
      membershipId,
      MembershipStatus.approved,
      'Membro aprovado com sucesso!',
    );
  }

  /// Rejeita uma solicitação de associação
  /// REQUER: Usuário autenticado como admin da empresa
  Future<MembershipResult> rejectMembership(
    String membershipId, {
    String? reason,
  }) async {
    return _updateMembershipStatus(
      membershipId,
      MembershipStatus.rejected,
      'Solicitação recusada',
      reason: reason,
    );
  }

  /// Suspende um membro
  /// REQUER: Usuário autenticado como admin da empresa
  Future<MembershipResult> suspendMembership(
    String membershipId, {
    String? reason,
  }) async {
    return _updateMembershipStatus(
      membershipId,
      MembershipStatus.suspended,
      'Membro suspenso',
      reason: reason,
    );
  }

  /// Reativa um membro suspenso
  /// REQUER: Usuário autenticado como admin da empresa
  Future<MembershipResult> reactivateMembership(String membershipId) async {
    return _updateMembershipStatus(
      membershipId,
      MembershipStatus.approved,
      'Membro reativado com sucesso!',
    );
  }

  /// Atualiza o status de uma associação
  Future<MembershipResult> _updateMembershipStatus(
    String membershipId,
    MembershipStatus newStatus,
    String successMessage, {
    String? reason,
  }) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return MembershipResult.error('Você não tem permissão para realizar esta ação');
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return MembershipResult.error('Usuário não autenticado');
    }

    // Validação de ID
    final idError = InputValidator.validateId(membershipId, 'ID da associação');
    if (idError != null) {
      return MembershipResult.error(idError);
    }

    try {
      // Verifica se a associação existe e pertence à empresa do admin
      final membership = await supabase
          .from('business_memberships')
          .select('id, business_id')
          .eq('id', membershipId)
          .maybeSingle();

      if (membership == null) {
        return MembershipResult.error('Associação não encontrada');
      }

      // Verifica se o admin gerencia essa empresa
      final profile = await supabase
          .from('profiles')
          .select('business_id')
          .eq('id', userId)
          .single();

      if (profile['business_id'] != membership['business_id']) {
        return MembershipResult.error('Você só pode gerenciar membros da sua academia');
      }

      // Monta os dados de atualização
      final updateData = <String, dynamic>{
        'status': newStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newStatus == MembershipStatus.approved) {
        updateData['approved_at'] = DateTime.now().toIso8601String();
        updateData['approved_by'] = userId;
      } else if (newStatus == MembershipStatus.rejected) {
        updateData['rejected_at'] = DateTime.now().toIso8601String();
        updateData['rejection_reason'] = reason;
      }

      // Atualiza o membership
      await supabase
          .from('business_memberships')
          .update(updateData)
          .eq('id', membershipId);

      // Busca o membership atualizado
      final response = await supabase
          .from('business_memberships')
          .select()
          .eq('id', membershipId)
          .single();

      // Busca o perfil do usuário separadamente
      final memberUserId = response['user_id'] as String;
      Map<String, dynamic>? profileData;
      try {
        profileData = await supabase
            .from('profiles')
            .select('id, name, email, phone')
            .eq('id', memberUserId)
            .maybeSingle();
      } catch (e) {
        // Ignora erro de perfil
      }

      // Combina os dados
      final combinedJson = Map<String, dynamic>.from(response);
      if (profileData != null) {
        combinedJson['profiles'] = profileData;
      }

      final updatedMembership = BusinessMembership.fromJson(combinedJson);

      return MembershipResult.success(successMessage, updatedMembership);
    } catch (e) {
      return _handleError(e, 'atualizar associação');
    }
  }

  /// Busca as associações do usuário atual (aluno vendo suas academias)
  Future<List<BusinessMembership>> getMyMemberships() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('business_memberships')
          .select('''
            *,
            businesses:business_id (
              name,
              slug
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => BusinessMembership.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Busca a associação aprovada do usuário com uma empresa específica
  Future<BusinessMembership?> getApprovedMembership(String businessId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await supabase
          .from('business_memberships')
          .select()
          .eq('user_id', userId)
          .eq('business_id', businessId)
          .eq('status', 'approved')
          .maybeSingle();

      if (response == null) return null;

      return BusinessMembership.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se o usuário tem associação aprovada com uma empresa
  Future<bool> hasApprovedMembership(String businessId) async {
    final membership = await getApprovedMembership(businessId);
    return membership != null;
  }

  /// Busca os membros de uma empresa (para admin ver solicitações e membros)
  /// REQUER: Usuário autenticado como admin da empresa
  Future<List<BusinessMembership>> getBusinessMembers({
    MembershipStatus? status,
  }) async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return [];
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Pega o business_id do admin
      final profile = await supabase
          .from('profiles')
          .select('business_id')
          .eq('id', userId)
          .single();

      final businessId = profile['business_id'] as String?;
      if (businessId == null) return [];

      // Primeiro busca os memberships sem join
      var query = supabase
          .from('business_memberships')
          .select()
          .eq('business_id', businessId);

      if (status != null) {
        query = query.eq('status', status.value);
      }

      final membershipsResponse = await query.order('created_at', ascending: false);
      final memberships = membershipsResponse as List;

      if (memberships.isEmpty) return [];

      // Busca os user_ids
      final userIds = memberships
          .map((m) => m['user_id'] as String)
          .toSet()
          .toList();

      // Busca os perfis separadamente (evita problemas de RLS no join)
      final profilesMap = <String, Map<String, dynamic>>{};
      try {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, name, email, phone')
            .inFilter('id', userIds);

        for (final p in profilesResponse as List) {
          profilesMap[p['id'] as String] = p;
        }
      } catch (e) {
        // Se não conseguir buscar perfis, continua sem os dados extras
      }

      // Combina os dados
      return memberships.map((json) {
        final memberUserId = json['user_id'] as String;
        final profileData = profilesMap[memberUserId];
        
        // Adiciona dados do perfil ao JSON
        final combinedJson = Map<String, dynamic>.from(json);
        if (profileData != null) {
          combinedJson['profiles'] = profileData;
        }
        
        return BusinessMembership.fromJson(combinedJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Busca solicitações pendentes (para admin)
  /// REQUER: Usuário autenticado como admin da empresa
  Future<List<BusinessMembership>> getPendingRequests() async {
    return getBusinessMembers(status: MembershipStatus.pending);
  }

  /// Busca membros aprovados (para admin)
  /// REQUER: Usuário autenticado como admin da empresa
  Future<List<BusinessMembership>> getApprovedMembers() async {
    return getBusinessMembers(status: MembershipStatus.approved);
  }

  /// Conta solicitações pendentes (para badge de notificação)
  /// REQUER: Usuário autenticado como admin da empresa
  Future<int> countPendingRequests() async {
    // SEGURANÇA: Verifica se é admin
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return 0;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      // Pega o business_id do admin
      final profile = await supabase
          .from('profiles')
          .select('business_id')
          .eq('id', userId)
          .single();

      final businessId = profile['business_id'] as String?;
      if (businessId == null) return 0;

      final response = await supabase
          .from('business_memberships')
          .select('id')
          .eq('business_id', businessId)
          .eq('status', 'pending');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Trata erros e retorna mensagem apropriada
  MembershipResult _handleError(Object e, String operation) {
    final errorMessage = e.toString().toLowerCase();

    if (errorMessage.contains('permission') ||
        errorMessage.contains('policy') ||
        errorMessage.contains('denied') ||
        errorMessage.contains('rls')) {
      return MembershipResult.error(
        'Você não tem permissão para $operation',
      );
    }

    if (errorMessage.contains('unique') || errorMessage.contains('duplicate')) {
      return MembershipResult.error(
        'Você já solicitou associação a esta academia',
      );
    }

    return MembershipResult.error('Não foi possível $operation. Tente novamente');
  }
}
