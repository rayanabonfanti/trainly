import 'class_type.dart';

/// Tipo de aula (enum para compatibilidade com código existente)
enum SwimClassType {
  classType('class', 'Aula de Natação'),
  free('free', 'Nado Livre');

  final String value;
  final String label;

  const SwimClassType(this.value, this.label);

  static SwimClassType fromString(String value) {
    return SwimClassType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SwimClassType.classType,
    );
  }

  /// Converte de ClassType para SwimClassType
  static SwimClassType fromClassType(ClassType classType) {
    return SwimClassType.values.firstWhere(
      (e) => e.value == classType.id,
      orElse: () => SwimClassType.classType,
    );
  }
}

/// Model que representa uma aula de natação
class SwimClass {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int lanes;
  final SwimClassType type;
  final DateTime? createdAt;

  SwimClass({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.lanes,
    required this.type,
    this.createdAt,
  });

  factory SwimClass.fromJson(Map<String, dynamic> json) {
    return SwimClass(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      capacity: json['capacity'] as int,
      lanes: json['lanes'] as int,
      type: SwimClassType.fromString(json['type'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'capacity': capacity,
      'lanes': lanes,
      'type': type.value,
    };
  }

  /// Cria uma cópia com os campos atualizados
  SwimClass copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    int? capacity,
    int? lanes,
    SwimClassType? type,
    DateTime? createdAt,
  }) {
    return SwimClass(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capacity: capacity ?? this.capacity,
      lanes: lanes ?? this.lanes,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Formata o horário para exibição (ex: "06:00 - 07:00")
  String get formattedTime {
    final startHour = startTime.hour.toString().padLeft(2, '0');
    final startMinute = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMinute - $endHour:$endMinute';
  }

  /// Formata a data para exibição (ex: "30/01/2026")
  String get formattedDate {
    final day = startTime.day.toString().padLeft(2, '0');
    final month = startTime.month.toString().padLeft(2, '0');
    final year = startTime.year;
    return '$day/$month/$year';
  }

  /// Duração da aula em minutos
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }
}
