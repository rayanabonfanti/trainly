import 'package:flutter/material.dart';

/// Helper para envolver widgets em MaterialApp para testes
Widget wrapWithMaterialApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(body: child),
  );
}

/// Helper para criar JSON de aula de teste
Map<String, dynamic> createTestClassJson({
  String id = 'class-123',
  String title = 'Natação Iniciante',
  String? description,
  DateTime? startTime,
  DateTime? endTime,
  int capacity = 10,
  int lanes = 4,
  String type = 'class',
}) {
  final start = startTime ?? DateTime.now().add(const Duration(days: 1));
  final end = endTime ?? start.add(const Duration(hours: 1));

  return {
    'id': id,
    'title': title,
    'description': description,
    'start_time': start.toIso8601String(),
    'end_time': end.toIso8601String(),
    'capacity': capacity,
    'lanes': lanes,
    'type': type,
  };
}

/// Helper para criar JSON de reserva de teste
Map<String, dynamic> createTestBookingJson({
  String id = 'booking-123',
  String userId = 'user-456',
  String classId = 'class-789',
  DateTime? createdAt,
  Map<String, dynamic>? classData,
}) {
  return {
    'id': id,
    'user_id': userId,
    'class_id': classId,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    if (classData != null) 'classes': classData,
  };
}

/// Helper para criar JSON de perfil de teste
Map<String, dynamic> createTestProfileJson({
  String id = 'user-123',
  String email = 'user@example.com',
  String? name,
  String? phone,
  String? avatarUrl,
}) {
  return {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'avatar_url': avatarUrl,
  };
}

/// Helper para criar JSON de admin profile de teste
Map<String, dynamic> createTestAdminProfileJson({
  String id = 'admin-123',
  String email = 'admin@example.com',
  String? name,
  String role = 'admin',
}) {
  return {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
  };
}
