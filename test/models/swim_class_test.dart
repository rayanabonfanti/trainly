import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/swim_class.dart';

void main() {
  group('SwimClassType', () {
    test('should have correct values', () {
      expect(SwimClassType.classType.value, equals('class'));
      expect(SwimClassType.free.value, equals('free'));
    });

    test('should have correct labels', () {
      expect(SwimClassType.classType.label, equals('Aula'));
      expect(SwimClassType.free.label, equals('Nado Livre'));
    });

    group('fromString', () {
      test('should return classType for "class"', () {
        final result = SwimClassType.fromString('class');
        expect(result, equals(SwimClassType.classType));
      });

      test('should return free for "free"', () {
        final result = SwimClassType.fromString('free');
        expect(result, equals(SwimClassType.free));
      });

      test('should return classType for unknown value', () {
        final result = SwimClassType.fromString('unknown');
        expect(result, equals(SwimClassType.classType));
      });
    });
  });

  group('SwimClass', () {
    group('fromJson', () {
      test('should create SwimClass from complete JSON', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'title': 'Natação Iniciante',
          'description': 'Aula para iniciantes',
          'start_time': '2024-01-15T08:00:00Z',
          'end_time': '2024-01-15T09:00:00Z',
          'capacity': 10,
          'lanes': 4,
          'type': 'class',
          'created_at': '2024-01-10T10:00:00Z',
        };

        final swimClass = SwimClass.fromJson(json);

        expect(swimClass.id, equals('123e4567-e89b-12d3-a456-426614174000'));
        expect(swimClass.title, equals('Natação Iniciante'));
        expect(swimClass.description, equals('Aula para iniciantes'));
        expect(swimClass.capacity, equals(10));
        expect(swimClass.lanes, equals(4));
        expect(swimClass.type, equals(SwimClassType.classType));
      });

      test('should handle null description', () {
        final json = {
          'id': '123',
          'title': 'Natação',
          'description': null,
          'start_time': '2024-01-15T08:00:00Z',
          'end_time': '2024-01-15T09:00:00Z',
          'capacity': 10,
          'lanes': 4,
          'type': 'free',
        };

        final swimClass = SwimClass.fromJson(json);

        expect(swimClass.description, isNull);
        expect(swimClass.type, equals(SwimClassType.free));
      });
    });

    group('toJson', () {
      test('should convert SwimClass to JSON correctly', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Natação Iniciante',
          description: 'Aula para iniciantes',
          startTime: DateTime.parse('2024-01-15T08:00:00Z'),
          endTime: DateTime.parse('2024-01-15T09:00:00Z'),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        final json = swimClass.toJson();

        expect(json['title'], equals('Natação Iniciante'));
        expect(json['description'], equals('Aula para iniciantes'));
        expect(json['capacity'], equals(10));
        expect(json['lanes'], equals(4));
        expect(json['type'], equals('class'));
      });
    });

    group('copyWith', () {
      test('should create copy with updated title', () {
        final original = SwimClass(
          id: '123',
          title: 'Original',
          startTime: DateTime.parse('2024-01-15T08:00:00Z'),
          endTime: DateTime.parse('2024-01-15T09:00:00Z'),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        final copy = original.copyWith(title: 'Updated');

        expect(copy.title, equals('Updated'));
        expect(copy.id, equals(original.id));
        expect(copy.capacity, equals(original.capacity));
      });
    });

    group('formattedTime', () {
      test('should format time correctly', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 1, 15, 8, 0),
          endTime: DateTime(2024, 1, 15, 9, 30),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.formattedTime, equals('08:00 - 09:30'));
      });

      test('should pad single digit hours and minutes', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 1, 15, 6, 5),
          endTime: DateTime(2024, 1, 15, 7, 0),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.formattedTime, equals('06:05 - 07:00'));
      });
    });

    group('formattedDate', () {
      test('should format date correctly', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 1, 15, 8, 0),
          endTime: DateTime(2024, 1, 15, 9, 0),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.formattedDate, equals('15/01/2024'));
      });

      test('should pad single digit day and month', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 3, 5, 8, 0),
          endTime: DateTime(2024, 3, 5, 9, 0),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.formattedDate, equals('05/03/2024'));
      });
    });

    group('durationMinutes', () {
      test('should calculate duration correctly', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 1, 15, 8, 0),
          endTime: DateTime(2024, 1, 15, 9, 30),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.durationMinutes, equals(90));
      });

      test('should return 60 for one hour class', () {
        final swimClass = SwimClass(
          id: '123',
          title: 'Test',
          startTime: DateTime(2024, 1, 15, 8, 0),
          endTime: DateTime(2024, 1, 15, 9, 0),
          capacity: 10,
          lanes: 4,
          type: SwimClassType.classType,
        );

        expect(swimClass.durationMinutes, equals(60));
      });
    });
  });
}
