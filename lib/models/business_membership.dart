/// Status de associação do usuário com uma empresa
enum MembershipStatus {
  pending('pending', 'Pendente'),
  approved('approved', 'Aprovado'),
  rejected('rejected', 'Recusado'),
  suspended('suspended', 'Suspenso');

  final String value;
  final String label;

  const MembershipStatus(this.value, this.label);

  static MembershipStatus fromString(String value) {
    return MembershipStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MembershipStatus.pending,
    );
  }

  bool get isPending => this == MembershipStatus.pending;
  bool get isApproved => this == MembershipStatus.approved;
  bool get isRejected => this == MembershipStatus.rejected;
  bool get isSuspended => this == MembershipStatus.suspended;
  bool get canBook => this == MembershipStatus.approved;
}

/// Model que representa a associação de um usuário com uma empresa
class BusinessMembership {
  final String id;
  final String userId;
  final String businessId;
  final MembershipStatus status;
  final String? rejectionReason;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Dados do usuário (populated via join)
  final String? userName;
  final String? userEmail;
  final String? userPhone;

  // Dados da empresa (populated via join)
  final String? businessName;
  final String? businessSlug;

  BusinessMembership({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.status,
    this.rejectionReason,
    this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    this.approvedBy,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.businessName,
    this.businessSlug,
  });

  factory BusinessMembership.fromJson(Map<String, dynamic> json) {
    // Extrai dados do usuário se houver join
    String? userName;
    String? userEmail;
    String? userPhone;
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      userName = profile['name'] as String?;
      userEmail = profile['email'] as String?;
      userPhone = profile['phone'] as String?;
    }

    // Extrai dados da empresa se houver join
    String? businessName;
    String? businessSlug;
    if (json['businesses'] != null) {
      final business = json['businesses'] as Map<String, dynamic>;
      businessName = business['name'] as String?;
      businessSlug = business['slug'] as String?;
    }

    return BusinessMembership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessId: json['business_id'] as String,
      status: MembershipStatus.fromString(json['status'] as String? ?? 'pending'),
      rejectionReason: json['rejection_reason'] as String?,
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'] as String)
          : null,
      approvedBy: json['approved_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      businessName: businessName,
      businessSlug: businessSlug,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'business_id': businessId,
      'status': status.value,
      'rejection_reason': rejectionReason,
      'requested_at': requestedAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }

  BusinessMembership copyWith({
    String? id,
    String? userId,
    String? businessId,
    MembershipStatus? status,
    String? rejectionReason,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? approvedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? businessName,
    String? businessSlug,
  }) {
    return BusinessMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      businessName: businessName ?? this.businessName,
      businessSlug: businessSlug ?? this.businessSlug,
    );
  }

  /// Nome de exibição do usuário
  String get displayName {
    if (userName != null && userName!.isNotEmpty) {
      return userName!;
    }
    if (userEmail != null) {
      final parts = userEmail!.split('@');
      if (parts.isNotEmpty) {
        return parts[0].replaceAll('.', ' ').split(' ').map((s) {
          if (s.isEmpty) return s;
          return s[0].toUpperCase() + s.substring(1).toLowerCase();
        }).join(' ');
      }
    }
    return 'Usuário';
  }

  /// Iniciais do nome do usuário
  String get initials {
    final name = displayName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Texto formatado do status
  String get statusText {
    switch (status) {
      case MembershipStatus.pending:
        return 'Aguardando aprovação';
      case MembershipStatus.approved:
        return 'Membro ativo';
      case MembershipStatus.rejected:
        return 'Solicitação recusada';
      case MembershipStatus.suspended:
        return 'Membro suspenso';
    }
  }

  /// Data formatada da solicitação
  String get formattedRequestDate {
    final date = requestedAt ?? createdAt;
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
}
