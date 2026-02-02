import 'class_type.dart';

/// Model para configurações de negócio dinâmicas
class BusinessSettings {
  /// ID da empresa (null = configurações globais/padrão)
  final String? businessId;

  /// Deadline de cancelamento em horas (ex: 2 = 2 horas antes da aula)
  final int cancellationDeadlineHours;

  /// Limite de cancelamentos por mês (0 = sem limite)
  final int maxCancellationsPerMonth;

  /// Se o limite de cancelamentos está habilitado
  final bool cancellationLimitEnabled;

  /// Limite de reservas por semana (0 = sem limite)
  final int maxBookingsPerWeek;

  /// Se o limite de reservas está habilitado
  final bool bookingLimitEnabled;

  /// Antecedência mínima para reservar em horas (ex: 24 = precisa reservar 24h antes)
  /// 0 = pode reservar até o momento da aula
  final int minBookingAdvanceHours;

  /// Capacidade padrão para novas aulas
  final int defaultClassCapacity;

  /// Número padrão de vagas para novas aulas
  final int defaultLanes;

  /// Tipos de aula disponíveis (configurável pelo admin)
  final List<ClassType> classTypes;

  /// Data da última atualização
  final DateTime? updatedAt;

  /// ID do admin que atualizou
  final String? updatedBy;

  BusinessSettings({
    this.businessId,
    this.cancellationDeadlineHours = 0, // Sem deadline - pode cancelar a qualquer momento
    this.maxCancellationsPerMonth = 0,
    this.cancellationLimitEnabled = false, // Limite desabilitado
    this.maxBookingsPerWeek = 0,
    this.bookingLimitEnabled = false, // Limite desabilitado
    this.minBookingAdvanceHours = 0, // Sem antecedência mínima
    this.defaultClassCapacity = 10,
    this.defaultLanes = 4,
    List<ClassType>? classTypes,
    this.updatedAt,
    this.updatedBy,
  }) : classTypes = classTypes ?? ClassType.defaults;

