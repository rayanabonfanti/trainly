import 'package:flutter/material.dart';

import '../models/business_membership.dart';
import '../services/membership_service.dart';

/// Página para gerenciar membros da academia (solicitações e membros ativos)
class ManageMembersPage extends StatefulWidget {
  const ManageMembersPage({super.key});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MembershipService _membershipService = MembershipService();

  List<BusinessMembership> _pendingRequests = [];
  List<BusinessMembership> _approvedMembers = [];
  List<BusinessMembership> _otherMembers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allMembers = await _membershipService.getBusinessMembers();

      setState(() {
        _pendingRequests = allMembers
            .where((m) => m.status.isPending)
            .toList();
        _approvedMembers = allMembers
            .where((m) => m.status.isApproved)
            .toList();
        _otherMembers = allMembers
            .where((m) => m.status.isRejected || m.status.isSuspended)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar membros';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveMembership(BusinessMembership membership) async {
    final result = await _membershipService.approveMembership(membership.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
        _loadMembers();
      }
    }
  }

  Future<void> _rejectMembership(BusinessMembership membership) async {
    final reason = await _showReasonDialog('Motivo da recusa (opcional)');
    if (reason == null) return; // Cancelled

    final result = await _membershipService.rejectMembership(
      membership.id,
      reason: reason.isNotEmpty ? reason : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
        _loadMembers();
      }
    }
  }

  Future<void> _suspendMembership(BusinessMembership membership) async {
    final reason = await _showReasonDialog('Motivo da suspensão (opcional)');
    if (reason == null) return; // Cancelled

    final result = await _membershipService.suspendMembership(
      membership.id,
      reason: reason.isNotEmpty ? reason : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
        _loadMembers();
      }
    }
  }

  Future<void> _reactivateMembership(BusinessMembership membership) async {
    final result = await _membershipService.reactivateMembership(membership.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );

      if (result.success) {
        _loadMembers();
      }
    }
  }

  Future<String?> _showReasonDialog(String title) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Digite o motivo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Membros'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendentes'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Ativos (${_approvedMembers.length})'),
            Tab(text: 'Outros (${_otherMembers.length})'),
          ],
        ),
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
                        onPressed: _loadMembers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMembersList(_pendingRequests, isPending: true),
                      _buildMembersList(_approvedMembers),
                      _buildMembersList(_otherMembers, showReason: true),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMembersList(
    List<BusinessMembership> members, {
    bool isPending = false,
    bool showReason = false,
  }) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.inbox : Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'Nenhuma solicitação pendente'
                  : 'Nenhum membro encontrado',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return _buildMemberCard(
          member,
          isPending: isPending,
          showReason: showReason,
        );
      },
    );
  }

  Widget _buildMemberCard(
    BusinessMembership member, {
    bool isPending = false,
    bool showReason = false,
  }) {
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
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    member.initials,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (member.userEmail != null)
                        Text(
                          member.userEmail!,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(member.status),
              ],
            ),
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
                  'Solicitado em ${member.formattedRequestDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.outline,
                  ),
                ),
                if (member.userPhone != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    member.userPhone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            if (showReason && member.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.rejectionReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(member, isPending: isPending),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(MembershipStatus status) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case MembershipStatus.pending:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.hourglass_empty;
        break;
      case MembershipStatus.approved:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case MembershipStatus.rejected:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        break;
      case MembershipStatus.suspended:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BusinessMembership member, {
    bool isPending = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isPending) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _rejectMembership(member),
            icon: const Icon(Icons.close),
            label: const Text('Recusar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _approveMembership(member),
            icon: const Icon(Icons.check),
            label: const Text('Aprovar'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      );
    }

    if (member.status.isApproved) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _suspendMembership(member),
            icon: const Icon(Icons.block),
            label: const Text('Suspender'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
        ],
      );
    }

    // Rejected or Suspended
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: () => _reactivateMembership(member),
          icon: const Icon(Icons.refresh),
          label: const Text('Reativar'),
        ),
      ],
    );
  }
}
