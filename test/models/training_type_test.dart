import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/training_type.dart';

void main() {
  group('TrainingType', () {
    test('should create TrainingType with all properties', () {
      final trainingType = TrainingType(
        id: 'type-123',
        name: 'Natação',
      );

      expect(trainingType.id, equals('type-123'));
      expect(trainingType.name, equals('Natação'));
    });

    group('fromJson', () {
      test('should create TrainingType from JSON', () {
        final json = {
          'id': 'type-123',
          'name': 'Natação',
        };

        final trainingType = TrainingType.fromJson(json);

        expect(trainingType.id, equals('type-123'));
        expect(trainingType.name, equals('Natação'));
      });

      test('should handle different training types', () {
        final json = {
          'id': 'type-456',
          'name': 'Nado Livre',
        };

        final trainingType = TrainingType.fromJson(json);

        expect(trainingType.id, equals('type-456'));
        expect(trainingType.name, equals('Nado Livre'));
      });
    });
  });
}
