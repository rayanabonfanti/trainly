import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/class_item.dart';
import 'package:trainly/models/time_slot.dart';
import 'package:trainly/models/training_type.dart';

void main() {
  group('ClassItem', () {
    test('should create ClassItem with all properties', () {
      final trainingType = TrainingType(id: 'type-1', name: 'Natação');
      final timeSlot = TimeSlot(
        id: 'slot-1',
        startTime: '08:00',
        endTime: '09:00',
      );
      final classItem = ClassItem(
        id: 'class-123',
        date: DateTime(2024, 1, 15),
        capacity: 10,
        trainingType: trainingType,
        timeSlot: timeSlot,
      );

      expect(classItem.id, equals('class-123'));
      expect(classItem.date, equals(DateTime(2024, 1, 15)));
      expect(classItem.capacity, equals(10));
      expect(classItem.trainingType.name, equals('Natação'));
      expect(classItem.timeSlot.startTime, equals('08:00'));
    });

    group('fromJson', () {
      test('should create ClassItem from JSON', () {
        final json = {
          'id': 'class-123',
          'date': '2024-01-15',
          'capacity': 10,
          'training_types': {
            'id': 'type-1',
            'name': 'Natação',
          },
          'time_slots': {
            'id': 'slot-1',
            'start_time': '08:00',
            'end_time': '09:00',
          },
        };

        final classItem = ClassItem.fromJson(json);

        expect(classItem.id, equals('class-123'));
        expect(classItem.date, equals(DateTime(2024, 1, 15)));
        expect(classItem.capacity, equals(10));
        expect(classItem.trainingType.id, equals('type-1'));
        expect(classItem.trainingType.name, equals('Natação'));
        expect(classItem.timeSlot.id, equals('slot-1'));
        expect(classItem.timeSlot.startTime, equals('08:00'));
        expect(classItem.timeSlot.endTime, equals('09:00'));
      });

      test('should parse date correctly', () {
        final json = {
          'id': 'class-123',
          'date': '2024-03-20',
          'capacity': 5,
          'training_types': {
            'id': 'type-1',
            'name': 'Nado Livre',
          },
          'time_slots': {
            'id': 'slot-1',
            'start_time': '14:00',
            'end_time': '15:00',
          },
        };

        final classItem = ClassItem.fromJson(json);

        expect(classItem.date.year, equals(2024));
        expect(classItem.date.month, equals(3));
        expect(classItem.date.day, equals(20));
      });
    });
  });
}
