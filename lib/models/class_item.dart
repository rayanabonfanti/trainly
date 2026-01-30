import 'time_slot.dart';
import 'training_type.dart';

/// Model que representa uma aula agendada
class ClassItem {
  final String id;
  final DateTime date;
  final int capacity;
  final TrainingType trainingType;
  final TimeSlot timeSlot;

  ClassItem({
    required this.id,
    required this.date,
    required this.capacity,
    required this.trainingType,
    required this.timeSlot,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      capacity: json['capacity'] as int,
      trainingType: TrainingType.fromJson(
        json['training_types'] as Map<String, dynamic>,
      ),
      timeSlot: TimeSlot.fromJson(
        json['time_slots'] as Map<String, dynamic>,
      ),
    );
  }
}
