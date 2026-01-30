import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/booking_service.dart';

void main() {
  group('StudentBookingInfo', () {
    late StudentBookingInfo bookingInfo;

    setUp(() {
      bookingInfo = StudentBookingInfo(
        bookingId: 'booking-123',
        classId: 'class-456',
        classTitle: 'Natação Iniciante',
        classType: 'class',
        classStartTime: DateTime(2024, 1, 15, 8, 0),
        classEndTime: DateTime(2024, 1, 15, 9, 0),
        studentId: 'student-789',
        studentName: 'João Silva',
        studentEmail: 'joao@example.com',
        bookingsThisWeek: 2,
        remainingBookings: 1,
      );
    });

    test('should store all properties correctly', () {
      expect(bookingInfo.bookingId, equals('booking-123'));
      expect(bookingInfo.classId, equals('class-456'));
      expect(bookingInfo.classTitle, equals('Natação Iniciante'));
      expect(bookingInfo.classType, equals('class'));
      expect(bookingInfo.studentId, equals('student-789'));
      expect(bookingInfo.studentName, equals('João Silva'));
      expect(bookingInfo.studentEmail, equals('joao@example.com'));
      expect(bookingInfo.bookingsThisWeek, equals(2));
      expect(bookingInfo.remainingBookings, equals(1));
    });

    group('formattedDate', () {
      test('should format date correctly', () {
        expect(bookingInfo.formattedDate, equals('15/01'));
      });

      test('should pad single digit day and month', () {
        final info = StudentBookingInfo(
          bookingId: 'booking-123',
          classId: 'class-456',
          classTitle: 'Test',
          classType: 'class',
          classStartTime: DateTime(2024, 3, 5, 8, 0),
          classEndTime: DateTime(2024, 3, 5, 9, 0),
          studentId: 'student-789',
          studentName: 'Test',
          studentEmail: 'test@example.com',
          bookingsThisWeek: 1,
          remainingBookings: 2,
        );

        expect(info.formattedDate, equals('05/03'));
      });
    });

    group('formattedTime', () {
      test('should format time correctly', () {
        expect(bookingInfo.formattedTime, equals('08:00 - 09:00'));
      });

      test('should pad single digit hours and minutes', () {
        final info = StudentBookingInfo(
          bookingId: 'booking-123',
          classId: 'class-456',
          classTitle: 'Test',
          classType: 'class',
          classStartTime: DateTime(2024, 1, 15, 6, 5),
          classEndTime: DateTime(2024, 1, 15, 7, 30),
          studentId: 'student-789',
          studentName: 'Test',
          studentEmail: 'test@example.com',
          bookingsThisWeek: 1,
          remainingBookings: 2,
        );

        expect(info.formattedTime, equals('06:05 - 07:30'));
      });
    });

    group('remainingText', () {
      test('should return "Sem limite" when negative', () {
        final info = StudentBookingInfo(
          bookingId: 'booking-123',
          classId: 'class-456',
          classTitle: 'Test',
          classType: 'class',
          classStartTime: DateTime(2024, 1, 15, 8, 0),
          classEndTime: DateTime(2024, 1, 15, 9, 0),
          studentId: 'student-789',
          studentName: 'Test',
          studentEmail: 'test@example.com',
          bookingsThisWeek: 1,
          remainingBookings: -1,
        );

        expect(info.remainingText, equals('Sem limite'));
      });

      test('should return "Limite atingido" when zero', () {
        final info = StudentBookingInfo(
          bookingId: 'booking-123',
          classId: 'class-456',
          classTitle: 'Test',
          classType: 'class',
          classStartTime: DateTime(2024, 1, 15, 8, 0),
          classEndTime: DateTime(2024, 1, 15, 9, 0),
          studentId: 'student-789',
          studentName: 'Test',
          studentEmail: 'test@example.com',
          bookingsThisWeek: 3,
          remainingBookings: 0,
        );

        expect(info.remainingText, equals('Limite atingido'));
      });

      test('should return "1 restante" for single booking', () {
        expect(bookingInfo.remainingText, equals('1 restante'));
      });

      test('should return "X restantes" for multiple bookings', () {
        final info = StudentBookingInfo(
          bookingId: 'booking-123',
          classId: 'class-456',
          classTitle: 'Test',
          classType: 'class',
          classStartTime: DateTime(2024, 1, 15, 8, 0),
          classEndTime: DateTime(2024, 1, 15, 9, 0),
          studentId: 'student-789',
          studentName: 'Test',
          studentEmail: 'test@example.com',
          bookingsThisWeek: 1,
          remainingBookings: 2,
        );

        expect(info.remainingText, equals('2 restantes'));
      });
    });
  });

  group('BookingResult', () {
    group('factory constructors', () {
      test('success should create successful result', () {
        final result = BookingResult.success('Reserva realizada!');

        expect(result.success, isTrue);
        expect(result.message, equals('Reserva realizada!'));
        expect(result.booking, isNull);
      });

      test('error should create failed result', () {
        final result = BookingResult.error('Aula lotada');

        expect(result.success, isFalse);
        expect(result.message, equals('Aula lotada'));
        expect(result.booking, isNull);
      });
    });

    group('properties', () {
      test('should store all properties correctly', () {
        final result = BookingResult(
          success: true,
          message: 'Test message',
          booking: null,
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Test message'));
      });
    });
  });

  group('UserBookingLimits', () {
    test('should store all properties correctly', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 2,
        cancellationsThisMonth: 1,
        canBookMore: true,
        canCancelMore: true,
      );

      expect(limits.activeBookingsThisWeek, equals(2));
      expect(limits.cancellationsThisMonth, equals(1));
      expect(limits.canBookMore, isTrue);
      expect(limits.canCancelMore, isTrue);
    });

    test('should indicate cannot book when limit reached', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 3,
        cancellationsThisMonth: 0,
        canBookMore: false,
        canCancelMore: true,
      );

      expect(limits.canBookMore, isFalse);
    });

    test('should indicate cannot cancel when limit reached', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 1,
        cancellationsThisMonth: 2,
        canBookMore: true,
        canCancelMore: false,
      );

      expect(limits.canCancelMore, isFalse);
    });

    test('should handle zero values', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 0,
        cancellationsThisMonth: 0,
        canBookMore: true,
        canCancelMore: true,
      );

      expect(limits.activeBookingsThisWeek, equals(0));
      expect(limits.cancellationsThisMonth, equals(0));
      expect(limits.canBookMore, isTrue);
      expect(limits.canCancelMore, isTrue);
    });
  });
}