  /// Valores padrão - regras de negócio desabilitadas
  factory BusinessSettings.defaults({String? businessId}) {
    return BusinessSettings(
      businessId: businessId,
      cancellationDeadlineHours: 0, // Sem deadline
      maxCancellationsPerMonth: 0,
      cancellationLimitEnabled: false, // Desabilitado
      maxBookingsPerWeek: 0,
      bookingLimitEnabled: false, // Desabilitado
      minBookingAdvanceHours: 0, // Sem antecedência
      defaultClassCapacity: 10,
      defaultLanes: 4,
      classTypes: ClassType.defaults,
    );
  }

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      businessId: json['business_id'] as String?,
      cancellationDeadlineHours: json['cancellation_deadline_hours'] as int? ?? 0,
      maxCancellationsPerMonth: json['max_cancellations_per_month'] as int? ?? 0,
      cancellationLimitEnabled: json['cancellation_limit_enabled'] as bool? ?? false,
      maxBookingsPerWeek: json['max_bookings_per_week'] as int? ?? 0,
      bookingLimitEnabled: json['booking_limit_enabled'] as bool? ?? false,
      minBookingAdvanceHours: json['min_booking_advance_hours'] as int? ?? 0,
      defaultClassCapacity: json['default_class_capacity'] as int? ?? 10,
      defaultLanes: json['default_lanes'] as int? ?? 4,
      classTypes: ClassType.fromJsonList(json['class_types'] as List<dynamic>?),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'cancellation_deadline_hours': cancellationDeadlineHours,
      'max_cancellations_per_month': maxCancellationsPerMonth,
      'cancellation_limit_enabled': cancellationLimitEnabled,
      'max_bookings_per_week': maxBookingsPerWeek,
      'booking_limit_enabled': bookingLimitEnabled,
      'min_booking_advance_hours': minBookingAdvanceHours,
      'default_class_capacity': defaultClassCapacity,
      'default_lanes': defaultLanes,
      'class_types': ClassType.toJsonList(classTypes),
    };
  }

  BusinessSettings copyWith({
    String? businessId,
    int? cancellationDeadlineHours,
    int? maxCancellationsPerMonth,
    bool? cancellationLimitEnabled,
    int? maxBookingsPerWeek,
    bool? bookingLimitEnabled,
    int? minBookingAdvanceHours,
    int? defaultClassCapacity,
    int? defaultLanes,
    List<ClassType>? classTypes,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return BusinessSettings(
      businessId: businessId ?? this.businessId,
      cancellationDeadlineHours: cancellationDeadlineHours ?? this.cancellationDeadlineHours,
      maxCancellationsPerMonth: maxCancellationsPerMonth ?? this.maxCancellationsPerMonth,
      cancellationLimitEnabled: cancellationLimitEnabled ?? this.cancellationLimitEnabled,
      maxBookingsPerWeek: maxBookingsPerWeek ?? this.maxBookingsPerWeek,
      bookingLimitEnabled: bookingLimitEnabled ?? this.bookingLimitEnabled,
      minBookingAdvanceHours: minBookingAdvanceHours ?? this.minBookingAdvanceHours,
      defaultClassCapacity: defaultClassCapacity ?? this.defaultClassCapacity,
      defaultLanes: defaultLanes ?? this.defaultLanes,
      classTypes: classTypes ?? this.classTypes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Mensagem de deadline de cancelamento
  String get cancellationDeadlineMessage {
    if (cancellationDeadlineHours == 0) {
      return 'Cancelamentos são permitidos a qualquer momento';
    }
    if (cancellationDeadlineHours == 1) {
      return 'Cancelamentos só são permitidos até 1 hora antes da aula';
    }
    return 'Cancelamentos só são permitidos até $cancellationDeadlineHours horas antes da aula';
  }

  /// Mensagem de limite de reservas
  String get bookingLimitMessage {
    if (!bookingLimitEnabled || maxBookingsPerWeek == 0) {
      return 'Sem limite de reservas por semana';
    }
    if (maxBookingsPerWeek == 1) {
      return 'Você pode ter no máximo 1 reserva ativa por semana';
    }
    return 'Você pode ter no máximo $maxBookingsPerWeek reservas ativas por semana';
  }

  /// Mensagem de limite de cancelamentos
  String get cancellationLimitMessage {
    if (!cancellationLimitEnabled || maxCancellationsPerMonth == 0) {
      return 'Sem limite de cancelamentos por mês';
    }
    if (maxCancellationsPerMonth == 1) {
      return 'Você pode cancelar no máximo 1 vez por mês';
    }
    return 'Você pode cancelar no máximo $maxCancellationsPerMonth vezes por mês';
  }

  /// Mensagem de antecedência mínima
  String get minBookingAdvanceMessage {
    if (minBookingAdvanceHours == 0) {
      return 'Reservas podem ser feitas até o horário da aula';
    }
    if (minBookingAdvanceHours < 24) {
      return 'Reservas devem ser feitas com $minBookingAdvanceHours horas de antecedência';
    }
    final days = minBookingAdvanceHours ~/ 24;
    if (days == 1) {
      return 'Reservas devem ser feitas com 1 dia de antecedência';
    }
    return 'Reservas devem ser feitas com $days dias de antecedência';
  }

  /// Verifica se pode cancelar baseado no deadline
  bool canCancelBooking(DateTime classStartTime) {
    if (cancellationDeadlineHours == 0) return true;
    final deadline = classStartTime.subtract(
      Duration(hours: cancellationDeadlineHours),
    );
    return DateTime.now().isBefore(deadline);
  }

  /// Verifica se pode reservar baseado na antecedência
  bool canBookClass(DateTime classStartTime) {
    if (minBookingAdvanceHours == 0) return true;
    final minBookingTime = classStartTime.subtract(
      Duration(hours: minBookingAdvanceHours),
    );
    return DateTime.now().isBefore(minBookingTime);
  }

  /// Retorna o tempo restante para cancelar
  Duration? timeUntilCancellationDeadline(DateTime classStartTime) {
    if (cancellationDeadlineHours == 0) return null;
    final deadline = classStartTime.subtract(
      Duration(hours: cancellationDeadlineHours),
    );
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}
