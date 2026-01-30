import 'package:flutter/material.dart';

/// Representa um tipo de aula configurável pelo admin
class ClassType {
  final String id;
  final String name;
  final String icon; // Nome do ícone Material

  const ClassType({
    required this.id,
    required this.name,
    this.icon = 'school',
  });

  /// Retorna o IconData correspondente ao nome do ícone
  IconData get iconData => ClassTypeIcons.getIconData(icon);

  /// Tipos padrão do sistema
  static const List<ClassType> defaults = [
    ClassType(id: 'class', name: 'Aula de Natação', icon: 'school'),
    ClassType(id: 'free', name: 'Nado Livre', icon: 'pool'),
  ];

  /// Cria a partir de JSON
  factory ClassType.fromJson(Map<String, dynamic> json) {
    return ClassType(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'school',
    );
  }

  /// Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }

  /// Cria a partir de string JSON (para armazenamento em array)
  static List<ClassType> fromJsonList(List<dynamic>? jsonList) {
    if (jsonList == null || jsonList.isEmpty) {
      return List.from(defaults);
    }
    return jsonList.map((json) => ClassType.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Converte lista para JSON
  static List<Map<String, dynamic>> toJsonList(List<ClassType> types) {
    return types.map((t) => t.toJson()).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Cria uma cópia com os campos atualizados
  ClassType copyWith({
    String? id,
    String? name,
    String? icon,
  }) {
    return ClassType(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
    );
  }
}

/// Helper para mapear nomes de ícones para IconData
class ClassTypeIcons {
  static const Map<String, IconData> _iconMap = {
    'school': Icons.school,
    'pool': Icons.pool,
    'fitness_center': Icons.fitness_center,
    'sports': Icons.sports,
    'directions_run': Icons.directions_run,
    'water': Icons.water,
    'waves': Icons.waves,
    'child_care': Icons.child_care,
    'elderly': Icons.elderly,
    'accessibility': Icons.accessibility,
    'category': Icons.category,
  };

  /// Lista de ícones disponíveis para seleção
  static const List<Map<String, dynamic>> availableIcons = [
    {'name': 'school', 'label': 'Escola'},
    {'name': 'pool', 'label': 'Piscina'},
    {'name': 'fitness_center', 'label': 'Academia'},
    {'name': 'sports', 'label': 'Esportes'},
    {'name': 'directions_run', 'label': 'Corrida'},
    {'name': 'water', 'label': 'Água'},
    {'name': 'waves', 'label': 'Ondas'},
    {'name': 'child_care', 'label': 'Infantil'},
    {'name': 'elderly', 'label': 'Idoso'},
    {'name': 'accessibility', 'label': 'Acessível'},
  ];

  /// Retorna o IconData para um nome de ícone
  static IconData getIconData(String iconName) {
    return _iconMap[iconName] ?? Icons.category;
  }
}
