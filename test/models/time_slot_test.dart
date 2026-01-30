import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/time_slot.dart';

void main() {
  group('TimeSlot', () {
    test('should create TimeSlot with all properties', () {
      final timeSlot = TimeSlot(
        id: 'slot-123',
        startTime: '08:00',
        endTime: '09:00',
      );

      expect(timeSlot.id, equals('slot-123'));
      expect(timeSlot.startTime, equals('08:00'));
      expect(timeSlot.endTime, equals('09:00'));
    });

    group('fromJson', () {
      test('should create TimeSlot from JSON', () {
        final json = {
          'id': 'slot-123',
          'start_time': '08:00',
          'end_time': '09:00',
        };

        final timeSlot = TimeSlot.fromJson(json);

        expect(timeSlot.id, equals('slot-123'));
        expect(timeSlot.startTime, equals('08:00'));
        expect(timeSlot.endTime, equals('09:00'));
      });

      test('should handle different time formats', () {
        final json = {
          'id': 'slot-123',
          'start_time': '14:30',
          'end_time': '16:00',
        };

        final timeSlot = TimeSlot.fromJson(json);

        expect(timeSlot.startTime, equals('14:30'));
        expect(timeSlot.endTime, equals('16:00'));
      });
    });

    group('formattedTime', () {
      test('should format time range correctly', () {
        final timeSlot = TimeSlot(
          id: 'slot-123',
          startTime: '08:00',
          endTime: '09:00',
        );

        expect(timeSlot.formattedTime, equals('08:00 - 09:00'));
      });

      test('should format time with different hours', () {
        final timeSlot = TimeSlot(
          id: 'slot-123',
          startTime: '14:30',
          endTime: '16:00',
        );

        expect(timeSlot.formattedTime, equals('14:30 - 16:00'));
      });

      test('should handle time with seconds by removing them', () {
        final timeSlot = TimeSlot(
          id: 'slot-123',
          startTime: '08:00:00',
          endTime: '09:00:00',
        );

        expect(timeSlot.formattedTime, equals('08:00 - 09:00'));
      });

      test('should handle time without seconds', () {
        final timeSlot = TimeSlot(
          id: 'slot-123',
          startTime: '06:00',
          endTime: '07:00',
        );

        expect(timeSlot.formattedTime, equals('06:00 - 07:00'));
      });
    });
  });
}
