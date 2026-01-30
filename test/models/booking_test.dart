import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/booking.dart';
import 'package:trainly/models/swim_class.dart';

void main() {
  group('Booking', () {
    group('fromJson', () {
      test('should create Booking from complete JSON with nested class', () {
        final json = {
          'id': 'booking-123',
          'user_id': 'user-456',
          'class_id': 'class-789',
          'created_at': '2024-01-15T10:00:00Z',
          'classes': {
            'id': 'class-789',
            'title': 'Natação Iniciante',
            'description': 'Aula para iniciantes',
            'start_time': '2024-01-16T08:00:00Z',
            'end_time': '2024-01-16T09:00:00Z',
            'capacity': 10,
            'lanes': 4,
            'type': 'class',
          },
        };

        final booking = Booking.fromJson(json);

        expect(booking.id, equals('booking-123'));
        expect(booking.userId, equals('user-456'));
        expect(booking.classId, equals('class-789'));
        expect(booking.swimClass, isNotNull);
        expect(booking.swimClass!.title, equals('Natação Iniciante'));
      });

      test('should create Booking without nested class', () {
        final json = {
          'id': 'booking-123',
          'user_id': 'user-456',
          'class_id': 'class-789',
          'created_at': '2024-01-15T10:00:00Z',
        };

        final booking = Booking.fromJson(json);

        expect(booking.id, equals('booking-123'));
        expect(booking.swimClass, isNull);
      });
    });

    group('toJson', () {
      test('should convert Booking to JSON for insert', () {
        final booking = Booking(
          id: 'booking-123',
          userId: 'user-456',
          classId: 'class-789',
          createdAt: DateTime.parse('2024-01-15T10:00:00Z'),
        );

        final json = booking.toJson();

        expect(json['user_id'], equals('user-456'));
        expect(json['class_id'], equals('class-789'));
        // id and created_at should not be in insert JSON
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('created_at'), isFalse);
      });
    });
  });

  group('SwimClassWithAvailability', () {
    late SwimClass testClass;

    setUp(() {
      testClass = SwimClass(
        id: 'class-123',
        title: 'Natação',
        startTime: DateTime.parse('2024-01-16T08:00:00Z'),
        endTime: DateTime.parse('2024-01-16T09:00:00Z'),
        capacity: 10,
        lanes: 4,
        type: SwimClassType.classType,
      );
    });

    group('fromJson', () {
      test('should create SwimClassWithAvailability from JSON', () {
        final json = {
          'id': 'class-123',
          'title': 'Natação',
          'start_time': '2024-01-16T08:00:00Z',
          'end_time': '2024-01-16T09:00:00Z',
          'capacity': 10,
          'lanes': 4,
          'type': 'class',
          'available_spots': 7,
          'booked_count': 3,
        };

        final classWithAvailability = SwimClassWithAvailability.fromJson(
          json,
          isBookedByCurrentUser: true,
        );

        expect(classWithAvailability.availableSpots, equals(7));
        expect(classWithAvailability.bookedCount, equals(3));
        expect(classWithAvailability.isBookedByCurrentUser, isTrue);
      });
    });

    group('isFull', () {
      test('should return true when no available spots', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 0,
          bookedCount: 10,
        );

        expect(classWithAvailability.isFull, isTrue);
      });

      test('should return false when spots available', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 5,
          bookedCount: 5,
        );

        expect(classWithAvailability.isFull, isFalse);
      });
    });

    group('canBook', () {
      test('should return true when spots available and not booked', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 5,
          bookedCount: 5,
          isBookedByCurrentUser: false,
        );

        expect(classWithAvailability.canBook, isTrue);
      });

      test('should return false when already booked by user', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 5,
          bookedCount: 5,
          isBookedByCurrentUser: true,
        );

        expect(classWithAvailability.canBook, isFalse);
      });

      test('should return false when class is full', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 0,
          bookedCount: 10,
          isBookedByCurrentUser: false,
        );

        expect(classWithAvailability.canBook, isFalse);
      });
    });

    group('availabilityText', () {
      test('should return "Lotada" when full', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 0,
          bookedCount: 10,
        );

        expect(classWithAvailability.availabilityText, equals('Lotada'));
      });

      test('should return "1 vaga" for single spot', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 1,
          bookedCount: 9,
        );

        expect(classWithAvailability.availabilityText, equals('1 vaga'));
      });

      test('should return "X vagas" for multiple spots', () {
        final classWithAvailability = SwimClassWithAvailability(
          swimClass: testClass,
          availableSpots: 5,
          bookedCount: 5,
        );

        expect(classWithAvailability.availabilityText, equals('5 vagas'));
      });
    });
  });
}
