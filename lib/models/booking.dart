import 'swim_class.dart';

/// Model que representa uma reserva de aula
class Booking {
  final String id;
  final String userId;
  final String classId;
  final DateTime createdAt;
  final SwimClass? swimClass;

  Booking({
    required this.id,
    required this.userId,
    required this.classId,
    required this.createdAt,
    this.swimClass,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      classId: json['class_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      swimClass: json['classes'] != null
          ? SwimClass.fromJson(json['classes'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'class_id': classId,
    };
  }
}

/// Model para aula com disponibilidade
class SwimClassWithAvailability {
  final SwimClass swimClass;
  final int availableSpots;
  final int bookedCount;
  final bool isBookedByCurrentUser;

  SwimClassWithAvailability({
    required this.swimClass,
    required this.availableSpots,
    required this.bookedCount,
    this.isBookedByCurrentUser = false,
  });

  factory SwimClassWithAvailability.fromJson(
    Map<String, dynamic> json, {
    bool isBookedByCurrentUser = false,
  }) {
    return SwimClassWithAvailability(
      swimClass: SwimClass.fromJson(json),
      availableSpots: json['available_spots'] as int? ?? 0,
      bookedCount: json['booked_count'] as int? ?? 0,
      isBookedByCurrentUser: isBookedByCurrentUser,
    );
  }

  bool get isFull => availableSpots <= 0;

  bool get canBook => !isFull && !isBookedByCurrentUser;

  String get availabilityText {
    if (isFull) return 'Lotada';
    if (availableSpots == 1) return '1 vaga';
    return '$availableSpots vagas';
  }
}
