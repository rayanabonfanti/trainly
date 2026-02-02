import 'package:flutter/material.dart';

import '../models/business.dart';
import '../models/business_membership.dart';
import '../services/business_service.dart';
import '../services/membership_service.dart';

/// Página para alunos verem todas as academias e seus status de cadastro
class SelectBusinessPage extends StatefulWidget {
  const SelectBusinessPage({super.key});

  @override
  State<SelectBusinessPage> createState() => _SelectBusinessPageState();
}

class _SelectBusinessPageState extends State<SelectBusinessPage> {
  final BusinessService _businessService = BusinessService();
  final MembershipService _membershipService = MembershipService();
  final TextEditingController _searchController = TextEditingController();

  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];
  Map<String, BusinessMembership> _membershipsByBusinessId = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carrega academias e memberships em paralelo
      final results = await Future.wait([
        _businessService.listActiveBusinesses(),
        _membershipService.getMyMemberships(),
      ]);

      final businesses = results[0] as List<Business>;
      final memberships = results[1] as List<BusinessMembership>;

      // Cria mapa de memberships por business_id
      final membershipMap = <String, BusinessMembership>{};
      for (final m in memberships) {
        membershipMap[m.businessId] = m;
      }

      // Ordena: primeiro as que tem membership, depois as demais
      businesses.sort((a, b) {
        final aMembership = membershipMap[a.id];
        final bMembership = membershipMap[b.id];

        // Prioridade: aprovado > pendente > outros > sem membership
        int getPriority(BusinessMembership? m) {
          if (m == null) return 4;
          if (m.status.isApproved) return 1;
          if (m.status.isPending) return 2;
          return 3;
        }

        final priorityCompare = getPriority(aMembership).compareTo(getPriority(bMembership));
        if (priorityCompare != 0) return priorityCompare;

        // Se mesma prioridade, ordena por nome
        return a.name.compareTo(b.name);
      });

      setState(() {
        _businesses = businesses;
        _filteredBusinesses = businesses;
        _membershipsByBusinessId = membershipMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar academias';
        _isLoading = false;
      });
    }
  }

  void _filterBusinesses(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBusinesses = _businesses;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredBusinesses = _businesses
          .where((b) =>
              b.name.toLowerCase().contains(lowercaseQuery) ||
              (b.address?.toLowerCase().contains(lowercaseQuery) ?? false))
          .toList();
    });
  }

  Future<void> _requestMembership(Business business) async {
    final membership = _membershipsByBusinessId[business.id];

    // Se já tem membership, mostra informações
    if (membership != null) {
      _showMembershipInfo(business, membership);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar solicitação'),
        content: Text(
          'Deseja solicitar acesso à academia "${business.name}"?\n\n'
          'Após a aprovação, você poderá agendar aulas e treinos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _membershipService.requestMembership(business.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          // Recarrega os dados para atualizar o status
          _loadData();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMembershipInfo(Business business, BusinessMembership membership) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getStatusColor(membership.status).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(membership.status),
                size: 40,
                color: _getStatusColor(membership.status),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              business.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(membership.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                membership.statusText,
                style: TextStyle(
                  color: _getStatusColor(membership.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getStatusDescription(membership.status),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (membership.status.isRejected && membership.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo: ${membership.rejectionReason}',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (membership.status.isRejected)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _resubmitRequest(business);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reenviar Solicitação'),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _resubmitRequest(Business business) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _membershipService.requestMembership(business.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          _loadData();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Color _getStatusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.approved:
        return Colors.green;
      case MembershipStatus.pending:
        return Colors.orange;
      case MembershipStatus.rejected:
        return Colors.red;
      case MembershipStatus.suspended:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.approved:
        return Icons.check_circle;
      case MembershipStatus.pending:
        return Icons.hourglass_empty;
      case MembershipStatus.rejected:
        return Icons.cancel;
      case MembershipStatus.suspended:
        return Icons.block;
    }
  }

  String _getStatusDescription(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.approved:
        return 'Você é membro desta academia e pode reservar aulas.';
      case MembershipStatus.pending:
        return 'Sua solicitação está em análise. Você será notificado quando for aprovado.';
      case MembershipStatus.rejected:
        return 'Sua solicitação foi recusada. Você pode tentar novamente.';
      case MembershipStatus.suspended:
        return 'Sua associação foi suspensa. Entre em contato com a academia.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Conta academias por status
    final approvedCount = _membershipsByBusinessId.values
        .where((m) => m.status.isApproved)
        .length;
    final pendingCount = _membershipsByBusinessId.values
        .where((m) => m.status.isPending)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Academias'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de estatísticas
          if (!_isLoading && _membershipsByBusinessId.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (approvedCount > 0)
                    _buildStatChip(
                      icon: Icons.check_circle,
                      label: '$approvedCount ativa${approvedCount > 1 ? 's' : ''}',
                      color: Colors.green,
                    ),
                  if (approvedCount > 0 && pendingCount > 0)
                    const SizedBox(width: 8),
                  if (pendingCount > 0)
                    _buildStatChip(
                      icon: Icons.hourglass_empty,
                      label: '$pendingCount pendente${pendingCount > 1 ? 's' : ''}',
                      color: Colors.orange,
                    ),
                ],
              ),
            ),
          // Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar academia...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              onChanged: _filterBusinesses,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _filteredBusinesses.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.business_outlined,
                                      size: 48,
                                      color: colorScheme.primary.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'Nenhuma academia disponível'
                                        : 'Nenhuma academia encontrada',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'Novas academias aparecerão aqui quando se cadastrarem.'
                                        : 'Tente buscar por outro nome ou limpe a busca.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredBusinesses.length + 1, // +1 para o header
                              itemBuilder: (context, index) {
                                // Header de orientação
                                if (index == 0) {
                                  // Mostra dica apenas se não tem nenhuma academia ainda
                                  if (_membershipsByBusinessId.isEmpty) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.tips_and_updates_outlined,
                                            color: colorScheme.primary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Como funciona',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Toque em uma academia para solicitar acesso. Após aprovação, você poderá reservar aulas.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurface.withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                                
                                final business = _filteredBusinesses[index - 1];
                                final membership = _membershipsByBusinessId[business.id];
                                return _buildBusinessCard(business, membership);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Business business, BusinessMembership? membership) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMembership = membership != null;
    final isApproved = membership?.status.isApproved ?? false;
    final isPending = membership?.status.isPending ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasMembership
            ? BorderSide(
                color: _getStatusColor(membership!.status).withOpacity(0.5),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: _isSubmitting ? null : () => _requestMembership(business),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar da academia com indicador de status
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: hasMembership
                              ? _getStatusColor(membership!.status).withOpacity(0.1)
                              : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: business.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  business.logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      business.initials,
                                      style: TextStyle(
                                        color: hasMembership
                                            ? _getStatusColor(membership!.status)
                                            : colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  business.initials,
                                  style: TextStyle(
                                    color: hasMembership
                                        ? _getStatusColor(membership!.status)
                                        : colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                      ),
                      // Badge de status
                      if (hasMembership)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getStatusColor(membership!.status),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _getStatusIcon(membership.status),
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isApproved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Membro',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isPending)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Pendente',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (business.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            business.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (business.address != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  business.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.outline,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasMembership ? Icons.info_outline : Icons.add_circle_outline,
                    color: hasMembership
                        ? _getStatusColor(membership!.status)
                        : colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
