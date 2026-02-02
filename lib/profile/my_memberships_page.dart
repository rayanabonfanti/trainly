import 'package:flutter/material.dart';

import '../auth/select_business_page.dart';
import '../models/business_membership.dart';
import '../services/membership_service.dart';

/// Página para o aluno ver suas associações/academias
class MyMembershipsPage extends StatefulWidget {
  const MyMembershipsPage({super.key});

  @override
  State<MyMembershipsPage> createState() => _MyMembershipsPageState();
}

class _MyMembershipsPageState extends State<MyMembershipsPage> {
  final MembershipService _membershipService = MembershipService();

  List<BusinessMembership> _memberships = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMemberships();
  }

  Future<void> _loadMemberships() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final memberships = await _membershipService.getMyMemberships();
      setState(() {
        _memberships = memberships;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar academias';
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewMembership() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const SelectBusinessPage(),
      ),
    );

    if (result == true) {
      _loadMemberships();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Academias'),
        actions: [
          IconButton(
            onPressed: _addNewMembership,
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar academia',
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _loadMemberships,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _memberships.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Você ainda não está em nenhuma academia',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Busque uma academia para solicitar acesso',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _addNewMembership,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar Academia'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMemberships,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _memberships.length,
                        itemBuilder: (context, index) {
                          return _buildMembershipCard(_memberships[index]);
                        },
                      ),
                    ),
      floatingActionButton: _memberships.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addNewMembership,
              icon: const Icon(Icons.add),
              label: const Text('Nova Academia'),
            )
          : null,
    );
  }

  Widget _buildMembershipCard(BusinessMembership membership) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      membership.businessName != null
                          ? membership.businessName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membership.businessName ?? 'Academia',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        membership.statusText,
                        style: TextStyle(
                          color: _getStatusColor(membership.status),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(membership.status),
              ],
            ),
            if (membership.status.isPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 20,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sua solicitação está em análise. Você será notificado quando for aprovada.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (membership.status.isRejected && 
                membership.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo: ${membership.rejectionReason}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  'Solicitado em ${membership.formattedRequestDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.pending:
        return Colors.orange.shade700;
      case MembershipStatus.approved:
        return Colors.green.shade700;
      case MembershipStatus.rejected:
        return Colors.red.shade700;
      case MembershipStatus.suspended:
        return Colors.grey.shade700;
    }
  }

  Widget _buildStatusIcon(MembershipStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MembershipStatus.pending:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case MembershipStatus.approved:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case MembershipStatus.rejected:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case MembershipStatus.suspended:
        icon = Icons.block;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
